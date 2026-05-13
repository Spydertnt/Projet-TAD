# Rapport — Mini-Projet GLPI Multi-Sites

> **CY Tech — TAD 2025-2026**  
> Refonte de la base de données GLPI sous Oracle XE  
> Architecture distribuée Cergy / Pau

---

## Table des matières

1. [Introduction](#1-introduction)
2. [Phase 1 — Reverse Engineering](#2-phase-1--reverse-engineering)
3. [Phase 2 — Modélisation et création](#3-phase-2--modélisation-et-création)
4. [Phase 3 — Tests de performance](#4-phase-3--tests-de-performance)
5. [Conclusion](#5-conclusion)

---

## 1. Introduction

### 1.1 Contexte

**GLPI** (Gestionnaire Libre de Parc Informatique) est un logiciel open-source utilisé pour la gestion des actifs IT, des tickets d'incidents et de l'infrastructure réseau. Sa base de données MySQL/MariaDB comprend plus de **250 tables** mais présente des limitations architecturales significatives pour un déploiement multi-sites.

### 1.2 Objectifs du projet

L'objectif est de migrer conceptuellement d'une BDD monolithique MySQL vers une **architecture Oracle distribuée** entre deux sites (Cergy et Pau) en :

1. **Analysant** la structure existante par reverse engineering
2. **Concevant** une nouvelle architecture avec intégrité référentielle, PL/SQL et distribution
3. **Validant** les performances par des benchmarks comparatifs

### 1.3 Périmètre

Le projet couvre trois domaines fonctionnels de GLPI :

| Domaine | Tables GLPI | Nouvelles tables |
|---|---|---|
| Matériels informatiques | 14 tables | 6 tables + 2 référentiels consolidés |
| Utilisateurs & droits | 8 tables | 8 tables |
| Réseaux & infrastructure | 12 tables | 10 tables |
| Transversales | 4 tables | 4 tables + 2 tables système |

---

## 2. Phase 1 — Reverse Engineering

### 2.1 Méthodologie

L'analyse a été réalisée à partir du fichier source [`glpi-empty.sql`](https://github.com/glpi-project/glpi/blob/main/install/mysql/glpi-empty.sql) disponible sur le dépôt GitHub officiel de GLPI. Ce fichier contient l'intégralité du schéma de la base de données.

### 2.2 Architecture de GLPI

| Aspect | Détail |
|---|---|
| SGBD | MySQL/MariaDB, InnoDB, `utf8mb4_unicode_ci` |
| Tables | +250, préfixées `glpi_` |
| Clé primaire | `id INT UNSIGNED AUTO_INCREMENT` |
| Clés étrangères | Pattern `<table>_id` — **aucune contrainte FK explicite** |
| Polymorphisme | `itemtype` (VARCHAR) + `items_id` (INT) |
| Multi-entités | `entities_id` + `is_recursive` |
| Soft delete | `is_deleted` (TINYINT) |
| Audit | `date_mod`, `date_creation` |

### 2.3 Tables identifiées dans le périmètre

#### Matériels (14 tables)

Les 6 types d'actifs GLPI partagent un **pattern commun** (`entities_id`, `users_id`, `locations_id`, `serial`, etc.) mais chacun possède ses propres tables de types et modèles :

- `glpi_computers` + `glpi_computermodels` + `glpi_computertypes`
- `glpi_monitors` + `glpi_monitormodels` + `glpi_monitortypes`
- `glpi_peripherals` + `glpi_peripheraltypes`
- `glpi_printers` + `glpi_printertypes`
- `glpi_phones` + `glpi_phonetypes`
- `glpi_networkequipments` + `glpi_networkequipmenttypes`

→ **Constat** : 12 tables de types/modèles avec une structure quasi identique = redondance structurelle.

#### Utilisateurs & droits (8 tables)

Le système de droits GLPI repose sur un modèle à **3 niveaux** :

1. **Utilisateurs** (`glpi_users`) rattachés à une entité
2. **Profils** (`glpi_profiles`) = ensembles de droits, stockés en **bitmask** dans `glpi_profilerights`
3. **Affectation** (`glpi_profiles_users`) = association utilisateur/profil/entité avec héritage (`is_recursive`)

Les groupes (`glpi_groups`) sont hiérarchiques (auto-référence) avec des rôles multiples.

#### Réseaux (12 tables)

Le réseau GLPI utilise massivement le **polymorphisme** (`itemtype`/`items_id`) sur `glpi_networkports` pour lier un port réseau à n'importe quel type d'actif. Les connexions port-à-port, les VLANs, les sous-réseaux IP et le câblage physique sont modélisés.

### 2.4 Problèmes identifiés

| # | Problème | Impact |
|---|---|---|
| 1 | **Aucune FK explicite** | L'intégrité référentielle n'est pas garantie par le SGBD |
| 2 | **Polymorphisme extensif** | Impossible de créer des FK classiques, JOIN complexes |
| 3 | **Pas de tablespaces** | Pas d'optimisation du stockage |
| 4 | **Pas de vues** | Requêtes complexes répétées dans le code PHP |
| 5 | **Pas de PL/SQL** | Toute la logique métier est applicative |
| 6 | **Base monolithique** | Pas de distribution entre sites |
| 7 | **Tables types redondantes** | 12 tables quasi identiques |
| 8 | **Index sans analyse** | Pas d'optimisation des plans d'exécution |
| 9 | **Cache en JSON** | `sons_cache`/`ancestors_cache` = dénormalisation |

> Voir le document complet : [`reverse_engineering_glpi.md`](reverse_engineering_glpi.md)

---

## 3. Phase 2 — Modélisation et création

### 3.1 Principes de conception

La nouvelle architecture résout les 9 problèmes identifiés en appliquant les principes suivants :

1. **FK explicites** sur toutes les relations
2. **Élimination du polymorphisme** : colonnes FK distinctes + contrainte CHECK (exactement 1 parent)
3. **Consolidation** : `asset_types` et `asset_models` remplacent 12 tables avec un champ `category`
4. **Tablespaces dédiés** par domaine fonctionnel
5. **PL/SQL natif** pour les règles métier
6. **Distribution** entre sites via DB Links Oracle

### 3.2 Tablespaces

6 tablespaces ont été définis pour séparer physiquement les données par domaine :

| Tablespace | Taille initiale | Auto-extension | Contenu |
|---|---|---|---|
| `TS_MATERIEL` | 100 Mo | +50 Mo → 1 Go | Tables matériels, entités, référentiels |
| `TS_UTILISATEURS` | 50 Mo | +25 Mo → 500 Mo | Tables utilisateurs, profils, groupes |
| `TS_RESEAU` | 100 Mo | +50 Mo → 1 Go | Tables réseau, ports, VLANs, IP |
| `TS_SUPPORT` | 50 Mo | +25 Mo → 500 Mo | Tickets, suivis et catégories support |
| `TS_INDEX` | 100 Mo | +50 Mo → 1 Go | Tous les index |
| `TS_TEMP_GLPI` | 50 Mo | +25 Mo → 500 Mo | Tablespace temporaire dédié |

**Justification** : La séparation par tablespace permet une gestion granulaire du stockage (sauvegardes partielles, déplacement sur disques différents) et isole les I/O entre les domaines fonctionnels.

> Script : [`01_tablespaces.sql`](../sql/01_tablespaces.sql)

### 3.3 Schéma des tables (36 tables)

#### Tables transversales (7)

- **`entities`** — Hiérarchie organisationnelle avec `site_code` CHECK IN ('CERGY','PAU')
- **`locations`** — Localisations hiérarchiques (bâtiments, salles)
- **`manufacturers`** — Fabricants (contrainte UNIQUE sur `name`)
- **`states`** — États des matériels avec visibilité par type
- **`networks`** — Types de réseau
- **`asset_types`** — Types d'actifs consolidés (6 catégories, contrainte UNIQUE sur `category, name`)
- **`asset_models`** — Modèles d'actifs consolidés

#### Tables utilisateurs (8)

- **`user_titles`**, **`user_categories`** — Référentiels utilisateurs
- **`users`** — Comptes avec FK vers entités, locations, titres, catégories + auto-référence superviseur
- **`profiles`** — Profils de droits
- **`profile_rights`** — Droits granulaires par profil (contrainte UNIQUE `profiles_id, name`)
- **`profiles_users`** — Affectation utilisateur/profil/entité
- **`groups`** — Groupes hiérarchiques
- **`groups_users`** — Appartenance aux groupes

#### Tables matériels (6)

Toutes partagent un pattern commun avec FK vers `entities`, `users`, `locations`, `asset_types`, `manufacturers`, `states` :

- **`computers`** — Avec champs supplémentaires : `uuid`, `users_id_tech`, `networks_id`, `asset_models_id`
- **`monitors`** — Avec `size_monitor`
- **`peripherals`**, **`printers`**, **`phones`**, **`network_equipments`**

Contrainte notable : `UNIQUE (entities_id, serial)` sur `computers` pour empêcher les doublons de numéro de série par entité.

#### Tables support / tickets (3)

- **`ticket_categories`** — Catégories fonctionnelles des demandes support
- **`tickets`** — Tickets d'incident liés à une entité, un demandeur, un groupe IT et exactement un matériel
- **`ticket_followups`** — Échanges et suivis rattachés aux tickets

#### Tables réseau (10)

- **`network_ports`** — Résolution du polymorphisme GLPI : 6 colonnes FK nullable (`computers_id`, `monitors_id`, etc.) avec contrainte CHECK garantissant **exactement un parent**
- **`network_names`**, **`ip_addresses`** — Noms DNS et adresses IP
- **`network_connections`** — Connexions port-à-port (CHECK `port1 ≠ port2`)
- **`vlans`**, **`network_port_vlans`** — VLANs (UNIQUE `entities_id, tag`)
- **`ip_networks`**, **`ip_network_vlans`** — Sous-réseaux IP
- **`fqdns`**, **`sockets`**, **`cables`** — FQDN, prises réseau, câblage

#### Tables système (2)

- **`audit_log`** — Journal d'audit automatique (action CHECK IN INSERT/UPDATE/DELETE)
- **`archives_materiel`** — Archivage des matériels supprimés

> Script : [`02_schema_tables.sql`](../sql/02_schema_tables.sql)

### 3.4 Utilisateurs et rôles Oracle

4 rôles avec des privilèges différenciés :

| Rôle | Droits | Cas d'usage |
|---|---|---|
| `ROLE_ADMIN` | CRUD complet sur toutes les tables | Administration globale |
| `ROLE_TECHNICIEN` | CRUD matériels + réseau, lecture référentiels | Gestion technique |
| `ROLE_CONSULTANT` | SELECT uniquement | Consultation / reporting |
| `ROLE_MANAGER_SITE` | Hérite de TECHNICIEN + gestion utilisateurs/profils | Responsable de site |

6 utilisateurs Oracle créés avec des **quotas** sur les tablespaces adaptés à leur rôle :

- `admin_glpi` — Quota illimité sur tous les tablespaces
- `tech_cergy`, `tech_pau` — 100 Mo matériel + 50 Mo réseau + 50 Mo support
- `consultant` — Aucun quota (lecture seule)
- `manager_cergy`, `manager_pau` — 200 Mo matériel + 100 Mo utilisateurs + 100 Mo réseau + 50 Mo support

> Script : [`03_users_roles.sql`](../sql/03_users_roles.sql)

### 3.5 Index et optimisation

53 index répartis en 5 catégories :

| Type d'index | Nombre | Exemples | Justification |
|---|---|---|---|
| **B-tree simple** | 39 | `idx_comp_entity`, `idx_np_computer`, `idx_ticket_status` | Jointures par FK |
| **Composite** | 4 | `idx_comp_entity_state`, `idx_ticket_entity_status_priority` | Requêtes multi-critères |
| **Fonctionnel** | 3 | `idx_comp_name_upper`, `idx_comp_serial_upper` | Recherche case-insensitive |
| **Bitmap** | 4 | `bmp_comp_state`, `bmp_users_active` | Colonnes à faible cardinalité |
| **Audit** | 3 | `idx_audit_table`, `idx_audit_date` | Consultation du journal d'audit |

Tous les index sont stockés dans le tablespace dédié `TS_INDEX` pour isoler les I/O d'indexation.

> Script : [`04_clusters_indexes.sql`](../sql/04_clusters_indexes.sql)

### 3.6 Vues métier

7 vues simplifient l'accès aux données complexes :

| Vue | Description | Jointures |
|---|---|---|
| `V_INVENTAIRE_COMPLET` | Inventaire consolidé de tous les matériels | UNION ALL 6 tables × 7 LEFT JOIN |
| `V_MATERIEL_PAR_SITE` | Compteurs par site et type | Agrégation sur V_INVENTAIRE_COMPLET |
| `V_UTILISATEURS_PROFILS` | Utilisateurs avec profils et entités | 4 JOIN |
| `V_TOPOLOGIE_RESEAU` | Ports réseau + VLANs + IP + équipements | 11 LEFT JOIN |
| `V_STATISTIQUES_SITE` | Compteurs par entité (sous-requêtes corrélées) | 8 sous-requêtes |
| `V_MATERIEL_RECENT` | Matériels modifiés dans les 30 derniers jours | Filtre sur V_INVENTAIRE_COMPLET |
| `V_TICKETS_SUPPORT` | Tickets avec demandeur, technicien, groupe IT et matériel concerné | 10 LEFT JOIN |

> Script : [`05_views.sql`](../sql/05_views.sql)

### 3.7 PL/SQL

#### Triggers (7)

| Trigger | Table | Événement | Action |
|---|---|---|---|
| `TRG_AUTO_DATE_MOD_COMPUTERS` | computers | BEFORE UPDATE | Met à jour `date_mod` |
| `TRG_AUTO_DATE_MOD_MONITORS` | monitors | BEFORE UPDATE | Met à jour `date_mod` |
| `TRG_AUTO_DATE_MOD_USERS` | users | BEFORE UPDATE | Met à jour `date_mod` |
| `TRG_AUTO_DATE_MOD_NETPORTS` | network_ports | BEFORE UPDATE | Met à jour `date_mod` |
| `TRG_AUDIT_COMPUTERS` | computers | AFTER INSERT/UPDATE/DELETE | Journalisation dans `audit_log` |
| `TRG_CHECK_COMPUTER_TYPE` | computers | BEFORE INSERT/UPDATE | Vérifie la catégorie du type/modèle |
| `TRG_CHECK_MONITOR_TYPE` | monitors | BEFORE INSERT/UPDATE | Vérifie la catégorie du type |
| `TRG_ARCHIVE_COMPUTER_DELETE` | computers | BEFORE DELETE | Archive dans `archives_materiel` |
| `TRG_CASCADE_SITE_CODE` | entities | AFTER UPDATE OF site_code | Propage aux sous-entités |

#### Procédures stockées (4)

| Procédure | Paramètres | Fonction |
|---|---|---|
| `SP_TRANSFERT_MATERIEL` | computer_id, new_entity_id, new_user_id | Transfert d'un ordinateur entre sites (local ou via DB Link) |
| `SP_AFFECTER_PROFIL` | user_id, profile_id, entity_id, is_recursive | Affectation/mise à jour de profil |
| `SP_INVENTAIRE_SITE` | site_code | Rapport d'inventaire complet pour un site |
| `SP_NETTOYER_ARCHIVES` | nb_mois (défaut 12) | Purge des archives anciennes |

La procédure `SP_TRANSFERT_MATERIEL` est particulièrement notable : elle gère le **transfert inter-sites** via `EXECUTE IMMEDIATE` avec DB Link dynamique, en insérant les données sur le site distant puis en supprimant les lignes locales.

#### Fonctions (4)

| Fonction | Retour | Description |
|---|---|---|
| `FN_COMPTER_MATERIEL_SITE` | NUMBER | Total des matériels d'un site |
| `FN_CALCULER_TAUX_UTILISATION` | NUMBER | % de ports connectés d'un équipement réseau |
| `FN_OBTENIR_SITE_MATERIEL` | VARCHAR2 | Remonte la hiérarchie des entités pour trouver le site_code |
| `FN_VERIFIER_QUOTA_MATERIEL` | NUMBER | Vérifie si un site dépasse un quota (0/1/-1) |

#### Curseurs (4 types différents)

| # | Type de curseur | Usage |
|---|---|---|
| 1 | Curseur explicite paramétré | Inventaire des ordinateurs d'un site |
| 2 | Curseur explicite | Détection des ports réseau orphelins |
| 3 | Curseur FOR loop implicite | Utilisateurs actifs sans profil |
| 4 | REF CURSOR (variable) | Rapport récapitulatif dynamique par entité |

> Scripts : [`06_plsql/`](../sql/06_plsql/)

### 3.8 Base de Données Répartie (BDDR)

#### Architecture distribuée

L'architecture BDDR repose sur deux instances Oracle XE (une par site) connectées par **Database Links** :

```
Instance CERGY                    Instance PAU
┌─────────────────┐              ┌─────────────────┐
│ Données Cergy   │──DBL_PAU──► │ Données Pau     │
│                 │◄─DBL_CERGY──│                 │
│ + Référentiels  │  réplication │ + Référentiels  │
└─────────────────┘              └─────────────────┘
```

#### Stratégie de distribution

| Type de données | Stratégie | Implémentation |
|---|---|---|
| Matériels | **Fragmentation horizontale** | Filtrage par `entities.site_code` |
| Utilisateurs | **Fragmentation horizontale** | Comptes locaux au site |
| Référentiels | **Réplication** | Procédure `SP_REPLIQUER_REFERENTIELS` (MERGE) |
| Réseau | **Fragmentation horizontale** | Infrastructure locale |

#### Éléments implémentés

- **2 DB Links** : `DBL_PAU` (depuis Cergy) et `DBL_CERGY` (depuis Pau)
- **12 synonymes** pour accès transparent aux tables distantes
- **4 vues distribuées** : `V_COMPUTERS_GLOBAL`, `V_USERS_GLOBAL`, `V_STATS_GLOBAL`, `V_TICKETS_GLOBAL`
- **1 procédure de réplication** : `SP_REPLIQUER_REFERENTIELS` utilisant `MERGE` pour synchroniser 5 tables de référence

> Script : [`07_bddr.sql`](../sql/07_bddr.sql)

### 3.9 Plans de requêtes

L'analyse des plans d'exécution via `EXPLAIN PLAN` et `DBMS_XPLAN.DISPLAY` a été réalisée sur 6 requêtes représentatives :

| Requête | Opération sans index | Opération avec index |
|---|---|---|
| Q1 — Recherche par nom | TABLE ACCESS FULL | INDEX RANGE SCAN (fonctionnel) |
| Q2 — Inventaire d'un site | TABLE ACCESS FULL + SORT | INDEX RANGE SCAN (composite) |
| Q3 — Statistiques VLAN | HASH JOIN + FULL | INDEX RANGE SCAN (B-tree) |
| Q4 — Recherche par serial | TABLE ACCESS FULL | INDEX RANGE SCAN (fonctionnel) |
| Q5 — Vue inventaire | 6× TABLE ACCESS FULL | 6× INDEX RANGE SCAN |
| Q6 — Utilisateurs profils | TABLE ACCESS FULL + SORT | INDEX RANGE SCAN + BITMAP |

Le protocole de comparaison utilise `ALTER INDEX ... INVISIBLE/VISIBLE` pour basculer entre les deux scénarios sans recréer les index.

> Script : [`08_query_plans.sql`](../sql/08_query_plans.sql)

---

## 4. Phase 3 — Tests de performance

### 4.1 Génération du jeu de test

La procédure `SP_GENERER_JEU_DE_TEST` crée environ **21 100 lignes** de données réalistes :

| Table | Lignes | Répartition |
|---|---|---|
| Ordinateurs | 3 000 | 60% Cergy, 40% Pau |
| Moniteurs | 2 000 | 60/40 |
| Périphériques | 1 200 | 60/40 |
| Téléphones | 400 | 60/40 |
| Imprimantes | 160 | 60/40 |
| Équipements réseau | 80 | 60/40 |
| Utilisateurs | 1 000 | 60/40 |
| Ports réseau | ~6 920 | Proportionnel aux actifs |
| Autres (VLANs, IP, etc.) | ~6 080 | - |

Les données sont réalistes : noms de matériels contextualisés (`PC-CERGY-xxxx`), numéros de série formatés (`SN-2026-xxxxx`), adresses MAC valides, adresses IP cohérentes par VLAN.

> Script : [`09_test_data.sql`](../sql/09_test_data.sql)

### 4.2 Protocole de benchmark

Le benchmark compare les performances de **8 requêtes** dans deux scénarios :

- **Scénario A** (Sans index) : Tous les index rendus `INVISIBLE` → Full Table Scan systématique
- **Scénario B** (Avec index) : Index `VISIBLE` → utilisation des index B-tree, composites, fonctionnels et bitmap

Chaque requête est exécutée **5 fois**, le temps moyen est retenu. Le cache Oracle est vidé entre les scénarios.

### 4.3 Résultats

| ID | Requête | Sans index (ms) | Avec index (ms) | Gain |
|---|---|---|---|---|
| Q1 | Recherche par nom (UPPER) | 45.2 | 2.8 | **93.8%** |
| Q2 | Inventaire site complet | 128.5 | 38.4 | **70.1%** |
| Q3 | Statistiques VLAN agrégées | 85.3 | 31.7 | **62.8%** |
| Q4 | Recherche par serial (UPPER) | 42.8 | 2.5 | **94.2%** |
| Q5 | Vue inventaire par site | 312.6 | 145.2 | **53.6%** |
| Q6 | Utilisateurs avec profils | 95.4 | 28.6 | **70.0%** |
| Q7 | Matériel par fabricant/site | 78.2 | 22.3 | **71.5%** |
| Q8 | Topologie réseau complète | 265.8 | 98.5 | **62.9%** |

### 4.4 Analyse des résultats

**Gain moyen : 62%** sur l'ensemble des requêtes.

#### Requêtes ponctuelles (Q1, Q4) — Gain ~94%

Les index **fonctionnels** (`UPPER(name)`, `UPPER(serial)`) transforment un Full Table Scan en un INDEX RANGE SCAN ciblé. Le gain est spectaculaire car la sélectivité est maximale (1 ligne retournée).

#### Requêtes analytiques (Q2, Q6, Q7) — Gain ~70%

Les index **composites** (`entities_id, states_id`) et les index sur FK permettent à l'optimiseur de réduire considérablement les opérations de jointure. Le Nested Loop remplace le Hash Join.

#### Vues complexes (Q5, Q8) — Gain ~55%

Les vues `V_INVENTAIRE_COMPLET` (6 UNION ALL × 7 jointures) et `V_TOPOLOGIE_RESEAU` (11 jointures) restent coûteuses, mais les index sous-jacents sur chaque table participant réduisent le coût unitaire de chaque branche.

#### Points d'attention

- Les index **bitmap** sont optimaux en lecture mais **incompatibles** avec les environnements à forte concurrence DML
- La vue `V_INVENTAIRE_COMPLET` pourrait être matérialisée (`MATERIALIZED VIEW`) pour les dashboards
- Les gains seraient plus importants avec des volumes de production (50k+ lignes)

> Script : [`10_benchmark.sql`](../sql/10_benchmark.sql)  
> Rapport interactif : [`performance_report.html`](performance_report.html)

---

## 5. Conclusion

### 5.1 Bilan

Ce projet a permis de démontrer la faisabilité et les bénéfices d'une refonte architecturale d'une base de données applicative complexe (GLPI) vers une architecture Oracle distribuée :

| Aspect | GLPI original | Nouvelle BDD |
|---|---|---|
| Intégrité | Aucune FK | FK explicites sur toutes les relations |
| Polymorphisme | `itemtype`/`items_id` | FK classiques + CHECK |
| Stockage | Pas de tablespaces | 6 tablespaces dédiés |
| Accès données | Pas de vues | 7 vues métier |
| Logique métier | Tout en PHP | PL/SQL (triggers, procédures, fonctions) |
| Architecture | Monolithique | BDDR avec DB Links |
| Types/Modèles | 12 tables redondantes | 2 tables consolidées |
| Performance | Index sans analyse | 53 index optimisés, gain moyen 62% |

### 5.2 Compétences mises en œuvre

- **Reverse engineering** d'une base de données en production
- **Modélisation** relationnelle avancée (consolidation, élimination du polymorphisme)
- **Oracle** : tablespaces, utilisateurs, rôles, quotas
- **PL/SQL** : triggers, procédures, fonctions, curseurs (4 types)
- **Indexation** : B-tree, composites, fonctionnels, bitmap
- **BDDR** : DB Links, synonymes, vues distribuées, réplication par MERGE
- **Performance** : EXPLAIN PLAN, benchmarking, analyse comparative

### 5.3 Améliorations possibles

1. **Materialized Views** avec rafraîchissement programmé pour les vues coûteuses
2. **Partitionnement** des tables volumineuses par date ou site
3. **Oracle Advanced Queuing** pour la réplication asynchrone entre sites
4. **Oracle Data Guard** pour la haute disponibilité
5. **Compression** des tablespaces pour réduire l'empreinte disque
