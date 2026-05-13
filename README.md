# Mini-Projet GLPI — Nouvelle BDD Multi-Sites

> **CY Tech — TAD 2025-2026**  
> Refonte de la base de données GLPI pour une architecture Oracle XE distribuée multi-sites (Cergy / Pau)

---

## 📋 Description

Ce projet réalise le **reverse engineering** de la base de données du logiciel GLPI (Gestionnaire Libre de Parc Informatique), puis conçoit et implémente une **nouvelle architecture Oracle** répondant aux enjeux d'un déploiement multi-sites entre **Cergy** et **Pau**.

### Objectifs
- Analyser la structure existante de GLPI (MySQL, +250 tables, pas de FK)
- Concevoir une nouvelle BDD Oracle avec intégrité référentielle garantie
- Implémenter les concepts avancés : PL/SQL, tablespaces, BDDR, indexation
- Valider les performances par des benchmarks comparatifs

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│   ORACLE XE — CERGY    ◄──DB Link──►   ORACLE XE — PAU   │
│                                                           │
│   TS_MATERIEL           Fragmentation    TS_MATERIEL      │
│   TS_UTILISATEURS       horizontale      TS_UTILISATEURS  │
│   TS_RESEAU             + réplication    TS_RESEAU        │
│   TS_SUPPORT            référentiels     TS_SUPPORT       │
│   TS_INDEX                                TS_INDEX         │
└─────────────────────────────────────────────────┘
```

- **37 tables** (vs ~30 GLPI dans le périmètre) avec FK explicites
- **6 tablespaces** dédiés (matériel, utilisateurs, réseau, support, index, temporaire)
- **7 vues métier** pour l'accès simplifié aux données
- **54 index** (B-tree, composites, fonctionnels, bitmap)
- **PL/SQL complet** : triggers, procédures, fonctions, curseurs
- **BDDR** : DB Links, synonymes, vues distribuées, réplication

---

## 📁 Structure du projet

```
Projet-TAD/
├── README.md
├── docs/
│   ├── reverse_engineering_glpi.md   # Phase 1 — Analyse de l'existant
│   ├── rapport.md                    # Rapport détaillé du projet
│   ├── presentation.md               # Support pour la soutenance orale
│   └── performance_report.html       # Rapport interactif de benchmarks
└── sql/
    ├── 00_architecture.md            # Documentation technique
    ├── 01_tablespaces.sql            # Création des tablespaces
    ├── 02_schema_tables.sql          # 37 tables avec FK explicites
    ├── 03_users_roles.sql            # Utilisateurs, rôles, privilèges Oracle
    ├── 04_clusters_indexes.sql       # 54 index (B-tree, composite, bitmap)
    ├── 05_views.sql                  # 7 vues métier
    ├── 06_plsql/
    │   ├── triggers.sql              # 9 triggers (audit, validation, cascade)
    │   ├── procedures.sql            # 6 procédures stockées
    │   ├── functions.sql             # 4 fonctions
    │   └── cursors.sql               # 4 curseurs (explicite, FOR, REF)
    ├── 07_bddr.sql                   # DB Links, synonymes, vues distribuées
    ├── 08_query_plans.sql            # Analyse des plans d'exécution
    ├── 09_test_data.sql              # Génération de ~20 000 lignes de test
    └── 10_benchmark.sql              # Suite de benchmarks comparatifs
```

---

## 🚀 Installation et exécution

### Prérequis
- Oracle XE 21c
- SQL*Plus ou SQLcl

### Exécution (dans l'ordre)
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

---

## 📊 Résultats de performance

| Métrique | Valeur |
|---|---|
| Lignes générées | ~21 100 |
| Gain moyen | **62%** |
| Gain maximum | **94%** (recherches indexées) |
| Requêtes testées | 8 |

> Voir le rapport interactif : [`docs/performance_report.html`](docs/performance_report.html)

---

## 📄 Licence

Projet académique — CY Tech 2025-2026
