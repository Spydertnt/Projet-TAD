# Présentation Orale — Mini-Projet GLPI Multi-Sites

> **CY Tech — TAD 2025-2026**  
> Durée : 10-15 minutes  
> Support pour la soutenance

---

## Slide 1 — Page de titre

### Refonte BDD GLPI — Architecture Oracle Multi-Sites

**Mini-Projet TAD 2025-2026**

*CY Tech — Cergy / Pau*

---

## Slide 2 — Sommaire

1. Contexte & objectifs
2. Phase 1 — Reverse engineering
3. Phase 2 — Nouvelle architecture
4. Phase 3 — Tests de performance
5. Démonstration
6. Conclusion

---

## Slide 3 — Contexte

### Qu'est-ce que GLPI ?

- Logiciel **open-source** de gestion de parc IT
- +250 tables MySQL, pas de contraintes FK
- Gestion : matériels, utilisateurs, réseau, tickets

### Problème posé

> Comment migrer une BDD monolithique MySQL vers une **architecture Oracle distribuée** adaptée à 2 sites (Cergy/Pau) ?

**Notes orales :**
> *GLPI c'est un logiciel très utilisé en entreprise pour gérer le parc informatique. Sa base de données MySQL fait plus de 250 tables, mais elle a un gros problème : aucune contrainte de clé étrangère n'est définie. Toute l'intégrité repose sur le code PHP. Notre projet consiste à la redesigner pour Oracle avec une vraie architecture distribuée.*

---

## Slide 4 — Phase 1 : Reverse Engineering

### Analyse de l'existant

| Problème | Impact |
|---|---|
| Aucune FK explicite | Intégrité non garantie |
| Polymorphisme (`itemtype`/`items_id`) | Jointures impossibles à contraindre |
| 12 tables types/modèles redondantes | Structure dupliquée |
| Base monolithique | Pas de multi-sites |
| Aucun PL/SQL | Logique métier = PHP |

### Périmètre retenu

- **30 tables** dans 3 domaines : matériels (14), utilisateurs (8), réseau (12)

**Notes orales :**
> *On a analysé le code source sur GitHub, en particulier le fichier `glpi-empty.sql`. On a identifié 30 tables dans notre périmètre. Le constat principal c'est qu'il n'y a aucune FK, que le polymorphisme rend les jointures complexes, et qu'il y a beaucoup de redondance dans les tables de types et modèles — 6 tables de types et 6 tables de modèles avec quasiment la même structure.*

---

## Slide 5 — Phase 2 : Architecture globale

### Schéma d'architecture

```
ORACLE XE — CERGY          ORACLE XE — PAU
┌───────────────┐           ┌───────────────┐
│ TS_MATERIEL   │◄─DB Link─►│ TS_MATERIEL   │
│ TS_UTILISATEURS│          │ TS_UTILISATEURS│
│ TS_RESEAU     │           │ TS_RESEAU     │
│ TS_SUPPORT    │           │ TS_SUPPORT    │
│ TS_INDEX      │           │ TS_INDEX      │
└───────────────┘           └───────────────┘
```

### Chiffres clés

| Élément | Nombre |
|---|---|
| Tables | **36** (avec FK explicites) |
| Tablespaces | **6** |
| Vues métier | **7** |
| Index | **53** |
| Rôles Oracle | **4** |
| Utilisateurs Oracle | **6** |

**Notes orales :**
> *Notre nouvelle architecture utilise deux instances Oracle XE connectées par Database Links. On a 36 tables avec des FK explicites partout, 6 tablespaces pour séparer physiquement les données, et 4 rôles Oracle avec des privilèges différenciés. Les données sont fragmentées horizontalement par site — chaque site stocke ses matériels, utilisateurs et tickets — tandis que les référentiels comme les fabricants, les types et les catégories de tickets sont répliqués.*

---

## Slide 6 — Résolution des problèmes GLPI

### Avant / Après

| Problème GLPI | Solution implémentée |
|---|---|
| Pas de FK | FK explicites sur **toutes** les relations |
| Polymorphisme | 6 colonnes FK nullable + `CHECK (exactement 1 parent)` |
| 12 tables redondantes | 2 tables consolidées (`asset_types`, `asset_models`) avec `category` |
| Monolithique | BDDR : DB Links + synonymes + vues distribuées |
| Pas de PL/SQL | 8 triggers, 5 procédures, 4 fonctions, 4 curseurs |
| Pas de vues | 7 vues métier (inventaire, topologie, statistiques, tickets) |

**Notes orales :**
> *Point par point : les FK sont maintenant toutes explicites. Le polymorphisme de `network_ports` et des tickets est résolu par 6 colonnes FK nullable avec une contrainte CHECK qui garantit qu'exactement un parent est renseigné. Les 12 tables de types et modèles sont consolidées en 2 tables avec un champ `category`. Et on a ajouté tout le PL/SQL qui manquait : triggers d'audit, procédures de transfert inter-sites et de création de tickets, fonctions de calcul, et 4 types de curseurs différents.*

---

## Slide 7 — PL/SQL en détail

### Triggers

- **Date_mod automatique** : sur computers, monitors, users, network_ports
- **Audit** : journalisation INSERT/UPDATE/DELETE dans `audit_log`
- **Validation** : vérifie la catégorie du type assigné (`COMPUTER` → table `computers`)
- **Archivage** : sauvegarde automatique avant DELETE
- **Cascade** : propagation du `site_code` aux sous-entités

### Procédure phare : SP_TRANSFERT_MATERIEL

```
Transfert local (même site) :
  → UPDATE simple de entities_id

Transfert inter-sites (Cergy → Pau) :
  → INSERT via DB Link dans la base distante
  → DELETE local
  → Transfert atomique (ROLLBACK si erreur)
```

### Curseurs : 4 types utilisés

1. Curseur **explicite paramétré** (OPEN/FETCH/CLOSE)
2. Curseur **explicite** classique
3. Curseur **FOR loop implicite**
4. **REF CURSOR** (curseur variable dynamique)

**Notes orales :**
> *En PL/SQL, on a implémenté 8 triggers. Le plus intéressant c'est le trigger d'audit qui log automatiquement toute modification sur les ordinateurs. La procédure `SP_TRANSFERT_MATERIEL` gère le transfert d'un ordinateur entre sites, et `SP_CREER_TICKET_MATERIEL` centralise la création d'un ticket envoyé au service IT. On a aussi démontré les 4 types de curseurs PL/SQL : curseur explicite paramétré avec OPEN/FETCH/CLOSE, curseur explicite classique, FOR loop implicite, et REF CURSOR dynamique.*

---

## Slide 8 — BDDR

### Architecture distribuée

| Élément | Implémentation |
|---|---|
| DB Links | `DBL_PAU` (Cergy→Pau), `DBL_CERGY` (Pau→Cergy) |
| Synonymes | 12 synonymes pour accès transparent |
| Fragmentation | Horizontale par `site_code` |
| Réplication | `SP_REPLIQUER_REFERENTIELS` (MERGE sur 6 tables) |
| Vues globales | `V_COMPUTERS_GLOBAL`, `V_USERS_GLOBAL`, `V_STATS_GLOBAL`, `V_TICKETS_GLOBAL` |

### Réplication par MERGE

```sql
MERGE INTO manufacturers@DBL_PAU dest
USING manufacturers src ON (dest.id = src.id)
WHEN MATCHED THEN UPDATE ...
WHEN NOT MATCHED THEN INSERT ...;
```

**Notes orales :**
> *La BDDR repose sur des Database Links Oracle. La fragmentation est horizontale : chaque site stocke ses propres données, filtrées par le `site_code` de l'entité. Les référentiels comme les fabricants, les états, les types et modèles d'assets sont répliqués entre les deux sites par une procédure de MERGE. On a aussi créé des vues distribuées qui agrègent les données des deux sites de manière transparente.*

---

## Slide 9 — Phase 3 : Benchmarks

### Protocole

- **~21 100 lignes** de données réalistes générées en PL/SQL
- **8 requêtes** testées (ponctuelles, analytiques, vues complexes)
- **2 scénarios** : index INVISIBLE vs VISIBLE
- **5 exécutions** par requête, temps moyen retenu

### Résultats

| Type de requête | Gain moyen |
|---|---|
| Recherche ponctuelle (Q1, Q4) | **~94%** |
| Requête analytique (Q2, Q6, Q7) | **~70%** |
| Vue complexe (Q5, Q8) | **~55%** |
| **Gain moyen global** | **62%** |

**Notes orales :**
> *Pour valider les performances, on a généré environ 20 000 lignes de données réalistes avec une procédure PL/SQL. On a testé 8 requêtes dans deux scénarios : avec et sans index. Le gain moyen est de 62%. Les recherches ponctuelles par nom ou serial bénéficient le plus des index fonctionnels avec un gain de 94% — le Full Table Scan est remplacé par un Index Range Scan. Les requêtes analytiques gagnent environ 70% grâce aux index composites, et même les vues les plus complexes avec 7+ jointures gagnent 55%.*

---

## Slide 10 — Graphique de performance

### Temps d'exécution moyen par requête (ms)

```
Q1 │ ████████████████████████████████████████████ 45.2  → ██ 2.8     (-94%)
Q2 │ ████████████████████████████████████████████████████████████████ 128.5 → ████████████████████ 38.4 (-70%)
Q3 │ ████████████████████████████████████████████ 85.3  → ████████████████ 31.7 (-63%)
Q4 │ ███████████████████████████████████████████ 42.8   → █ 2.5      (-94%)
Q5 │ ████████████████████████████████████████████████████████████████████████████████████ 312.6 → ████████████████████████████████████████████████ 145.2 (-54%)
Q6 │ █████████████████████████████████████████████████ 95.4 → ██████████████ 28.6  (-70%)
Q7 │ ████████████████████████████████████████ 78.2    → ███████████ 22.3 (-71%)
Q8 │ ██████████████████████████████████████████████████████████████████████████ 265.8 → █████████████████████████████████████ 98.5 (-63%)
```

🔴 Sans index  🟢 Avec index

> Rapport interactif avec graphiques Chart.js : `performance_report.html`

**Notes orales :**
> *Voici la visualisation des résultats. En rouge les temps sans index, en vert avec index. On voit clairement que Q1 et Q4 — les recherches ponctuelles — sont les grandes gagnantes. Q5 et Q8 restent les plus coûteuses car ce sont des vues avec des UNION ALL et beaucoup de jointures, mais elles gagnent quand même plus de 50%. On a aussi un rapport HTML interactif avec des graphiques Chart.js si vous voulez explorer les résultats en détail.*

---

## Slide 11 — Arborescence du projet

```
Projet-TAD/
├── docs/
│   ├── reverse_engineering_glpi.md    ← Phase 1
│   ├── rapport.md                     ← Rapport complet
│   ├── presentation.md                ← Ce document
│   └── performance_report.html        ← Rapport interactif
└── sql/
    ├── 00_architecture.md             ← Doc technique
    ├── 01_tablespaces.sql             ← 6 tablespaces
    ├── 02_schema_tables.sql           ← 36 tables, FK explicites
    ├── 03_users_roles.sql             ← 4 rôles, 6 utilisateurs
    ├── 04_clusters_indexes.sql        ← 53 index
    ├── 05_views.sql                   ← 7 vues métier
    ├── 06_plsql/                      ← Triggers, procédures, fonctions, curseurs
    ├── 07_bddr.sql                    ← DB Links, synonymes, vues distribuées
    ├── 08_query_plans.sql             ← EXPLAIN PLAN
    ├── 09_test_data.sql               ← ~20 000 lignes de test
    └── 10_benchmark.sql               ← Suite de benchmarks
```

**Notes orales :**
> *Voici la structure du projet. Tous les scripts SQL sont numérotés dans l'ordre d'exécution, de 01 à 10. Le PL/SQL est séparé dans un sous-dossier. La documentation comprend le reverse engineering, le rapport complet, et le rapport de performance interactif en HTML.*

---

## Slide 12 — Conclusion

### Ce que le projet démontre

✅ Reverse engineering d'une BDD complexe (+250 tables)  
✅ Résolution de problèmes structurels (polymorphisme, redondance, absence de FK)  
✅ Architecture Oracle complète (tablespaces, rôles, quotas, PL/SQL)  
✅ Distribution multi-sites (DB Links, fragmentation horizontale, réplication)  
✅ Gains de performance validés (**62% moyen**, jusqu'à **94%**)  

### Améliorations possibles

- Materialized Views pour les vues coûteuses
- Partitionnement par date ou site
- Oracle Data Guard pour la haute disponibilité

**Notes orales :**
> *En conclusion, ce projet nous a permis de mettre en pratique les concepts avancés de bases de données : reverse engineering, modélisation Oracle, PL/SQL complet, BDDR, et optimisation des performances. Le gain moyen de 62% valide notre stratégie d'indexation, et l'architecture est extensible vers des solutions comme les Materialized Views ou Oracle Data Guard. Merci pour votre attention, je suis prêt pour les questions.*

---

## Questions fréquentes (préparation)

### Pourquoi avoir choisi des colonnes FK nullable plutôt que le polymorphisme ?
> Les FK nullable avec une contrainte CHECK garantissent l'intégrité référentielle au niveau SGBD. Le polymorphisme de GLPI (`itemtype`/`items_id`) empêche toute contrainte FK et oblige à gérer l'intégrité dans le code applicatif.

### Pourquoi des index bitmap sur `states_id` et `is_active` ?
> Ces colonnes ont une **faible cardinalité** (3-5 valeurs pour `states_id`, 0/1 pour `is_active`). Les index bitmap sont optimaux pour ce type de données en lecture. Cependant, ils sont déconseillés en environnement OLTP à forte concurrence DML car ils verrouillent des segments entiers.

### Comment fonctionne le transfert inter-sites ?
> La procédure `SP_TRANSFERT_MATERIEL` utilise `EXECUTE IMMEDIATE` pour construire dynamiquement les requêtes INSERT/DELETE via DB Link. Le transfert est atomique : si l'insertion distante échoue, un ROLLBACK annule tout.

### Pourquoi MERGE pour la réplication ?
> `MERGE` (upsert) permet de synchroniser en une seule opération : si la ligne existe, on la met à jour ; sinon, on l'insère. C'est plus efficace qu'un DELETE + INSERT et plus robuste qu'un simple INSERT avec gestion d'exception.

### Quels types de curseurs avez-vous utilisés et pourquoi ?
> 4 types : (1) **Curseur explicite paramétré** pour les requêtes réutilisables avec paramètres, (2) **Curseur explicite** classique avec OPEN/FETCH/CLOSE pour un contrôle fin, (3) **FOR loop implicite** pour la simplicité quand on n'a pas besoin de contrôle, (4) **REF CURSOR** pour les requêtes dynamiques construites à l'exécution.

### Pourquoi 6 tablespaces séparés ?
> La séparation permet : (a) des sauvegardes/restaurations granulaires par domaine, (b) le placement sur des disques différents pour répartir les I/O, (c) des quotas différenciés par utilisateur et domaine, (d) l'isolation des index pour éviter la contention.
