# Architecture - BDD GLPI Multi-Sites simplifiee

## 1. Vue d'ensemble

Le modele cible remplace le schema GLPI tres fragmente par une architecture Oracle distribuee entre deux sites, Cergy et Pau. La simplification principale consiste a centraliser tous les materiels dans une seule table `assets`.

![Schema d'architecture](../docs/diagrams/architecture.svg)

Les fichiers SVG sont generes par `scripts/generate_diagrams.py`.

## 2. Principes retenus

| Ancien probleme | Choix simplifie |
|---|---|
| 6 tables de materiels presque identiques | 1 table `assets` avec `category` |
| Colonnes polymorphes multiples dans tickets/ports | 1 FK simple `assets_id` |
| Trop de referentiels utilisateurs | Suppression de `user_titles`, `user_categories`, `profile_rights` |
| Reseau trop detaille pour le besoin projet | Conservation ports, connexions, VLAN, sous-reseaux et IP |
| Audit utile mais non central | Tables systeme separees `audit_log`, `archives_materiel` |

## 3. MCD simplifie

![MCD simplifie](../docs/diagrams/mcd.svg)

Pour regenerer les schemas apres une modification du modele :

```bash
python scripts/generate_diagrams.py
```

## 4. MLD

### Transversal et referentiels

- `entities(id, entities_id -> entities, name, site_code, completename, ...)`
- `locations(id, entities_id -> entities, locations_id -> locations, name, building, room, ...)`
- `manufacturers(id, name)`
- `states(id, name)`
- `networks(id, name)`
- `asset_models(id, category, name)`

### Utilisateurs et droits

- `users(id, login, realname, firstname, email, entities_id -> entities, locations_id -> locations, users_id_supervisor -> users, is_active, ...)`
- `profiles(id, name, interface, is_default)`
- `profiles_users(id, users_id -> users, profiles_id -> profiles, entities_id -> entities, is_recursive)`
- `groups(id, entities_id -> entities, groups_id -> groups, name, completename)`
- `groups_users(id, users_id -> users, groups_id -> groups, is_manager)`

### Inventaire

- `assets(id, entities_id -> entities, category, name, serial, inventory_tag, uuid, users_id -> users, users_id_tech -> users, locations_id -> locations, asset_models_id -> asset_models, manufacturers_id -> manufacturers, states_id -> states, networks_id -> networks, notes, ...)`

La colonne `category` porte le type fonctionnel : `COMPUTER`, `MONITOR`, `PERIPHERAL`, `PRINTER`, `PHONE`, `NETWORK_EQUIPMENT`.

### Support

- `ticket_categories(id, name, description)`
- `tickets(id, entities_id -> entities, assets_id -> assets, requester_users_id -> users, assigned_groups_id -> groups, ticket_categories_id -> ticket_categories, status, priority, urgency, impact, ...)`
- `ticket_users(id, tickets_id -> tickets, users_id -> users, assigned_by -> users, role)`
- `ticket_followups(id, tickets_id -> tickets, users_id -> users, content, is_private)`

### Reseau

- `network_ports(id, entities_id -> entities, assets_id -> assets, name, mac, port_type, logical_number)`
- `network_connections(id, network_ports_id_1 -> network_ports, network_ports_id_2 -> network_ports)`
- `vlans(id, entities_id -> entities, name, tag)`
- `network_port_vlans(id, network_ports_id -> network_ports, vlans_id -> vlans, tagged)`
- `ip_networks(id, entities_id -> entities, vlans_id -> vlans, address, netmask, gateway)`
- `ip_addresses(id, entities_id -> entities, network_ports_id -> network_ports, ip_networks_id -> ip_networks, address, version)`

### Systeme

- `audit_log(id, table_name, record_id, action, old_values, new_values, changed_by, change_date)`
- `archives_materiel(id, source_table, source_id, data, archived_by, archive_date)`

**Total : 24 tables**, dont 22 fonctionnelles et 2 systeme.

## 5. Strategie de distribution

| Donnees | Strategie |
|---|---|
| Assets, utilisateurs, tickets, ports reseau | Fragmentation horizontale par `entities.site_code` |
| Referentiels | Replication via `SP_REPLIQUER_REFERENTIELS` |
| Reporting | Vues globales `V_ASSETS_GLOBAL`, `V_USERS_GLOBAL`, `V_STATS_GLOBAL`, `V_TICKETS_GLOBAL` |

## 6. Ordre d'execution

1. `01_tablespaces.sql`
2. `02_schema_tables.sql`
3. `03_users_roles.sql`
4. `04_clusters_indexes.sql`
5. `05_views.sql`
6. `06_plsql/triggers.sql`
7. `06_plsql/procedures.sql`
8. `06_plsql/functions.sql`
9. `06_plsql/cursors.sql`
10. `07_bddr.sql`
11. `08_query_plans.sql`
12. `09_test_data.sql`
13. `10_benchmark.sql`
