-- ============================================================
-- 04_clusters_indexes.sql
-- Associations, strategie de clusters et index
-- Oracle XE - Schema GLPI simplifie
-- ============================================================

-- ============================================================
-- 1. ASSOCIATIONS PRINCIPALES ENTRE LES TABLES
-- ============================================================

-- Sites et localisation
-- sites
--   -> sites(parent_site_id)
--   -> locations(site_id)
--   -> users(site_id)
--   -> groups(site_id)
--   -> assets(site_id)
--   -> tickets(site_id)
--   -> network_ports(site_id)
--   -> ip_networks(site_id)
--   -> ip_addresses(site_id)

-- Utilisateurs et droits
-- users
--   -> users(supervisor_user_id)
--   -> profiles_users(user_id)
--   -> groups_users(user_id)
--   -> assets(owner_user_id)
--   -> assets(technician_user_id)
--   -> tickets(requester_user_id)
--   -> ticket_users(user_id)
--   -> ticket_users(assigned_by_user_id)
--   -> ticket_followups(user_id)
--
-- profiles
--   -> profiles_users(profile_id)
--
-- groups
--   -> groups(parent_group_id)
--   -> groups_users(group_id)
--   -> tickets(assigned_group_id)

-- Inventaire
-- locations
--   -> locations(parent_location_id)
--   -> users(location_id)
--   -> assets(location_id)
--
-- manufacturers
--   -> assets(manufacturer_id)
--
-- states
--   -> assets(state_id)
--
-- assets
--   -> tickets(asset_id)
--   -> network_ports(asset_id)

-- Support
-- ticket_categories
--   -> tickets(category_id)
--
-- tickets
--   -> ticket_users(ticket_id)
--   -> ticket_followups(ticket_id)

-- Reseau
-- network_ports
--   -> ip_addresses(network_port_id)
--
-- ip_networks
--   -> ip_addresses(ip_network_id)

-- ============================================================
-- 2. CLUSTERS PHYSIQUES UTILISES
-- ============================================================

-- IMPORTANT :
-- Les CREATE CLUSTER et les index de cluster sont dans 02_schema_tables.sql.
-- Oracle impose que le cluster et son index existent avant certaines
-- operations sur les tables clusterisees, notamment les contraintes FK.
-- Ce fichier garde donc uniquement les index classiques et la documentation.

-- Choix de conception :
-- On ne cree pas un cluster global sur site_id.
--
-- Raison :
-- site_id est une cle transversale presente dans beaucoup de tables.
-- Si on clusterise tout par site_id, les tables assets, users ou tickets ne
-- peuvent plus etre clusterisees avec leurs tables de detail. Or une table
-- Oracle ne peut appartenir qu'a un seul cluster physique.
--
-- Strategie retenue :
--   - garder site_id avec des index B-tree et composites ;
--   - reserver les clusters aux associations parent/detail les plus consultees.
--
-- Exemple :
--   tickets par site      -> index tickets(site_id, status, priority)
--   assets par site/type  -> index assets(site_id, asset_type)
--   reseau par site       -> index sur site_id + jointures reseau

-- Cluster CLUSTER_USER_RIGHTS
-- Cle de cluster : user_id
-- Tables :
--   users(id)
--   profiles_users(user_id)
--   groups_users(user_id)
-- But :
--   charger rapidement un utilisateur avec ses profils et groupes.

-- Cluster CLUSTER_SITE_STRUCTURE
-- Cle de cluster : site_id
-- Tables :
--   sites(id)
--   locations(site_id)
--   groups(site_id)
--   ip_networks(site_id)
-- But :
--   accelerer les consultations par site sur les structures de base.
--
-- Pourquoi pas un cluster tickets ?
--   tickets.description, tickets.resolution et ticket_followups.content sont
--   des CLOB. Oracle XE ne supporte pas ce cas en cluster indexe classique
--   dans ce schema, ce qui provoque ORA-03001.

-- Cluster CLUSTER_NETWORK_PORT_IPS
-- Cle de cluster : network_port_id
-- Tables :
--   network_ports(id)
--   ip_addresses(network_port_id)
-- But :
--   afficher rapidement les adresses IP associees a un port reseau.

-- Associations a ne PAS clusteriser en priorite :
--   - manufacturers -> assets : petite table de reference, index suffisant.
--   - states -> assets : petite table de reference, index suffisant.
--   - ticket_categories -> tickets : cardinalite faible, index suffisant.
--   - relations parent_* : auto-relations ponctuelles, index suffisant.
--   - audit_log et archives_materiel : tables techniques, acces surtout par date
--     ou par table d'origine.

-- ============================================================
-- 3. INDEX B-TREE SUR CLES ETRANGERES ET FILTRES FREQUENTS
-- ============================================================

-- Sites et localisation
CREATE INDEX idx_sites_parent ON sites(parent_site_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_sites_code ON sites(site_code) TABLESPACE TS_INDEX;
CREATE INDEX idx_locations_parent ON locations(parent_location_id) TABLESPACE TS_INDEX;

-- Utilisateurs et droits
CREATE INDEX idx_users_site ON users(site_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_users_location ON users(location_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_users_supervisor ON users(supervisor_user_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_pu_profile ON profiles_users(profile_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_pu_site ON profiles_users(site_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_groups_parent ON groups(parent_group_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_gu_group ON groups_users(group_id) TABLESPACE TS_INDEX;

-- Inventaire
CREATE INDEX idx_assets_site ON assets(site_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_owner ON assets(owner_user_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_technician ON assets(technician_user_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_location ON assets(location_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_manuf ON assets(manufacturer_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_state ON assets(state_id) TABLESPACE TS_INDEX;

-- Support
CREATE INDEX idx_ticket_site ON tickets(site_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_asset ON tickets(asset_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_status ON tickets(status) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_requester ON tickets(requester_user_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_assigned_group ON tickets(assigned_group_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_category ON tickets(category_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_created_at ON tickets(created_at) TABLESPACE TS_INDEX;
CREATE INDEX idx_tu_ticket ON ticket_users(ticket_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_tu_user ON ticket_users(user_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_tu_assigned_by ON ticket_users(assigned_by_user_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_tf_ticket ON ticket_followups(ticket_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_tf_user ON ticket_followups(user_id) TABLESPACE TS_INDEX;

-- Reseau
CREATE INDEX idx_np_site ON network_ports(site_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_np_asset ON network_ports(asset_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ipn_vlan_tag ON ip_networks(vlan_tag) TABLESPACE TS_INDEX;
CREATE INDEX idx_ip_site ON ip_addresses(site_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ip_network ON ip_addresses(ip_network_id) TABLESPACE TS_INDEX;

-- ============================================================
-- 4. INDEX COMPOSITES POUR LES REQUETES METIER
-- ============================================================

CREATE INDEX idx_assets_site_type ON assets(site_id, asset_type) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_site_state ON assets(site_id, state_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_site_owner ON assets(site_id, owner_user_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_site_location ON assets(site_id, location_id) TABLESPACE TS_INDEX;

CREATE INDEX idx_ticket_site_status_priority ON tickets(site_id, status, priority) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_asset_status ON tickets(asset_id, status) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_group_status ON tickets(assigned_group_id, status) TABLESPACE TS_INDEX;

CREATE INDEX idx_pu_site_user ON profiles_users(site_id, user_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_network_site_address ON ip_networks(site_id, network_address) TABLESPACE TS_INDEX;
CREATE INDEX idx_ip_network_address ON ip_addresses(ip_network_id, ip_address) TABLESPACE TS_INDEX;

-- ============================================================
-- 5. INDEX FONCTIONNELS
-- ============================================================

CREATE INDEX idx_assets_name_upper ON assets(UPPER(name)) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_serial_upper ON assets(UPPER(serial_number)) TABLESPACE TS_INDEX;
CREATE INDEX idx_users_login_upper ON users(UPPER(login)) TABLESPACE TS_INDEX;
CREATE INDEX idx_users_email_upper ON users(UPPER(email)) TABLESPACE TS_INDEX;

-- ============================================================
-- 6. INDEX BITMAP POUR COLONNES A FAIBLE CARDINALITE
-- ============================================================

-- A utiliser surtout pour lecture analytique et benchmarks.
-- Sur un systeme tres transactionnel, les bitmap index peuvent ralentir les
-- INSERT/UPDATE concurrents.

CREATE BITMAP INDEX bmp_assets_type ON assets(asset_type) TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_users_active ON users(is_active) TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_tickets_priority ON tickets(priority) TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_np_type ON network_ports(port_type) TABLESPACE TS_INDEX;

-- ============================================================
-- 7. INDEX TABLES SYSTEME
-- ============================================================

CREATE INDEX idx_audit_table ON audit_log(table_name) TABLESPACE TS_INDEX;
CREATE INDEX idx_audit_date ON audit_log(changed_at) TABLESPACE TS_INDEX;
CREATE INDEX idx_audit_table_record ON audit_log(table_name, row_id) TABLESPACE TS_INDEX;

CREATE INDEX idx_archives_original ON archives_materiel(original_table, original_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_archives_date ON archives_materiel(archived_at) TABLESPACE TS_INDEX;
