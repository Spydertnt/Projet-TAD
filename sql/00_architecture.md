# Architecture — Nouvelle BDD GLPI Multi-Sites

## 1. Vue d'ensemble

La nouvelle architecture remplace la BDD monolithique MySQL de GLPI par une **architecture Oracle distribuée** entre deux sites : **Cergy** et **Pau**.

```
┌─────────────────────────────────────────────────────────┐
│                    ARCHITECTURE GLOBALE                   │
│                                                          │
│   ┌──────────────────┐    DB Link    ┌────────────────┐  │
│   │   ORACLE XE      │◄────────────►│   ORACLE XE    │  │
│   │   SITE CERGY     │              │   SITE PAU     │  │
│   │                  │              │                │  │
│   │ TS_MATERIEL      │              │ TS_MATERIEL    │  │
│   │ TS_UTILISATEURS  │              │ TS_UTILISATEURS│  │
│   │ TS_RESEAU        │              │ TS_RESEAU      │  │
│   │ TS_INDEX         │              │ TS_INDEX       │  │
│   └──────────────────┘              └────────────────┘  │
│                                                          │
│   Données locales :                  Données locales :   │
│   - Matériels Cergy                 - Matériels Pau     │
│   - Users Cergy                     - Users Pau         │
│   - Ports réseau Cergy              - Ports réseau Pau  │
│                                                          │
│   Données répliquées (identiques sur les 2 sites) :      │
│   - manufacturers, states, asset_types, asset_models     │
│   - networks, profiles, profile_rights                   │
└─────────────────────────────────────────────────────────┘
```

## 2. Problèmes résolus vs GLPI original

| # | Problème GLPI | Solution nouvelle BDD |
|---|---|---|
| 1 | Aucune FK | FK explicites sur toutes les relations |
| 2 | Polymorphisme `itemtype`/`items_id` | FK classiques (une colonne par type) + CHECK |
| 3 | Pas de tablespaces | 6 tablespaces dédiés |
| 4 | Pas de vues | 7 vues métier |
| 5 | Pas de PL/SQL | Triggers, curseurs, procédures, fonctions |
| 6 | Base monolithique | BDDR avec DB Links entre Cergy et Pau |
| 7 | Tables types redondantes | Consolidation en `asset_types` / `asset_models` |
| 8 | Index sans analyse | Index B-tree, composites, fonctionnels, bitmap |

## 3. Modèle Logique de Données (MLD)

### Tables transversales (4)
- `entities` (id, name, entities_id→entities, level, site_code, ...)
- `locations` (id, entities_id→entities, locations_id→locations, building, room, ...)
- `manufacturers` (id, name)
- `states` (id, entities_id→entities, name, is_visible_*)

### Tables de référence consolidées (3)
- `networks` (id, name)
- `asset_types` (id, category, name) — remplace 6 tables GLPI
- `asset_models` (id, category, name) — remplace 6 tables GLPI

### Tables utilisateurs (8)
- `user_titles` (id, name)
- `user_categories` (id, name)
- `users` (id, name, password, realname, firstname, entities_id→entities, ...)
- `profiles` (id, name, interface, is_default)
- `profile_rights` (id, profiles_id→profiles, name, rights)
- `profiles_users` (id, users_id→users, profiles_id→profiles, entities_id→entities)
- `groups` (id, entities_id→entities, groups_id→groups, name, ...)
- `groups_users` (id, users_id→users, groups_id→groups, is_manager)

### Tables matériels (6)
- `computers` (id, entities_id→entities, name, serial, users_id→users, ...)
- `monitors` (id, entities_id→entities, name, serial, size_monitor, ...)
- `peripherals` (id, entities_id→entities, name, serial, ...)
- `printers` (id, entities_id→entities, name, serial, networks_id→networks, ...)
- `phones` (id, entities_id→entities, name, serial, ...)
- `network_equipments` (id, entities_id→entities, name, serial, ram, ...)

### Tables support / tickets (3)
- `ticket_categories` (id, name, description)
- `tickets` (id, entities_id→entities, requester_users_id→users, assigned_groups_id→groups, ...)
- `ticket_followups` (id, tickets_id→tickets, users_id→users, content)

### Tables réseau (10)
- `fqdns` (id, entities_id→entities, name, fqdn)
- `network_ports` (id, entities_id→entities, computers_id, printers_id, ..., mac)
- `network_names` (id, network_ports_id→network_ports, fqdns_id→fqdns)
- `ip_addresses` (id, entities_id→entities, network_names_id→network_names, name)
- `network_connections` (id, network_ports_id_1→network_ports, network_ports_id_2)
- `vlans` (id, entities_id→entities, name, tag)
- `network_port_vlans` (id, network_ports_id→network_ports, vlans_id→vlans)
- `ip_networks` (id, entities_id→entities, address, netmask, gateway)
- `ip_network_vlans` (id, ip_networks_id→ip_networks, vlans_id→vlans)
- `sockets` (id, entities_id→entities, network_ports_id→network_ports)
- `cables` (id, entities_id→entities, sockets_id_a→sockets, sockets_id_b)

### Tables système (2)
- `audit_log` (id, table_name, record_id, action, old_values, new_values)
- `archives_materiel` (id, source_table, source_id, data)

**Total : 36 tables** (vs ~30 GLPI dans le périmètre, mais avec intégrité garantie)

## 4. Stratégie de distribution (BDDR)

| Type de données | Stratégie | Justification |
|---|---|---|
| Matériels | **Fragmentation horizontale** | Chaque site stocke ses propres matériels |
| Utilisateurs | **Fragmentation horizontale** | Comptes locaux à chaque site |
| Tickets | **Fragmentation horizontale** | Tickets traités par le service IT du site concerné |
| Référentiels | **Réplication** | Types, modèles, fabricants identiques partout |
| Réseau | **Fragmentation horizontale** | Infrastructure locale à chaque site |

## 5. Scripts d'exécution

Exécuter dans l'ordre :
1. `01_tablespaces.sql` — Création des tablespaces
2. `02_schema_tables.sql` — Création des tables
3. `03_users_roles.sql` — Utilisateurs et rôles Oracle
4. `04_clusters_indexes.sql` — Clusters et index
5. `05_views.sql` — Vues métier
6. `06_plsql/triggers.sql` — Triggers
7. `06_plsql/procedures.sql` — Procédures stockées
8. `06_plsql/functions.sql` — Fonctions
9. `06_plsql/cursors.sql` — Scripts de curseurs (exécution ponctuelle)
10. `07_bddr.sql` — Configuration distribuée
11. `08_query_plans.sql` — Analyse des performances
