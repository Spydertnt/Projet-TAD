# Documentation Technique - Base GLPI Multi-Sites

## Vue D'ensemble

Le projet modelise une base GLPI simplifiee pour deux sites, `CERGY` et `PAU`. Le modele est centre sur `assets`, qui regroupe les ordinateurs, imprimantes, telephones, peripheriques, moniteurs et equipements reseau dans une seule table.

La BDDR est simulee sur une seule instance Oracle avec deux schemas locaux :

- `GLPI_CERGY`
- `GLPI_PAU`

Ces schemas exposent des vues filtrees par `sites.site_code`, puis des DB links locaux permettent de montrer une interrogation inter-sites.

## Diagrammes

| Diagramme | Fichier |
|---|---|
| Architecture | `docs/diagrams/architecture.svg` |
| MCD | `docs/diagrams/mcd.svg` |
| UML | `docs/diagrams/uml.svg` |
| MLD textuel | `docs/mld.md` |

Regeneration :

```bash
python scripts/generate_diagrams.py
python scripts/generate_uml_diagram.py
```

## Tables

### `sites`

Represente les sites ou structures organisationnelles. Dans ce projet, les sites physiques sont identifies par `site_code = 'CERGY'` ou `site_code = 'PAU'`.

| Champ | Role |
|---|---|
| `id` | Identifiant du site |
| `name` | Nom court |
| `parent_site_id` | Site parent, pour une hierarchie simple |
| `full_name` | Nom complet lisible |
| `site_code` | Code de distribution des donnees |
| `created_at`, `updated_at` | Dates techniques |

### `locations`

Emplacements physiques des utilisateurs et materiels.

| Champ | Role |
|---|---|
| `site_id` | Site de rattachement |
| `parent_location_id` | Localisation parente |
| `building`, `room` | Niveau batiment/salle |
| `full_name` | Chemin complet |

### `manufacturers`

Referentiel des fabricants : Dell, HP, Lenovo, Cisco, Epson, etc.

### `states`

Referentiel d'etat des materiels : en service, stock, maintenance, hors service, a renouveler.

### `users`

Utilisateurs metier, demandeurs, techniciens et responsables.

| Champ | Role |
|---|---|
| `login` | Identifiant unique |
| `site_id` | Site principal |
| `location_id` | Localisation principale |
| `supervisor_user_id` | Responsable |
| `is_active` | Activation du compte |

### `profiles`

Profils applicatifs simplifies : administrateur, technicien, manager site, utilisateur.

### `profiles_users`

Association entre utilisateur, profil et site. `is_recursive` permet d'etendre le profil a des sous-sites.

### `groups`

Groupes fonctionnels par site : support IT, equipe reseau, administration.

### `groups_users`

Association entre utilisateurs et groupes. `is_manager` indique un responsable de groupe.

### `assets`

Table centrale de l'inventaire. Elle evite de multiplier les tables par type de materiel.

| Champ | Role |
|---|---|
| `asset_type` | Type fonctionnel : `COMPUTER`, `PRINTER`, etc. |
| `serial_number` | Numero de serie, unique par site |
| `owner_user_id` | Utilisateur principal |
| `technician_user_id` | Technicien responsable |
| `manufacturer_id` | Fabricant |
| `state_id` | Etat du materiel |

### `ticket_categories`

Referentiel des categories support : incident materiel, demande reseau, installation, acces utilisateur, gestion du stock.

### `tickets`

Demandes et incidents lies a un materiel.

| Champ | Role |
|---|---|
| `asset_id` | Materiel concerne |
| `requester_user_id` | Demandeur |
| `assigned_group_id` | Groupe support affecte |
| `status` | Cycle de vie : nouveau, assigne, en cours, resolu, clos |
| `priority` | Priorite |
| `description`, `resolution` | Textes longs en CLOB |

### `ticket_users`

Techniciens affectes a un ticket. Un trigger verifie que l'utilisateur affecte possede le profil `Technicien`.

### `ticket_followups`

Historique textuel d'un ticket : demande initiale, diagnostic, resolution.

### `network_ports`

Ports reseau rattaches aux assets. Un equipement peut avoir plusieurs ports.

### `ip_networks`

Sous-reseaux IP d'un site : utilisateurs, serveurs, imprimantes, Wi-Fi. Les colonnes `vlan_name` et `vlan_tag` representent le VLAN sans table supplementaire.

### `ip_addresses`

Adresses IP affectees aux ports reseau.

### `audit_log`

Journal d'audit alimente par le trigger `TRG_AUDIT_ASSETS` lors des insertions, modifications et suppressions d'assets.

### `archives_materiel`

Archive fonctionnelle des assets supprimes, alimentee avant suppression par `TRG_ARCHIVE_ASSET_DELETE`.

## Vues Metier

| Vue | Utilite |
|---|---|
| `V_INVENTAIRE_COMPLET` | Inventaire enrichi avec site, localisation, proprietaire, fabricant et etat |
| `V_MATERIEL_PAR_SITE` | Comptage des materiels par site et type |
| `V_UTILISATEURS_PROFILS` | Liste des utilisateurs avec profils et sites d'application |
| `V_TOPOLOGIE_RESEAU` | Vue des ports, IP, sous-reseaux et VLAN |
| `V_STATISTIQUES_SITE` | Indicateurs par site |
| `V_MATERIEL_RECENT` | Materiels modifies dans les 30 derniers jours |
| `V_TICKETS_SUPPORT` | Tickets enrichis avec demandeur, techniciens, groupe, categorie et materiel |

## Fonctions PL/SQL

| Fonction | Parametres | Role |
|---|---|---|
| `FN_COMPTER_MATERIEL_SITE` | `p_site_code` | Retourne le nombre d'assets d'un site |
| `FN_CALCULER_TAUX_UTILISATION` | `p_asset_id` | Calcule le pourcentage de ports avec IP sur un asset |
| `FN_OBTENIR_SITE_ENTITE` | `p_site_id` | Remonte la hierarchie pour retrouver le code site |
| `FN_VERIFIER_QUOTA_MATERIEL` | `p_site_code`, `p_quota_max` | Retourne `1` si le quota est atteint, `0` sinon, `-1` en erreur |

## Procedures PL/SQL

| Procedure | Role |
|---|---|
| `SP_TRANSFERT_MATERIEL` | Simule le transfert inter-sites d'un materiel en changeant `site_id` sur l'asset, ses ports et ses IP |
| `SP_AFFECTER_PROFIL` | Cree ou met a jour l'affectation d'un profil utilisateur |
| `SP_CREER_TICKET_MATERIEL` | Cree un ticket sur un asset et peut affecter directement un technicien |
| `SP_ASSIGNER_TECH_TICKET` | Affecte un technicien a un ticket existant |
| `SP_INVENTAIRE_SITE` | Affiche un resume DBMS_OUTPUT par site |
| `SP_NETTOYER_ARCHIVES` | Supprime les archives trop anciennes |
| `SP_GENERER_JEU_DE_TEST` | Genere les donnees de test enrichies |
| `SP_REPLIQUER_REFERENTIELS` | Procedure de demonstration BDDR locale |

## Triggers

| Trigger | Table | Role |
|---|---|---|
| `TRG_AUTO_DATE_MOD_ASSETS` | `assets` | Met a jour `updated_at` |
| `TRG_AUTO_DATE_MOD_USERS` | `users` | Met a jour `updated_at` |
| `TRG_AUTO_DATE_MOD_NETPORTS` | `network_ports` | Met a jour `updated_at` |
| `TRG_AUTO_DATE_MOD_TICKETS` | `tickets` | Met a jour les dates de workflow |
| `TRG_CHECK_TICKET_USER_TECH` | `ticket_users` | Interdit d'affecter un non-technicien |
| `TRG_AUDIT_ASSETS` | `assets` | Journalise les changements |
| `TRG_ARCHIVE_ASSET_DELETE` | `assets` | Archive avant suppression |
| `TRG_CASCADE_SITE_CODE` | `sites` | Propage un changement de `site_code` aux enfants |

## Curseurs

Le fichier `cursors.sql` fournit des blocs de demonstration :

- inventaire detaille du site Cergy ;
- ports reseau sans adresse IP ;
- utilisateurs actifs sans profil ;
- rapport recapitulatif dynamique par site.

## Clusters Et Index

Les clusters physiques sont crees dans `02_schema_tables.sql` :

| Cluster | Cle | Tables |
|---|---|---|
| `cluster_user_rights` | `user_id` | `users`, `profiles_users`, `groups_users` |
| `cluster_site_structure` | `site_id` | `sites`, `locations`, `groups`, `ip_networks` |
| `cluster_network_port_ips` | `network_port_id` | `network_ports`, `ip_addresses` |

Les index classiques sont dans `04_clusters_indexes.sql` :

- index sur cles etrangeres ;
- index composites pour les requetes metier ;
- index fonctionnels sur `UPPER(name)`, `UPPER(serial_number)`, `UPPER(login)`, `UPPER(email)` ;
- bitmap index sur colonnes a faible cardinalite.

## BDDR Locale

Le fichier `07_bddr.sql` cree deux schemas de simulation :

- `GLPI_CERGY` expose les vues du fragment Cergy ;
- `GLPI_PAU` expose les vues du fragment Pau.

Chaque schema peut interroger l'autre via un DB link local :

- `lien_pau` depuis `GLPI_CERGY` ;
- `lien_cergy` depuis `GLPI_PAU`.

Les vues globales `V_ASSETS_GLOBAL`, `V_USERS_GLOBAL`, `V_STATS_GLOBAL` et `V_TICKETS_GLOBAL` font des `UNION ALL` entre le fragment local et le fragment distant.

## Donnees De Test

Le jeu de test genere par `09_test_data.sql` contient par defaut :

- 2 sites ;
- 6 localisations ;
- 300 utilisateurs ;
- 1400 assets ;
- plusieurs groupes, profils, categories, fabricants et etats ;
- 8 sous-reseaux IP ;
- des ports reseau et adresses IP ;
- des tickets, affectations et suivis.
