# Reverse Engineering — BDD GLPI

> Source : [glpi-empty.sql](https://github.com/glpi-project/glpi/blob/main/install/mysql/glpi-empty.sql) (MySQL/MariaDB, +250 tables)

## 1. Architecture générale de GLPI

| Aspect | Détail |
|---|---|
| **SGBD** | MySQL / MariaDB, InnoDB, `utf8mb4_unicode_ci` |
| **Tables** | +250, préfixées `glpi_` |
| **PK** | `id INT UNSIGNED AUTO_INCREMENT` sur chaque table |
| **FK** | Pattern `<table>_id` (ex: `computers_id`), **pas de contraintes FK explicites** |
| **Polymorphisme** | Champs `itemtype` (VARCHAR) + `items_id` (INT) pour les relations flexibles |
| **Multi-entités** | Colonne `entities_id` + `is_recursive` sur la majorité des tables |
| **Soft delete** | Colonne `is_deleted` (TINYINT) |
| **Templates** | Colonnes `is_template` + `template_name` |
| **Audit** | `date_mod`, `date_creation` sur presque toutes les tables |

---

## 2. Tables identifiées dans le périmètre

### 2.1 Matériels informatiques

```mermaid
erDiagram
    COMPUTERS {
        int id PK
        int entities_id FK
        varchar name
        varchar serial
        int users_id FK
        int users_id_tech FK
        int locations_id FK
        int networks_id FK
        int computermodels_id FK
        int computertypes_id FK
        int manufacturers_id FK
        int states_id FK
    }
    
    MONITORS {
        int id PK
        int entities_id FK
        varchar name
        varchar serial
        decimal size
        int users_id FK
        int locations_id FK
        int monitortypes_id FK
        int monitormodels_id FK
        int manufacturers_id FK
    }
    
    PERIPHERALS {
        int id PK
        int entities_id FK
        varchar name
        varchar serial
        int users_id FK
        int locations_id FK
        int peripheraltypes_id FK
        int manufacturers_id FK
    }
    
    PRINTERS {
        int id PK
        int entities_id FK
        varchar name
        varchar serial
        int users_id FK
        int locations_id FK
        int printertypes_id FK
        int networks_id FK
        int manufacturers_id FK
    }
    
    PHONES {
        int id PK
        int entities_id FK
        varchar name
        varchar serial
        int users_id FK
        int locations_id FK
        int phonetypes_id FK
        int manufacturers_id FK
    }
    
    NETWORKEQUIPMENTS {
        int id PK
        int entities_id FK
        varchar name
        varchar serial
        int ram
        int cpu
        int users_id FK
        int locations_id FK
        int networkequipmenttypes_id FK
        int networks_id FK
        int manufacturers_id FK
    }
```

**Pattern commun** à tous les assets :
- `entities_id`, `is_recursive`, `is_deleted`, `is_template`, `is_dynamic`
- `users_id` (propriétaire), `users_id_tech` (technicien responsable)
- `locations_id`, `manufacturers_id`, `states_id`
- `serial`, `otherserial`, `uuid`, `date_mod`, `date_creation`

**Tables de types/modèles associées** (dropdown) :
- `glpi_computermodels`, `glpi_computertypes`
- `glpi_monitormodels`, `glpi_monitortypes`
- `glpi_peripheralmodels`, `glpi_peripheraltypes`
- `glpi_printermodels`, `glpi_printertypes`
- `glpi_phonemodels`, `glpi_phonetypes`
- `glpi_networkequipmentmodels`, `glpi_networkequipmenttypes`
- `glpi_manufacturers`, `glpi_states`, `glpi_networks`

**Tables de composants matériels** (devices) :
- `glpi_deviceprocessors`, `glpi_devicememories`, `glpi_deviceharddrives`, `glpi_devicenetworkcards`, `glpi_devicegraphiccards`, `glpi_devicemotherboards`, etc.
- Liaison polymorphe via `glpi_items_device<X>` (champs `itemtype` + `items_id`)

**Liaison assets ↔ assets** :
- `glpi_assets_assets_peripheralassets` (polymorphe : `itemtype_asset`, `items_id_asset`, `itemtype_peripheral`, `items_id_peripheral`)

---

### 2.2 Utilisateurs & droits d'accès

```mermaid
erDiagram
    USERS ||--o{ PROFILES_USERS : "a"
    PROFILES ||--o{ PROFILES_USERS : "définit"
    PROFILES ||--o{ PROFILERIGHTS : "contient"
    USERS ||--o{ GROUPS_USERS : "membre de"
    GROUPS ||--o{ GROUPS_USERS : "contient"
    ENTITIES ||--o{ PROFILES_USERS : "scope"

    USERS {
        int id PK
        varchar name
        varchar password
        varchar realname
        varchar firstname
        varchar phone
        varchar mobile
        int profiles_id FK
        int entities_id FK
        int groups_id FK
        int locations_id FK
        int usertitles_id FK
        int usercategories_id FK
        int users_id_supervisor FK
        int authtype
        int auths_id FK
    }

    PROFILES {
        int id PK
        varchar name
        varchar interface
        tinyint is_default
    }

    PROFILERIGHTS {
        int id PK
        int profiles_id FK
        varchar name
        int rights
    }

    PROFILES_USERS {
        int id PK
        int users_id FK
        int profiles_id FK
        int entities_id FK
        tinyint is_recursive
    }

    GROUPS {
        int id PK
        int entities_id FK
        varchar name
        int groups_id FK
        int level
        text completename
    }

    GROUPS_USERS {
        int id PK
        int users_id FK
        int groups_id FK
        tinyint is_manager
        tinyint is_userdelegate
    }

    ENTITIES {
        int id PK
        varchar name
        int entities_id FK
        int level
        text completename
        varchar address
        varchar postcode
        varchar town
    }
```

**Points clés** :
- **Profils** = ensemble de droits. Un utilisateur peut avoir **plusieurs profils** sur **différentes entités** via `glpi_profiles_users`
- **Droits** stockés dans `glpi_profilerights` : champ `name` (ex: `computer`, `printer`) + `rights` (bitmask)
- **Groupes** hiérarchiques (auto-référence `groups_id`) avec rôles multiples (`is_requester`, `is_assign`, etc.)
- **Entités** hiérarchiques (auto-référence `entities_id`) = unités organisationnelles (sites, services…)

---

### 2.3 Réseaux & infrastructure

```mermaid
erDiagram
    NETWORKPORTS {
        int id PK
        int items_id
        varchar itemtype
        int entities_id FK
        varchar name
        varchar mac
        varchar instantiation_type
        bigint ifspeed
        bigint ifinbytes
        bigint ifoutbytes
    }
    
    NETWORKPORTS_NETWORKPORTS {
        int id PK
        int networkports_id_1 FK
        int networkports_id_2 FK
    }
    
    NETWORKPORTS_VLANS {
        int id PK
        int networkports_id FK
        int vlans_id FK
        tinyint tagged
    }
    
    VLANS {
        int id PK
        int entities_id FK
        varchar name
        int tag
    }
    
    IPNETWORKS {
        int id PK
        int entities_id FK
        varchar name
        varchar address
        varchar netmask
        varchar gateway
        int ipnetworks_id FK
    }
    
    IPNETWORKS_VLANS {
        int id PK
        int ipnetworks_id FK
        int vlans_id FK
    }
    
    NETWORKNAMES {
        int id PK
        int items_id
        varchar itemtype
        varchar name
        int fqdns_id FK
    }
    
    CABLES {
        int id PK
        int entities_id FK
        varchar itemtype_endpoint_a
        int items_id_endpoint_a
        varchar itemtype_endpoint_b
        int items_id_endpoint_b
        int sockets_id_endpoint_a FK
        int sockets_id_endpoint_b FK
        int cabletypes_id FK
    }
    
    SOCKETS {
        int id PK
        int locations_id FK
        varchar itemtype
        int items_id
        int networkports_id FK
    }

    NETWORKPORTS ||--o{ NETWORKPORTS_VLANS : "associé"
    VLANS ||--o{ NETWORKPORTS_VLANS : "contient"
    NETWORKPORTS ||--o{ NETWORKPORTS_NETWORKPORTS : "connecté"
    VLANS ||--o{ IPNETWORKS_VLANS : "associé"
    IPNETWORKS ||--o{ IPNETWORKS_VLANS : "sur"
```

**Points clés** :
- `glpi_networkports` est **polymorphe** (`itemtype` + `items_id`) → peut être lié à un Computer, NetworkEquipment, Printer, etc.
- Connexions port-à-port via `glpi_networkports_networkports`
- VLANs associés aux ports (`glpi_networkports_vlans`) et aux sous-réseaux IP (`glpi_ipnetworks_vlans`)
- Câblage physique via `glpi_cables` (polymorphe aux deux extrémités) et `glpi_sockets`
- Types de port spécialisés : `glpi_networkportethernets`, `glpi_networkportwifis`, `glpi_networkportfiberchannels`
- `glpi_ipnetworks` hiérarchique (auto-référence `ipnetworks_id`), stocke adresses en 4 octets séparés pour le calcul

---

## 3. Constats & problèmes identifiés

| # | Constat | Impact |
|---|---|---|
| 1 | **Aucune contrainte FOREIGN KEY** dans le schéma | L'intégrité référentielle n'est pas garantie par le SGBD |
| 2 | **Polymorphisme extensif** (`itemtype`/`items_id`) | Impossible de créer des FK classiques → JOIN complexes, pas d'intégrité |
| 3 | **Pas de tablespaces** ni de partitionnement | Pas d'optimisation du stockage multi-sites |
| 4 | **Pas de vues** définies | Les requêtes complexes sont répétées dans le code applicatif |
| 5 | **Pas de triggers/procédures/fonctions** SQL | Toute la logique métier est dans le code PHP |
| 6 | **Base monolithique** | Pas de distribution/réplication entre sites |
| 7 | **Tables de types très nombreuses et similaires** | Redondance structurelle (6 tables `*types`, 6 tables `*models`) |
| 8 | **Index nombreux mais sans analyse** | Pas d'évidence d'optimisation des plans d'exécution |
| 9 | **Colonnes `sons_cache`/`ancestors_cache`** | Cache de hiérarchie en JSON dans la BDD → dénormalisation |

---

## 4. Relations globales — Schéma résumé

```mermaid
graph TB
    subgraph "Organisation"
        E[Entities<br/>Hiérarchie sites]
        L[Locations<br/>Bâtiments/salles]
    end
    
    subgraph "Utilisateurs"
        U[Users]
        P[Profiles]
        PR[ProfileRights]
        G[Groups]
        PU[Profiles_Users]
        GU[Groups_Users]
    end
    
    subgraph "Matériels"
        C[Computers]
        M[Monitors]
        PE[Peripherals]
        PI[Printers]
        PH[Phones]
        NE[NetworkEquipments]
    end
    
    subgraph "Réseau"
        NP[NetworkPorts<br/>polymorphe]
        V[VLANs]
        IP[IPNetworks]
        CA[Cables]
        SO[Sockets]
    end
    
    E --> |entities_id| U
    E --> |entities_id| C
    E --> |entities_id| NE
    E --> |entities_id| NP
    L --> |locations_id| C
    L --> |locations_id| U
    U --> |users_id| C
    U --> |users_id_tech| C
    P --> |profiles_id| PU
    U --> |users_id| PU
    E --> |entities_id| PU
    P --> |profiles_id| PR
    U --> |users_id| GU
    G --> |groups_id| GU
    
    C -.-> |polymorphe| NP
    NE -.-> |polymorphe| NP
    PI -.-> |polymorphe| NP
    NP --> |networkports_id| V
    IP --> |ipnetworks_id| V
    NP -.-> |port-à-port| NP
    SO -.-> |polymorphe| CA
```

---

## 5. Résumé des tables dans le périmètre (30 tables)

### Matériels (14 tables)
`glpi_computers`, `glpi_computermodels`, `glpi_computertypes`, `glpi_monitors`, `glpi_monitormodels`, `glpi_monitortypes`, `glpi_peripherals`, `glpi_peripheraltypes`, `glpi_printers`, `glpi_printertypes`, `glpi_phones`, `glpi_phonetypes`, `glpi_networkequipments`, `glpi_networkequipmenttypes`

### Utilisateurs & droits (8 tables)
`glpi_users`, `glpi_profiles`, `glpi_profilerights`, `glpi_profiles_users`, `glpi_groups`, `glpi_groups_users`, `glpi_usertitles`, `glpi_usercategories`

### Réseaux (12 tables)
`glpi_networkports`, `glpi_networkports_networkports`, `glpi_networkports_vlans`, `glpi_vlans`, `glpi_ipnetworks`, `glpi_ipnetworks_vlans`, `glpi_ipaddresses`, `glpi_networknames`, `glpi_fqdns`, `glpi_cables`, `glpi_sockets`, `glpi_networks`

### Transversales (4 tables)
`glpi_entities`, `glpi_locations`, `glpi_manufacturers`, `glpi_states`
