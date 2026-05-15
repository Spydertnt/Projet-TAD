-- ============================================================
-- 04_clusters_indexes.sql
-- Index - Schema simplifie
-- Oracle XE
-- ============================================================

-- Les clusters physiques doivent etre definis avant les tables.
-- Le projet conserve ici des index executables et lisibles.

-- =========================
-- INDEX B-TREE
-- =========================

CREATE INDEX idx_entities_parent ON entities(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_entities_site ON entities(site_code) TABLESPACE TS_INDEX;
CREATE INDEX idx_locations_entity ON locations(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_locations_parent ON locations(locations_id) TABLESPACE TS_INDEX;

CREATE INDEX idx_users_entity ON users(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_users_location ON users(locations_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_pu_user ON profiles_users(users_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_pu_profile ON profiles_users(profiles_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_gu_user ON groups_users(users_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_gu_group ON groups_users(groups_id) TABLESPACE TS_INDEX;

CREATE INDEX idx_assets_entity ON assets(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_user ON assets(users_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_location ON assets(locations_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_manuf ON assets(manufacturers_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_model ON assets(asset_models_id) TABLESPACE TS_INDEX;

CREATE INDEX idx_ticket_entity ON tickets(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_asset ON tickets(assets_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_status ON tickets(status) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_requester ON tickets(requester_users_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_assigned_group ON tickets(assigned_groups_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_category ON tickets(ticket_categories_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_tf_ticket ON ticket_followups(tickets_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_tu_ticket ON ticket_users(tickets_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_tu_user ON ticket_users(users_id) TABLESPACE TS_INDEX;

CREATE INDEX idx_np_entity ON network_ports(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_np_asset ON network_ports(assets_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_nc_port1 ON network_connections(network_ports_id_1) TABLESPACE TS_INDEX;
CREATE INDEX idx_nc_port2 ON network_connections(network_ports_id_2) TABLESPACE TS_INDEX;
CREATE INDEX idx_npv_port ON network_port_vlans(network_ports_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_npv_vlan ON network_port_vlans(vlans_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ipn_entity ON ip_networks(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ip_port ON ip_addresses(network_ports_id) TABLESPACE TS_INDEX;

-- =========================
-- INDEX COMPOSITES
-- =========================

CREATE INDEX idx_assets_entity_category ON assets(entities_id, category) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_entity_state ON assets(entities_id, states_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_entity_user ON assets(entities_id, users_id) TABLESPACE TS_INDEX;
CREATE INDEX idx_ticket_entity_status_priority ON tickets(entities_id, status, priority) TABLESPACE TS_INDEX;
CREATE INDEX idx_pu_entity_user ON profiles_users(entities_id, users_id) TABLESPACE TS_INDEX;

-- =========================
-- INDEX FONCTIONNELS
-- =========================

CREATE INDEX idx_assets_name_upper ON assets(UPPER(name)) TABLESPACE TS_INDEX;
CREATE INDEX idx_assets_serial_upper ON assets(UPPER(serial)) TABLESPACE TS_INDEX;
CREATE INDEX idx_users_login_upper ON users(UPPER(login)) TABLESPACE TS_INDEX;

-- =========================
-- INDEX BITMAP
-- =========================

CREATE BITMAP INDEX bmp_assets_category ON assets(category) TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_assets_state ON assets(states_id) TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_users_active ON users(is_active) TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_np_type ON network_ports(port_type) TABLESPACE TS_INDEX;

-- =========================
-- INDEX AUDIT
-- =========================

CREATE INDEX idx_audit_table ON audit_log(table_name) TABLESPACE TS_INDEX;
CREATE INDEX idx_audit_date ON audit_log(change_date) TABLESPACE TS_INDEX;
CREATE INDEX idx_audit_table_record ON audit_log(table_name, record_id) TABLESPACE TS_INDEX;
