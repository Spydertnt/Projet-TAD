# Rapport - Mini-Projet GLPI Multi-Sites

> CY Tech - TAD 2025-2026  
> Refonte simplifiee de la base GLPI sous Oracle XE

## 1. Contexte

GLPI couvre un perimetre tres large et sa base contient plus de 250 tables. Pour le projet TAD, l'objectif n'est pas de recopier GLPI mais de proposer un schema Oracle propre, contraint, distribuable et demonstrable.

Le modele final couvre quatre domaines essentiels :

| Domaine | Role |
|---|---|
| Organisation | Sites, entites et localisations |
| Utilisateurs | Comptes, profils et groupes |
| Inventaire | Tous les materiels dans une table unique `assets` |
| Support et reseau | Tickets, ports, VLAN, IP et connexions |

## 2. Choix de simplification

Le premier schema contenait 37 tables et restait trop proche de GLPI. La version simplifiee conserve **24 tables**, dont 22 fonctionnelles et 2 systeme.

| Avant | Apres |
|---|---|
| `computers`, `monitors`, `peripherals`, `printers`, `phones`, `network_equipments` | `assets(category, ...)` |
| Plusieurs FK nullable dans `tickets` | Une FK `tickets.assets_id` |
| Plusieurs FK nullable dans `network_ports` | Une FK `network_ports.assets_id` |
| `asset_types` + `asset_models` | `asset_models` et `assets.category` |
| `user_titles`, `user_categories`, `profile_rights` | Supprimes du noyau |
| FQDN, sockets, cables, tables de liaison IP/VLAN avancees | Reseau recentre sur ports, VLAN, IP |

Cette simplification rend le schema plus facile a expliquer et evite les relations polymorphes artificielles.

## 3. Modele logique

### Transversal

- `entities` : hierarchie des sites et entites, avec `site_code`
- `locations` : batiments et salles
- `manufacturers`, `states`, `networks`, `asset_models` : referentiels

### Utilisateurs

- `users` : comptes rattaches a une entite et une localisation
- `profiles` : profils applicatifs
- `profiles_users` : affectation utilisateur/profil/entite
- `groups`, `groups_users` : groupes support et membres

### Inventaire

- `assets` : table centrale des materiels

La colonne `category` distingue les categories : `COMPUTER`, `MONITOR`, `PERIPHERAL`, `PRINTER`, `PHONE`, `NETWORK_EQUIPMENT`.

### Support

- `ticket_categories`
- `tickets`, relies a un seul materiel par `assets_id`
- `ticket_users`
- `ticket_followups`

### Reseau

- `network_ports`
- `network_connections`
- `vlans`
- `network_port_vlans`
- `ip_networks`
- `ip_addresses`

### Systeme

- `audit_log`
- `archives_materiel`

## 4. Architecture BDDR

La base est distribuee entre Cergy et Pau. Les donnees operationnelles sont fragmentees horizontalement selon `entities.site_code`.

![Schema d'architecture](diagrams/architecture.svg)

| Donnees | Strategie |
|---|---|
| `assets`, `users`, `tickets`, `network_ports` | Fragmentation horizontale |
| `manufacturers`, `states`, `networks`, `asset_models`, `ticket_categories` | Replication |
| Reporting global | Vues distribuees via DB Link |

Le script `07_bddr.sql` fournit les DB Links, les synonymes, la procedure `SP_REPLIQUER_REFERENTIELS` et les vues globales.

## 4.1 MCD

![MCD simplifie](diagrams/mcd.svg)

Les schemas sont generes par le script `scripts/generate_diagrams.py`, ce qui permet de produire de vrais fichiers SVG versionnables et reutilisables dans le rapport ou la presentation.

## 5. PL/SQL

| Objet | Role |
|---|---|
| `TRG_AUTO_DATE_MOD_ASSETS` | Mise a jour automatique de `date_mod` |
| `TRG_AUDIT_ASSETS` | Journalisation des modifications d'inventaire |
| `TRG_CHECK_ASSET_MODEL_CATEGORY` | Verification modele/categorie |
| `TRG_CHECK_TICKET_USER_TECH` | Controle des techniciens affectes |
| `SP_TRANSFERT_MATERIEL` | Transfert local ou inter-sites d'un asset |
| `SP_CREER_TICKET_MATERIEL` | Creation d'un ticket sur un asset |
| `FN_COMPTER_MATERIEL_SITE` | Comptage des assets d'un site |

## 6. Index et performances

Les index sont concentres sur les usages principaux :

- recherche d'assets par nom et numero de serie
- inventaire par site, categorie, etat et utilisateur
- suivi des tickets par site, statut et priorite
- jointures reseau autour de `network_ports.assets_id`

Le benchmark `10_benchmark.sql` mesure six requetes representatives : recherche par nom, inventaire, tickets ouverts, recherche par serial, topologie reseau et utilisateurs/profils.

## 7. Conclusion

La version simplifiee est plus robuste pour une soutenance : le modele est lisible, les FK sont classiques, le MCD/MLD est plus propre, et les scripts restent suffisamment complets pour montrer Oracle XE, les tablespaces, les vues, le PL/SQL, l'indexation et la BDDR.
