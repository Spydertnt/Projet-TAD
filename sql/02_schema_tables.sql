-- ============================================================
-- 02_schema_tables.sql
-- Schema simplifie - BDD GLPI Multi-Sites
-- Oracle XE - 19 tables, FK explicites, noms de champs lisibles
-- ============================================================

-- cleanup: drop objects if they already exist so the script can be rerun
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ticket_followups PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ticket_users PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE tickets PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ticket_categories PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ip_addresses PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE network_ports PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ip_networks PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE assets PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE groups_users PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE groups PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE profiles_users PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE profiles PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE users PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE locations PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE sites PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE manufacturers PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE states PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE audit_log PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE archives_materiel PURGE';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_cluster_user_rights';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -1418 AND SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_cluster_site_structure';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -1418 AND SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_cluster_ticket_details';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -1418 AND SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_cluster_network_port_ips';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -1418 AND SQLCODE != -942 THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP CLUSTER cluster_user_rights';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE NOT IN (-942, -943) THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP CLUSTER cluster_site_structure';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE NOT IN (-942, -943) THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP CLUSTER cluster_ticket_details';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE NOT IN (-942, -943) THEN
        RAISE;
    END IF;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP CLUSTER cluster_network_port_ips';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE NOT IN (-942, -943) THEN
        RAISE;
    END IF;
END;
/
-- =========================
-- TABLES TRANSVERSALES
-- =========================

CREATE CLUSTER cluster_user_rights(
    user_id NUMBER
) SIZE 1024 TABLESPACE TS_UTILISATEURS;

CREATE CLUSTER cluster_site_structure(
    site_id NUMBER
) SIZE 2048 TABLESPACE TS_MATERIEL;

CREATE CLUSTER cluster_network_port_ips(
    network_port_id NUMBER
) SIZE 1024 TABLESPACE TS_RESEAU;

CREATE INDEX idx_cluster_user_rights
    ON CLUSTER cluster_user_rights
    TABLESPACE TS_UTILISATEURS;

CREATE INDEX idx_cluster_site_structure
    ON CLUSTER cluster_site_structure
    TABLESPACE TS_MATERIEL;

CREATE INDEX idx_cluster_network_port_ips
    ON CLUSTER cluster_network_port_ips
    TABLESPACE TS_RESEAU;

CREATE TABLE sites (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name                VARCHAR2(255) NOT NULL,
    parent_site_id    NUMBER,
    full_name           VARCHAR2(1000),
    site_code           VARCHAR2(10) CHECK (site_code IN ('CERGY','PAU')),
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP
) CLUSTER cluster_site_structure (id);

ALTER TABLE sites ADD CONSTRAINT fk_sites_parent
    FOREIGN KEY (parent_site_id) REFERENCES sites(id);

CREATE TABLE locations (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    site_id           NUMBER NOT NULL,
    name                VARCHAR2(255) NOT NULL,
    parent_location_id  NUMBER,
    full_name           VARCHAR2(1000),
    building            VARCHAR2(255),
    room                VARCHAR2(255),
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_loc_site FOREIGN KEY (site_id) REFERENCES sites(id)
) CLUSTER cluster_site_structure (site_id);

ALTER TABLE locations ADD CONSTRAINT fk_loc_parent
    FOREIGN KEY (parent_location_id) REFERENCES locations(id);

CREATE TABLE manufacturers (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name                VARCHAR2(255) NOT NULL UNIQUE
) TABLESPACE TS_MATERIEL;

CREATE TABLE states (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name                VARCHAR2(255) NOT NULL UNIQUE
) TABLESPACE TS_MATERIEL;

-- =========================
-- UTILISATEURS ET DROITS
-- =========================

CREATE TABLE users (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    login               VARCHAR2(255) NOT NULL UNIQUE,
    last_name           VARCHAR2(255),
    first_name          VARCHAR2(255),
    email               VARCHAR2(255),
    phone               VARCHAR2(100),
    site_id           NUMBER NOT NULL,
    location_id         NUMBER,
    supervisor_user_id  NUMBER,
    is_active           NUMBER(1) DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_users_site FOREIGN KEY (site_id) REFERENCES sites(id),
    CONSTRAINT fk_users_loc FOREIGN KEY (location_id) REFERENCES locations(id)
) CLUSTER cluster_user_rights (id);

ALTER TABLE users ADD CONSTRAINT fk_users_supervisor
    FOREIGN KEY (supervisor_user_id) REFERENCES users(id);

CREATE TABLE profiles (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name                VARCHAR2(255) NOT NULL UNIQUE,
    interface           VARCHAR2(50) DEFAULT 'central',
    is_default          NUMBER(1) DEFAULT 0 CHECK (is_default IN (0, 1))
) TABLESPACE TS_UTILISATEURS;

CREATE TABLE profiles_users (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id             NUMBER NOT NULL,
    profile_id          NUMBER NOT NULL,
    site_id           NUMBER NOT NULL,
    is_recursive        NUMBER(1) DEFAULT 0 CHECK (is_recursive IN (0, 1)),
    CONSTRAINT fk_pu_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_pu_profile FOREIGN KEY (profile_id) REFERENCES profiles(id),
    CONSTRAINT fk_pu_site FOREIGN KEY (site_id) REFERENCES sites(id),
    CONSTRAINT uq_profile_user_site UNIQUE (user_id, profile_id, site_id)
) CLUSTER cluster_user_rights (user_id);

CREATE TABLE groups (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    site_id           NUMBER NOT NULL,
    name                VARCHAR2(255) NOT NULL,
    parent_group_id     NUMBER,
    full_name           VARCHAR2(1000),
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_groups_site FOREIGN KEY (site_id) REFERENCES sites(id)
) CLUSTER cluster_site_structure (site_id);

ALTER TABLE groups ADD CONSTRAINT fk_groups_parent
    FOREIGN KEY (parent_group_id) REFERENCES groups(id);

CREATE TABLE groups_users (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id             NUMBER NOT NULL,
    group_id            NUMBER NOT NULL,
    is_manager          NUMBER(1) DEFAULT 0 CHECK (is_manager IN (0, 1)),
    CONSTRAINT fk_gu_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_gu_group FOREIGN KEY (group_id) REFERENCES groups(id),
    CONSTRAINT uq_group_user UNIQUE (user_id, group_id)
) CLUSTER cluster_user_rights (user_id);

-- =========================
-- INVENTAIRE
-- =========================

CREATE TABLE assets (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    site_id           NUMBER NOT NULL,
    asset_type          VARCHAR2(50) NOT NULL
        CHECK (asset_type IN ('COMPUTER','MONITOR','PERIPHERAL','PRINTER','PHONE','NETWORK_EQUIPMENT')),
    name                VARCHAR2(255) NOT NULL,
    serial_number       VARCHAR2(255),
    owner_user_id       NUMBER,
    technician_user_id  NUMBER,
    location_id         NUMBER,
    manufacturer_id     NUMBER,
    state_id            NUMBER,
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_assets_site FOREIGN KEY (site_id) REFERENCES sites(id),
    CONSTRAINT fk_assets_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
    CONSTRAINT fk_assets_technician FOREIGN KEY (technician_user_id) REFERENCES users(id),
    CONSTRAINT fk_assets_loc FOREIGN KEY (location_id) REFERENCES locations(id),
    CONSTRAINT fk_assets_manuf FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id),
    CONSTRAINT fk_assets_state FOREIGN KEY (state_id) REFERENCES states(id),
    CONSTRAINT uq_assets_site_serial UNIQUE (site_id, serial_number)
) TABLESPACE TS_MATERIEL;

-- =========================
-- SUPPORT / TICKETS
-- =========================

CREATE TABLE ticket_categories (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name                VARCHAR2(255) NOT NULL UNIQUE,
    description         VARCHAR2(1000)
) TABLESPACE TS_SUPPORT;

CREATE TABLE tickets (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    site_id           NUMBER NOT NULL,
    asset_id            NUMBER NOT NULL,
    title               VARCHAR2(255) NOT NULL,
    description         CLOB NOT NULL,
    status              VARCHAR2(30) DEFAULT 'NOUVEAU' NOT NULL
        CHECK (status IN ('NOUVEAU','ASSIGNE','EN_COURS','EN_ATTENTE','RESOLU','CLOS','ANNULE')),
    priority            VARCHAR2(20) DEFAULT 'MOYENNE' NOT NULL
        CHECK (priority IN ('BASSE','MOYENNE','HAUTE','CRITIQUE')),
    requester_user_id   NUMBER NOT NULL,
    assigned_group_id   NUMBER,
    category_id         NUMBER,
    resolution          CLOB,
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    assigned_at         TIMESTAMP,
    resolved_at         TIMESTAMP,
    closed_at           TIMESTAMP,
    CONSTRAINT fk_ticket_site FOREIGN KEY (site_id) REFERENCES sites(id),
    CONSTRAINT fk_ticket_asset FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    CONSTRAINT fk_ticket_requester FOREIGN KEY (requester_user_id) REFERENCES users(id),
    CONSTRAINT fk_ticket_assigned_group FOREIGN KEY (assigned_group_id) REFERENCES groups(id),
    CONSTRAINT fk_ticket_category FOREIGN KEY (category_id) REFERENCES ticket_categories(id)
) TABLESPACE TS_SUPPORT;

CREATE TABLE ticket_users (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    ticket_id           NUMBER NOT NULL,
    user_id             NUMBER NOT NULL,
    assigned_by_user_id NUMBER,
    assigned_at         TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_tu_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    CONSTRAINT fk_tu_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_tu_assigned_by FOREIGN KEY (assigned_by_user_id) REFERENCES users(id),
    CONSTRAINT uq_ticket_user UNIQUE (ticket_id, user_id)
) TABLESPACE TS_SUPPORT;

CREATE TABLE ticket_followups (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    ticket_id           NUMBER NOT NULL,
    user_id             NUMBER NOT NULL,
    content             CLOB NOT NULL,
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_tf_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    CONSTRAINT fk_tf_user FOREIGN KEY (user_id) REFERENCES users(id)
) TABLESPACE TS_SUPPORT;

-- =========================
-- RESEAU ESSENTIEL
-- =========================

CREATE TABLE network_ports (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    site_id           NUMBER NOT NULL,
    asset_id            NUMBER NOT NULL,
    port_name           VARCHAR2(255),
    mac_address         VARCHAR2(50),
    port_type           VARCHAR2(100),
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_np_site FOREIGN KEY (site_id) REFERENCES sites(id),
    CONSTRAINT fk_np_asset FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
) CLUSTER cluster_network_port_ips (id);

CREATE TABLE ip_networks (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    site_id           NUMBER NOT NULL,
    network_name        VARCHAR2(255),
    network_address     VARCHAR2(40) NOT NULL,
    subnet_mask         VARCHAR2(40) NOT NULL,
    gateway_address     VARCHAR2(40),
    vlan_name           VARCHAR2(255),
    vlan_tag            NUMBER,
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_ipn_site FOREIGN KEY (site_id) REFERENCES sites(id),
    CONSTRAINT uq_ipn_site_network UNIQUE (site_id, network_address, subnet_mask)
) CLUSTER cluster_site_structure (site_id);

CREATE TABLE ip_addresses (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    site_id           NUMBER NOT NULL,
    network_port_id     NUMBER,
    ip_network_id       NUMBER,
    ip_address          VARCHAR2(40) NOT NULL,
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_ip_site FOREIGN KEY (site_id) REFERENCES sites(id),
    CONSTRAINT fk_ip_port FOREIGN KEY (network_port_id) REFERENCES network_ports(id) ON DELETE SET NULL,
    CONSTRAINT fk_ip_network FOREIGN KEY (ip_network_id) REFERENCES ip_networks(id)
) CLUSTER cluster_network_port_ips (network_port_id);

-- =========================
-- TABLES SYSTEME
-- =========================

CREATE TABLE audit_log (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    table_name          VARCHAR2(100) NOT NULL,
    row_id              NUMBER NOT NULL,
    action              VARCHAR2(10) NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
    old_data            CLOB,
    new_data            CLOB,
    changed_by          VARCHAR2(100) DEFAULT USER,
    changed_at          TIMESTAMP DEFAULT SYSTIMESTAMP
) TABLESPACE TS_MATERIEL;

CREATE TABLE archives_materiel (
    id                  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    original_table      VARCHAR2(100) NOT NULL,
    original_id         NUMBER NOT NULL,
    archived_data       CLOB NOT NULL,
    archived_by         VARCHAR2(100) DEFAULT USER,
    archived_at         TIMESTAMP DEFAULT SYSTIMESTAMP
) TABLESPACE TS_MATERIEL;
