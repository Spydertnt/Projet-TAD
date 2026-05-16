# Rapport - Mini-Projet GLPI Multi-Sites

> CY Tech - TAD 2025-2026  
> Refonte simplifiee de la base GLPI sous Oracle XE

## 1. Contexte

GLPI couvre un perimetre tres large et sa base contient plus de 250 tables. Pour le projet TAD, l'objectif n'est pas de recopier GLPI mais de proposer un schema Oracle propre, contraint, distribuable et demonstrable.

Le modele final couvre quatre domaines essentiels :

| Domaine | Role |
|---|---|
| Organisation | Sites, services et localisations |
| Utilisateurs | Comptes, profils et groupes |
| Inventaire | Tous les materiels dans une table unique `assets` |
| Support et reseau | Tickets, ports reseau, sous-reseaux et IP |

## 2. Choix de simplification

Le premier schema contenait 37 tables et restait trop proche de GLPI. La version simplifiee conserve **19 tables**, dont 17 fonctionnelles et 2 systeme.

| Avant | Apres |
|---|---|
| `computers`, `monitors`, `peripherals`, `printers`, `phones`, `network_equipments` | `assets(asset_type, ...)` |
| Plusieurs FK nullable dans `tickets` | Une FK `tickets.asset_id` |
| Plusieurs FK nullable dans `network_ports` | Une FK `network_ports.asset_id` |
| Tables de types et modeles materiel | Suppression des modeles, conservation de `assets.asset_type` |
| `user_titles`, `user_categories`, `profile_rights` | Supprimes du noyau |
| FQDN, sockets, cables, connexions port-a-port, VLANs detailles | Reseau recentre sur ports, sous-reseaux IP et adresses IP |

Cette simplification rend le schema plus facile a expliquer et evite les relations polymorphes artificielles.

## 3. Modele logique

### Transversal

- `sites` : hierarchie des sites et services, avec `site_code`
- `locations` : batiments et salles
- `manufacturers`, `states` : referentiels

### Utilisateurs

- `users` : comptes rattaches a un site et une localisation
- `profiles` : profils applicatifs
- `profiles_users` : affectation utilisateur/profil/site
- `groups`, `groups_users` : groupes support et membres

### Inventaire

- `assets` : table centrale des materiels

La colonne `asset_type` distingue les categories : `COMPUTER`, `MONITOR`, `PERIPHERAL`, `PRINTER`, `PHONE`, `NETWORK_EQUIPMENT`.

### Support

- `ticket_categories`
- `tickets`, relies a un seul materiel par `asset_id`
- `ticket_users`
- `ticket_followups`

### Reseau

- `network_ports`
- `ip_networks`
- `ip_addresses`

### Systeme

- `audit_log`
- `archives_materiel`

## 4. Architecture BDDR

La base est concue pour etre distribuee entre Cergy et Pau. Sur un seul PC, la BDDR est simulee avec deux schemas Oracle locaux : `GLPI_CERGY` et `GLPI_PAU`. Les donnees operationnelles sont fragmentees horizontalement selon `sites.site_code`.

![Schema d'architecture](diagrams/architecture.svg)

| Donnees | Strategie |
|---|---|
| `assets`, `users`, `tickets`, `network_ports`, `ip_networks`, `ip_addresses` | Fragmentation horizontale |
| `manufacturers`, `states`, `ticket_categories` | Replication |
| Reporting global | Vues globales entre les deux schemas locaux |

Le script `07_bddr.sql` cree les schemas de simulation, les vues locales, les synonymes et les vues globales.

## 4.1 MCD

![MCD simplifie](diagrams/mcd.svg)

## 4.2 Diagramme UML

![Diagramme UML](diagrams/uml.svg)

Le diagramme UML presente le modele sous forme de classes metier : sites, utilisateurs, inventaire, tickets et reseau, avec les multiplicites principales.

Les schemas d'architecture et de MCD sont generes par `scripts/generate_diagrams.py`. Le diagramme UML est genere separement par `scripts/generate_uml_diagram.py`, ce qui evite de modifier le generateur des schemas existants.

## 5. PL/SQL

| Objet | Role |
|---|---|
| `TRG_AUTO_DATE_MOD_ASSETS` | Mise a jour automatique de `updated_at` |
| `TRG_AUDIT_ASSETS` | Journalisation des modifications d'inventaire |
| `TRG_CHECK_TICKET_USER_TECH` | Controle des techniciens affectes |
| `SP_TRANSFERT_MATERIEL` | Transfert local ou inter-sites d'un asset |
| `SP_CREER_TICKET_MATERIEL` | Creation d'un ticket sur un asset |
| `FN_COMPTER_MATERIEL_SITE` | Comptage des assets d'un site |

## 6. Index et performances

Les index sont concentres sur les usages principaux :

- recherche d'assets par nom et numero de serie
- inventaire par site, categorie, etat et utilisateur
- suivi des tickets par site, statut et priorite
- jointures reseau autour de `network_ports.asset_id`

Le benchmark `10_benchmark.sql` mesure six requetes representatives : recherche par nom, inventaire, tickets ouverts, recherche par serial_number, reseau des appareils et utilisateurs/profils.

## 7. Conclusion

La version simplifiee est plus robuste pour une soutenance : le modele est lisible, les FK sont classiques, le MCD/MLD est plus propre, et les scripts restent suffisamment complets pour montrer Oracle XE, les tablespaces, les vues, le PL/SQL, l'indexation et la BDDR.
