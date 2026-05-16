# Mini-Projet GLPI - Nouvelle BDD Multi-Sites

> CY Tech - TAD 2025-2026  
> Refonte simplifiee d'une base GLPI vers Oracle XE distribue entre Cergy et Pau.

## Objectif

Le projet simplifie le schema GLPI original pour obtenir une base Oracle plus lisible, contrainte et defendable. Le modele garde uniquement le noyau utile : organisation multi-sites, utilisateurs, inventaire, tickets support, reseau minimal, audit et archivage.

La table centrale est `assets`. Elle remplace les tables separees de GLPI comme `computers`, `monitors`, `printers`, `phones`, `peripherals` et `network_equipments`.

## Architecture

```text
Oracle XE local
|-- schema GLPI_CERGY : vues du fragment Cergy
`-- schema GLPI_PAU   : vues du fragment Pau

Donnees fragmentees par site :
- assets
- users
- tickets
- network_ports
- ip_networks
- ip_addresses

Referentiels repliques :
- manufacturers
- states
- ticket_categories
```

Le champ `sites.site_code` indique le site proprietaire des donnees : `CERGY` ou `PAU`.
La BDDR est simulee sur un seul PC avec deux utilisateurs Oracle locaux.

## Structure

```text
Projet-TAD/
|-- README.md
|-- docs/
|   |-- rapport.md
|   |-- presentation.md
|   |-- reverse_engineering_glpi.md
|   `-- diagrams/
|       |-- architecture.svg
|       |-- mcd.svg
|       `-- uml.svg
|-- scripts/
|   |-- generate_diagrams.py
|   `-- generate_uml_diagram.py
`-- sql/
    |-- 00_architecture.md
    |-- 00_run_all.sql
    |-- 01_tablespaces.sql
    |-- 02_schema_tables.sql
    |-- 03_users_roles.sql
    |-- 04_clusters_indexes.sql
    |-- 05_views.sql
    |-- 06_plsql/
    |-- 07_bddr.sql
    |-- 08_query_plans.sql
    |-- 09_test_data.sql
    `-- 10_benchmark.sql
```

## Execution

Execution simple :

```sql
CONNECT system/mot_de_passe@localhost:1521/XE
START H:\Desktop\S4\Administration_et_traitement_des_donnees\Projet-TAD\sql\00_run_all.sql
```

Execution fichier par fichier :

```sql
@01_tablespaces.sql
@02_schema_tables.sql
@04_clusters_indexes.sql
@03_users_roles.sql
@05_views.sql
@06_plsql/triggers.sql
@06_plsql/procedures.sql
@06_plsql/functions.sql
@06_plsql/cursors.sql
@09_test_data.sql
@08_query_plans.sql
@10_benchmark.sql
@07_bddr.sql
```

## Diagrammes

```bash
python scripts/generate_diagrams.py
python scripts/generate_uml_diagram.py
```

`generate_diagrams.py` genere `architecture.svg` et `mcd.svg`. `generate_uml_diagram.py` genere uniquement `uml.svg`.

## Tables

Le modele contient **19 tables** : 17 fonctionnelles et 2 systeme.

| Domaine | Tables |
|---|---|
| Organisation | `sites`, `locations` |
| Referentiels | `manufacturers`, `states`, `ticket_categories` |
| Utilisateurs | `users`, `profiles`, `profiles_users`, `groups`, `groups_users` |
| Inventaire | `assets` |
| Support | `tickets`, `ticket_users`, `ticket_followups` |
| Reseau | `network_ports`, `ip_networks`, `ip_addresses` |
| Systeme | `audit_log`, `archives_materiel` |

## Dictionnaire Des Donnees

### `sites`

Sites et structures logiques : Cergy, Pau, services ou sous-services.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `name` | Nom du site ou de la structure |
| `parent_site_id` | Site ou structure parente |
| `full_name` | Nom complet avec chemin hierarchique |
| `site_code` | Site physique : `CERGY` ou `PAU` |
| `created_at` | Date de creation |
| `updated_at` | Date de derniere modification |

### `locations`

Emplacements physiques des utilisateurs et materiels.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `site_id` | Site de rattachement |
| `name` | Nom de la localisation |
| `parent_location_id` | Localisation parente |
| `full_name` | Chemin complet de la localisation |
| `building` | Batiment |
| `room` | Salle ou bureau |
| `created_at` | Date de creation |
| `updated_at` | Date de derniere modification |

### `manufacturers`

Referentiel des fabricants.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `name` | Nom du fabricant |

### `states`

Referentiel des etats d'un materiel.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `name` | Etat : en service, stock, maintenance, hors service |

### `users`

Utilisateurs, demandeurs et techniciens.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `login` | Identifiant de connexion |
| `last_name` | Nom |
| `first_name` | Prenom |
| `email` | Adresse email |
| `phone` | Telephone |
| `site_id` | Site principal |
| `location_id` | Localisation principale |
| `supervisor_user_id` | Responsable hierarchique |
| `is_active` | Compte actif ou non |
| `created_at` | Date de creation |
| `updated_at` | Date de derniere modification |

### `profiles`

Profils applicatifs simplifiant les droits.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `name` | Nom du profil |
| `interface` | Interface associee : `central` ou `helpdesk` |
| `is_default` | Profil par defaut ou non |

### `profiles_users`

Affectation d'un profil a un utilisateur sur un site.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `user_id` | Utilisateur |
| `profile_id` | Profil |
| `site_id` | Site d'application |
| `is_recursive` | Application aux sous-sites |

### `groups`

Groupes d'utilisateurs, principalement equipes support.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `site_id` | Site du groupe |
| `name` | Nom du groupe |
| `parent_group_id` | Groupe parent |
| `full_name` | Nom complet |
| `created_at` | Date de creation |
| `updated_at` | Date de derniere modification |

### `groups_users`

Membres des groupes.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `user_id` | Utilisateur membre |
| `group_id` | Groupe |
| `is_manager` | Indique si l'utilisateur gere le groupe |

### `assets`

Table centrale de l'inventaire.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `site_id` | Site du materiel |
| `asset_type` | Type : ordinateur, imprimante, telephone, etc. |
| `name` | Nom du materiel |
| `serial_number` | Numero de serie |
| `owner_user_id` | Utilisateur principal |
| `technician_user_id` | Technicien responsable |
| `location_id` | Localisation physique |
| `manufacturer_id` | Fabricant |
| `state_id` | Etat du materiel |
| `created_at` | Date de creation |
| `updated_at` | Date de derniere modification |

### `ticket_categories`

Categories de tickets.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `name` | Nom de la categorie |
| `description` | Description |

### `tickets`

Demandes et incidents associes a un materiel.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `site_id` | Site concerne |
| `asset_id` | Materiel concerne |
| `title` | Titre du ticket |
| `description` | Description detaillee |
| `status` | Etat du ticket |
| `priority` | Priorite |
| `requester_user_id` | Demandeur |
| `assigned_group_id` | Groupe support affecte |
| `category_id` | Categorie du ticket |
| `resolution` | Texte de resolution |
| `created_at` | Date d'ouverture |
| `updated_at` | Date de derniere modification |
| `assigned_at` | Date d'affectation |
| `resolved_at` | Date de resolution |
| `closed_at` | Date de cloture |

### `ticket_users`

Techniciens affectes aux tickets.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `ticket_id` | Ticket concerne |
| `user_id` | Technicien affecte |
| `assigned_by_user_id` | Utilisateur ayant affecte le technicien |
| `assigned_at` | Date d'affectation |

### `ticket_followups`

Commentaires et suivis de tickets.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `ticket_id` | Ticket concerne |
| `user_id` | Auteur |
| `content` | Contenu du suivi |
| `created_at` | Date du suivi |

### `network_ports`

Interfaces reseau des appareils.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `site_id` | Site du port |
| `asset_id` | Materiel possedant le port |
| `port_name` | Nom du port, par exemple `eth0` |
| `mac_address` | Adresse MAC |
| `port_type` | Type de port |
| `created_at` | Date de creation |
| `updated_at` | Date de derniere modification |

### `ip_networks`

Sous-reseaux IP.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `site_id` | Site du sous-reseau |
| `network_name` | Nom fonctionnel |
| `network_address` | Adresse reseau |
| `subnet_mask` | Masque |
| `gateway_address` | Passerelle |
| `vlan_name` | Nom VLAN optionnel |
| `vlan_tag` | Tag VLAN optionnel |
| `created_at` | Date de creation |
| `updated_at` | Date de derniere modification |

### `ip_addresses`

Adresses IP attribuees aux ports.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `site_id` | Site de l'adresse |
| `network_port_id` | Port reseau |
| `ip_network_id` | Sous-reseau |
| `ip_address` | Adresse IP |
| `created_at` | Date de creation |
| `updated_at` | Date de derniere modification |

### `audit_log`

Journalisation des modifications.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `table_name` | Table modifiee |
| `row_id` | Ligne concernee |
| `action` | `INSERT`, `UPDATE` ou `DELETE` |
| `old_data` | Anciennes valeurs |
| `new_data` | Nouvelles valeurs |
| `changed_by` | Utilisateur Oracle |
| `changed_at` | Date de l'action |

### `archives_materiel`

Archive des materiels supprimes.

| Champ | Utilite |
|---|---|
| `id` | Identifiant unique |
| `original_table` | Table d'origine |
| `original_id` | Identifiant d'origine |
| `archived_data` | Donnees archivees |
| `archived_by` | Utilisateur Oracle |
| `archived_at` | Date d'archivage |

## Contraintes Importantes

- Les FK utilisent des noms singuliers et lisibles : `site_id`, `asset_id`, `user_id`, etc.
- `assets(site_id, serial_number)` evite deux numeros de serie identiques dans un meme site.
- `ip_networks(site_id, network_address, subnet_mask)` evite les doublons de sous-reseaux.
- Les tables de liaison `profiles_users`, `groups_users` et `ticket_users` empechent les doublons avec des contraintes `UNIQUE`.
- Les colonnes non vitales au projet ont ete supprimees pour garder un modele plus clair.
