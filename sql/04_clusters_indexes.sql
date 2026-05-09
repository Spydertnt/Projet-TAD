-- ============================================================
-- 04_clusters_indexes.sql
-- Clusters et Index — Optimisation des performances
-- Oracle XE
-- ============================================================

-- =========================
-- CLUSTERS
-- =========================

-- Les clusters physiques doivent etre definis avant la creation des tables.
-- Comme 02_schema_tables.sql cree deja les tables, ce script conserve
-- uniquement les index executables et documente les optimisations retenues.

-- =========================
-- INDEX B-TREE (jointures et recherches par FK)
-- =========================

-- === ENTITÉS & LOCALISATIONS ===
CREATE INDEX idx_entities_parent ON entities(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_entities_site ON entities(site_code)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_locations_entity ON locations(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_locations_parent ON locations(locations_id)
    TABLESPACE TS_INDEX;

-- === UTILISATEURS ===
CREATE INDEX idx_users_entity ON users(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_users_location ON users(locations_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_users_active ON users(is_active)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_pu_user ON profiles_users(users_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_pu_profile ON profiles_users(profiles_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_pu_entity ON profiles_users(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_gu_user ON groups_users(users_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_gu_group ON groups_users(groups_id)
    TABLESPACE TS_INDEX;

-- === MATÉRIELS ===
CREATE INDEX idx_comp_entity ON computers(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_comp_user ON computers(users_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_comp_location ON computers(locations_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_comp_state ON computers(states_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_comp_manuf ON computers(manufacturers_id)
    TABLESPACE TS_INDEX;

CREATE INDEX idx_mon_entity ON monitors(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_mon_user ON monitors(users_id)
    TABLESPACE TS_INDEX;

CREATE INDEX idx_per_entity ON peripherals(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_pri_entity ON printers(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_pho_entity ON phones(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_neq_entity ON network_equipments(entities_id)
    TABLESPACE TS_INDEX;

-- === RÉSEAU ===
CREATE INDEX idx_np_entity ON network_ports(entities_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_np_computer ON network_ports(computers_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_np_neq ON network_ports(network_equipments_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_np_printer ON network_ports(printers_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_nc_port1 ON network_connections(network_ports_id_1)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_nc_port2 ON network_connections(network_ports_id_2)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_npv_port ON network_port_vlans(network_ports_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_npv_vlan ON network_port_vlans(vlans_id)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_ipn_entity ON ip_networks(entities_id)
    TABLESPACE TS_INDEX;

-- =========================
-- INDEX COMPOSITES (requêtes multi-critères)
-- =========================

-- Recherche de matériels par site et état
CREATE INDEX idx_comp_entity_state ON computers(entities_id, states_id)
    TABLESPACE TS_INDEX;

-- Recherche de matériels par site et utilisateur
CREATE INDEX idx_comp_entity_user ON computers(entities_id, users_id)
    TABLESPACE TS_INDEX;

-- Profils utilisateurs par entité
CREATE INDEX idx_pu_entity_user ON profiles_users(entities_id, users_id)
    TABLESPACE TS_INDEX;

-- VLANs par entité et tag
CREATE INDEX idx_vlans_entity_tag ON vlans(entities_id, tag)
    TABLESPACE TS_INDEX;

-- =========================
-- INDEX FONCTIONNELS (recherche insensible à la casse)
-- =========================

CREATE INDEX idx_comp_name_upper ON computers(UPPER(name))
    TABLESPACE TS_INDEX;
CREATE INDEX idx_users_name_upper ON users(UPPER(name))
    TABLESPACE TS_INDEX;
CREATE INDEX idx_comp_serial_upper ON computers(UPPER(serial))
    TABLESPACE TS_INDEX;

-- =========================
-- INDEX BITMAP (colonnes à faible cardinalité)
-- =========================

CREATE BITMAP INDEX bmp_comp_state ON computers(states_id)
    TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_mon_state ON monitors(states_id)
    TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_users_active ON users(is_active)
    TABLESPACE TS_INDEX;
CREATE BITMAP INDEX bmp_np_type ON network_ports(instantiation_type)
    TABLESPACE TS_INDEX;

-- =========================
-- INDEX AUDIT
-- =========================

CREATE INDEX idx_audit_table ON audit_log(table_name)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_audit_date ON audit_log(change_date)
    TABLESPACE TS_INDEX;
CREATE INDEX idx_audit_table_record ON audit_log(table_name, record_id)
    TABLESPACE TS_INDEX;
