# Presentation - BDD GLPI Multi-Sites simplifiee

## Slide 1 - Sujet

Refonte simplifiee d'une base GLPI vers Oracle XE distribue entre Cergy et Pau.

## Slide 2 - Probleme initial

- GLPI contient plus de 250 tables
- Peu de contraintes FK explicites
- Beaucoup de tables tres proches pour les materiels
- Schema difficile a expliquer et a distribuer proprement

## Slide 3 - Choix principal

Centraliser l'inventaire dans une seule table :

```text
assets(id, category, name, serial, users_id, locations_id, ...)
```

`category` remplace les anciennes tables separees : ordinateurs, ecrans, imprimantes, telephones, peripheriques et equipements reseau.

## Slide 4 - Resultat

- 24 tables au lieu de 37
- FK simples et lisibles
- Tickets relies a `assets_id`
- Ports reseau relies a `assets_id`
- Documentation MCD/MLD plus claire

Schema MCD : `docs/diagrams/mcd.svg`

## Slide 5 - Domaines conserves

| Domaine | Tables principales |
|---|---|
| Organisation | `entities`, `locations` |
| Utilisateurs | `users`, `profiles`, `groups` |
| Inventaire | `assets`, `asset_models`, `manufacturers`, `states` |
| Support | `tickets`, `ticket_users`, `ticket_followups` |
| Reseau | `network_ports`, `vlans`, `ip_addresses` |

## Slide 6 - BDDR

Schema d'architecture : `docs/diagrams/architecture.svg`

- fragmentation horizontale par `entities.site_code`
- replication des referentiels
- vues globales pour le reporting

## Slide 7 - PL/SQL

- triggers de date de modification
- audit automatique des assets
- archivage avant suppression
- procedure de transfert inter-sites
- procedure de creation de ticket
- fonctions de statistiques

## Slide 8 - Performance

Index principaux :

- `assets(entities_id, category)`
- `assets(entities_id, states_id)`
- `UPPER(assets.name)`
- `UPPER(assets.serial)`
- `tickets(entities_id, status, priority)`
- `network_ports(assets_id)`

## Slide 9 - Conclusion

Le schema final garde les notions attendues du projet tout en etant beaucoup plus propre : une table centrale pour le parc, des relations simples, une BDDR claire et un MCD/MLD defendable.
