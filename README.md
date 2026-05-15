# Mini-Projet GLPI - Nouvelle BDD Multi-Sites

> CY Tech - TAD 2025-2026  
> Refonte simplifiee d'une base GLPI vers Oracle XE distribue entre Cergy et Pau.

## Objectif

Le projet part du constat que GLPI possede un schema tres volumineux, peu contraint par le SGBD et difficile a distribuer proprement. La nouvelle version garde uniquement le noyau utile au projet :

- gestion multi-sites avec `entities` et `locations`
- utilisateurs, profils et groupes
- inventaire unifie avec une seule table `assets`
- tickets support rattaches aux materiels
- reseau essentiel : ports, connexions, VLAN, IP
- audit et archivage des materiels
- BDDR par DB Links Oracle

## Architecture

```
Oracle XE - Cergy  <------ DB Link ------>  Oracle XE - Pau

Fragmentation horizontale :
- assets
- users
- tickets
- network_ports

Replication :
- manufacturers
- states
- networks
- asset_models
- ticket_categories
```

Le schema passe de 37 tables a **24 tables**. La simplification majeure est la table `assets`, qui remplace les anciennes tables `computers`, `monitors`, `peripherals`, `printers`, `phones` et `network_equipments`.

## Structure

```text
Projet-TAD/
|-- README.md
|-- docs/
|   |-- reverse_engineering_glpi.md
|   |-- rapport.md
|   |-- presentation.md
|   `-- performance_report.html
`-- sql/
    |-- 00_architecture.md
    |-- 01_tablespaces.sql
    |-- 02_schema_tables.sql
    |-- 03_users_roles.sql
    |-- 04_clusters_indexes.sql
    |-- 05_views.sql
    |-- 06_plsql/
    |   |-- triggers.sql
    |   |-- procedures.sql
    |   |-- functions.sql
    |   `-- cursors.sql
    |-- 07_bddr.sql
    |-- 08_query_plans.sql
    |-- 09_test_data.sql
    `-- 10_benchmark.sql
```

## Execution

```sql
@01_tablespaces.sql
@02_schema_tables.sql
@03_users_roles.sql
@04_clusters_indexes.sql
@05_views.sql
@06_plsql/triggers.sql
@06_plsql/procedures.sql
@06_plsql/functions.sql
@06_plsql/cursors.sql
@07_bddr.sql
@08_query_plans.sql
@09_test_data.sql
@10_benchmark.sql
```

## Livrables principaux

- `sql/00_architecture.md` : MCD, MLD et strategie BDDR
- `scripts/generate_diagrams.py` : generation des schemas SVG
- `docs/diagrams/architecture.svg` et `docs/diagrams/mcd.svg` : schemas visuels
- `sql/02_schema_tables.sql` : schema relationnel simplifie
- `sql/05_views.sql` : vues metier
- `sql/06_plsql/` : triggers, procedures, fonctions et curseurs
- `sql/09_test_data.sql` : generation d'un jeu de test coherent
- `sql/10_benchmark.sql` : mesures de performance

## Resultat

La base reste assez riche pour demontrer les notions du cours (FK, tablespaces, vues, PL/SQL, index, BDDR), mais elle est nettement plus lisible : une table centrale pour l'inventaire, des relations simples, et un MCD/MLD defendable en soutenance.
