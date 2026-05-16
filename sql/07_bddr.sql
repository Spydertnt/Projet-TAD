-- ============================================================
-- 07_bddr.sql
-- Simulation BDDR sur une seule instance Oracle XE
-- Deux schemas locaux + DATABASE LINK local
-- ============================================================

-- Objectif :
-- Simuler deux bases reparties sur un seul PC avec un DB Link local.
--
-- Le schema principal contient les tables physiques.
-- Les schemas GLPI_CERGY et GLPI_PAU exposent chacun une fragmentation locale
-- via des vues filtrees sur sites.site_code.
--
-- A lancer avec SYSTEM apres :
-- 01_tablespaces.sql, 02_schema_tables.sql, 04_clusters_indexes.sql,
-- 03_users_roles.sql, 05_views.sql, 06_plsql/functions.sql et 09_test_data.sql.

-- A adapter si les tables physiques ne sont pas dans SYSTEM.
DEFINE BASE_SCHEMA = SYSTEM

-- Mots de passe des deux schemas de simulation.
DEFINE GLPI_CERGY_PASSWORD = glpi_cergy_pwd
DEFINE GLPI_PAU_PASSWORD = glpi_pau_pwd

-- Connexion locale utilisee par les DB links.
-- Si ton service Oracle est different, remplace XE par XEPDB1 ou ton service.
-- Exemples :
-- DEFINE LOCAL_CONNECT_ALIAS = localhost:1521/XE
-- DEFINE LOCAL_CONNECT_ALIAS = localhost:1521/XEPDB1
DEFINE LOCAL_CONNECT_ALIAS = localhost:1521/XE

-- ============================================================
-- 1. CREATION DES DEUX SCHEMAS LOCAUX
-- ============================================================

BEGIN
    EXECUTE IMMEDIATE 'CREATE USER glpi_cergy IDENTIFIED BY "&&GLPI_CERGY_PASSWORD"
        DEFAULT TABLESPACE TS_MATERIEL
        TEMPORARY TABLESPACE TS_TEMP_GLPI
        QUOTA 0 ON TS_MATERIEL';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE = -1920 THEN
        EXECUTE IMMEDIATE 'ALTER USER glpi_cergy IDENTIFIED BY "&&GLPI_CERGY_PASSWORD"';
    ELSE
        RAISE;
    END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'CREATE USER glpi_pau IDENTIFIED BY "&&GLPI_PAU_PASSWORD"
        DEFAULT TABLESPACE TS_MATERIEL
        TEMPORARY TABLESPACE TS_TEMP_GLPI
        QUOTA 0 ON TS_MATERIEL';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE = -1920 THEN
        EXECUTE IMMEDIATE 'ALTER USER glpi_pau IDENTIFIED BY "&&GLPI_PAU_PASSWORD"';
    ELSE
        RAISE;
    END IF;
END;
/

GRANT CREATE SESSION, CREATE VIEW, CREATE SYNONYM, CREATE DATABASE LINK, CREATE PROCEDURE TO glpi_cergy;
GRANT CREATE SESSION, CREATE VIEW, CREATE SYNONYM, CREATE DATABASE LINK TO glpi_pau;

-- Droits de lecture directs necessaires pour compiler les vues des schemas.
GRANT SELECT ON sites TO glpi_cergy;
GRANT SELECT ON locations TO glpi_cergy;
GRANT SELECT ON manufacturers TO glpi_cergy;
GRANT SELECT ON states TO glpi_cergy;
GRANT SELECT ON users TO glpi_cergy;
GRANT SELECT ON profiles TO glpi_cergy;
GRANT SELECT ON profiles_users TO glpi_cergy;
GRANT SELECT ON groups TO glpi_cergy;
GRANT SELECT ON groups_users TO glpi_cergy;
GRANT SELECT ON assets TO glpi_cergy;
GRANT SELECT ON ticket_categories TO glpi_cergy;
GRANT SELECT ON tickets TO glpi_cergy;
GRANT SELECT ON ticket_users TO glpi_cergy;
GRANT SELECT ON ticket_followups TO glpi_cergy;
GRANT SELECT ON network_ports TO glpi_cergy;
GRANT SELECT ON ip_networks TO glpi_cergy;
GRANT SELECT ON ip_addresses TO glpi_cergy;

GRANT SELECT ON sites TO glpi_pau;
GRANT SELECT ON locations TO glpi_pau;
GRANT SELECT ON manufacturers TO glpi_pau;
GRANT SELECT ON states TO glpi_pau;
GRANT SELECT ON users TO glpi_pau;
GRANT SELECT ON profiles TO glpi_pau;
GRANT SELECT ON profiles_users TO glpi_pau;
GRANT SELECT ON groups TO glpi_pau;
GRANT SELECT ON groups_users TO glpi_pau;
GRANT SELECT ON assets TO glpi_pau;
GRANT SELECT ON ticket_categories TO glpi_pau;
GRANT SELECT ON tickets TO glpi_pau;
GRANT SELECT ON ticket_users TO glpi_pau;
GRANT SELECT ON ticket_followups TO glpi_pau;
GRANT SELECT ON network_ports TO glpi_pau;
GRANT SELECT ON ip_networks TO glpi_pau;
GRANT SELECT ON ip_addresses TO glpi_pau;

-- ============================================================
-- 2. FRAGMENT CERGY
-- ============================================================

CREATE OR REPLACE VIEW glpi_cergy.sites AS
SELECT *
FROM &&BASE_SCHEMA..sites
WHERE site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.locations AS
SELECT l.*
FROM &&BASE_SCHEMA..locations l
    JOIN &&BASE_SCHEMA..sites s ON l.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.users AS
SELECT u.*
FROM &&BASE_SCHEMA..users u
    JOIN &&BASE_SCHEMA..sites s ON u.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.groups AS
SELECT g.*
FROM &&BASE_SCHEMA..groups g
    JOIN &&BASE_SCHEMA..sites s ON g.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.groups_users AS
SELECT gu.*
FROM &&BASE_SCHEMA..groups_users gu
    JOIN &&BASE_SCHEMA..groups g ON gu.group_id = g.id
    JOIN &&BASE_SCHEMA..sites s ON g.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.profiles_users AS
SELECT pu.*
FROM &&BASE_SCHEMA..profiles_users pu
    JOIN &&BASE_SCHEMA..sites s ON pu.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.assets AS
SELECT a.*
FROM &&BASE_SCHEMA..assets a
    JOIN &&BASE_SCHEMA..sites s ON a.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.tickets AS
SELECT
    t.id,
    t.site_id,
    t.asset_id,
    t.title,
    t.status,
    t.priority,
    t.requester_user_id,
    t.assigned_group_id,
    t.category_id,
    t.created_at,
    t.updated_at,
    t.assigned_at,
    t.resolved_at,
    t.closed_at
FROM &&BASE_SCHEMA..tickets t
    JOIN &&BASE_SCHEMA..sites s ON t.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.ticket_users AS
SELECT tu.*
FROM &&BASE_SCHEMA..ticket_users tu
    JOIN &&BASE_SCHEMA..tickets t ON tu.ticket_id = t.id
    JOIN &&BASE_SCHEMA..sites s ON t.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.ticket_followups AS
SELECT tf.*
FROM &&BASE_SCHEMA..ticket_followups tf
    JOIN &&BASE_SCHEMA..tickets t ON tf.ticket_id = t.id
    JOIN &&BASE_SCHEMA..sites s ON t.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.network_ports AS
SELECT np.*
FROM &&BASE_SCHEMA..network_ports np
    JOIN &&BASE_SCHEMA..sites s ON np.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.ip_networks AS
SELECT ipn.*
FROM &&BASE_SCHEMA..ip_networks ipn
    JOIN &&BASE_SCHEMA..sites s ON ipn.site_id = s.id
WHERE s.site_code = 'CERGY';

CREATE OR REPLACE VIEW glpi_cergy.ip_addresses AS
SELECT ia.*
FROM &&BASE_SCHEMA..ip_addresses ia
    JOIN &&BASE_SCHEMA..sites s ON ia.site_id = s.id
WHERE s.site_code = 'CERGY';

-- Referentiels repliques logiquement.
CREATE OR REPLACE VIEW glpi_cergy.manufacturers AS SELECT * FROM &&BASE_SCHEMA..manufacturers;
CREATE OR REPLACE VIEW glpi_cergy.states AS SELECT * FROM &&BASE_SCHEMA..states;
CREATE OR REPLACE VIEW glpi_cergy.profiles AS SELECT * FROM &&BASE_SCHEMA..profiles;
CREATE OR REPLACE VIEW glpi_cergy.ticket_categories AS SELECT * FROM &&BASE_SCHEMA..ticket_categories;

-- ============================================================
-- 3. FRAGMENT PAU
-- ============================================================

CREATE OR REPLACE VIEW glpi_pau.sites AS
SELECT *
FROM &&BASE_SCHEMA..sites
WHERE site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.locations AS
SELECT l.*
FROM &&BASE_SCHEMA..locations l
    JOIN &&BASE_SCHEMA..sites s ON l.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.users AS
SELECT u.*
FROM &&BASE_SCHEMA..users u
    JOIN &&BASE_SCHEMA..sites s ON u.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.groups AS
SELECT g.*
FROM &&BASE_SCHEMA..groups g
    JOIN &&BASE_SCHEMA..sites s ON g.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.groups_users AS
SELECT gu.*
FROM &&BASE_SCHEMA..groups_users gu
    JOIN &&BASE_SCHEMA..groups g ON gu.group_id = g.id
    JOIN &&BASE_SCHEMA..sites s ON g.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.profiles_users AS
SELECT pu.*
FROM &&BASE_SCHEMA..profiles_users pu
    JOIN &&BASE_SCHEMA..sites s ON pu.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.assets AS
SELECT a.*
FROM &&BASE_SCHEMA..assets a
    JOIN &&BASE_SCHEMA..sites s ON a.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.tickets AS
SELECT
    t.id,
    t.site_id,
    t.asset_id,
    t.title,
    t.status,
    t.priority,
    t.requester_user_id,
    t.assigned_group_id,
    t.category_id,
    t.created_at,
    t.updated_at,
    t.assigned_at,
    t.resolved_at,
    t.closed_at
FROM &&BASE_SCHEMA..tickets t
    JOIN &&BASE_SCHEMA..sites s ON t.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.ticket_users AS
SELECT tu.*
FROM &&BASE_SCHEMA..ticket_users tu
    JOIN &&BASE_SCHEMA..tickets t ON tu.ticket_id = t.id
    JOIN &&BASE_SCHEMA..sites s ON t.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.ticket_followups AS
SELECT tf.*
FROM &&BASE_SCHEMA..ticket_followups tf
    JOIN &&BASE_SCHEMA..tickets t ON tf.ticket_id = t.id
    JOIN &&BASE_SCHEMA..sites s ON t.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.network_ports AS
SELECT np.*
FROM &&BASE_SCHEMA..network_ports np
    JOIN &&BASE_SCHEMA..sites s ON np.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.ip_networks AS
SELECT ipn.*
FROM &&BASE_SCHEMA..ip_networks ipn
    JOIN &&BASE_SCHEMA..sites s ON ipn.site_id = s.id
WHERE s.site_code = 'PAU';

CREATE OR REPLACE VIEW glpi_pau.ip_addresses AS
SELECT ia.*
FROM &&BASE_SCHEMA..ip_addresses ia
    JOIN &&BASE_SCHEMA..sites s ON ia.site_id = s.id
WHERE s.site_code = 'PAU';

-- Referentiels repliques logiquement.
CREATE OR REPLACE VIEW glpi_pau.manufacturers AS SELECT * FROM &&BASE_SCHEMA..manufacturers;
CREATE OR REPLACE VIEW glpi_pau.states AS SELECT * FROM &&BASE_SCHEMA..states;
CREATE OR REPLACE VIEW glpi_pau.profiles AS SELECT * FROM &&BASE_SCHEMA..profiles;
CREATE OR REPLACE VIEW glpi_pau.ticket_categories AS SELECT * FROM &&BASE_SCHEMA..ticket_categories;

-- ============================================================
-- 4. DB LINK LOCAL : GLPI_CERGY -> GLPI_PAU
-- ============================================================

CONNECT glpi_cergy/&&GLPI_CERGY_PASSWORD@&&LOCAL_CONNECT_ALIAS

BEGIN
    EXECUTE IMMEDIATE 'DROP DATABASE LINK lien_pau';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -2024 THEN
        RAISE;
    END IF;
END;
/

CREATE DATABASE LINK lien_pau
    CONNECT TO glpi_pau IDENTIFIED BY "&&GLPI_PAU_PASSWORD"
    USING '&&LOCAL_CONNECT_ALIAS';

CREATE OR REPLACE SYNONYM assets_pau FOR assets@lien_pau;
CREATE OR REPLACE SYNONYM users_pau FOR users@lien_pau;
CREATE OR REPLACE SYNONYM sites_pau FOR sites@lien_pau;
CREATE OR REPLACE SYNONYM tickets_pau FOR tickets@lien_pau;
CREATE OR REPLACE SYNONYM network_ports_pau FOR network_ports@lien_pau;
CREATE OR REPLACE SYNONYM ip_networks_pau FOR ip_networks@lien_pau;
CREATE OR REPLACE SYNONYM ip_addresses_pau FOR ip_addresses@lien_pau;

CREATE OR REPLACE PROCEDURE SP_REPLIQUER_REFERENTIELS
AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('Simulation DB Link locale : GLPI_CERGY interroge GLPI_PAU via lien_pau.');
    DBMS_OUTPUT.PUT_LINE('Les referentiels sont exposes par vues dans les deux schemas.');
END SP_REPLIQUER_REFERENTIELS;
/

CREATE OR REPLACE VIEW V_ASSETS_GLOBAL AS
SELECT a.id, a.asset_type, a.name, a.serial_number, a.site_id,
       s.name AS entite, s.site_code AS site, 'GLPI_CERGY' AS source_schema
FROM assets a
    JOIN sites s ON a.site_id = s.id
UNION ALL
SELECT a.id, a.asset_type, a.name, a.serial_number, a.site_id,
       s.name AS entite, s.site_code AS site, 'GLPI_PAU@LIEN_PAU' AS source_schema
FROM assets@lien_pau a
    JOIN sites@lien_pau s ON a.site_id = s.id;

CREATE OR REPLACE VIEW V_USERS_GLOBAL AS
SELECT u.id, u.login, u.last_name, u.first_name, u.email,
       s.name AS entite, s.site_code AS site, 'GLPI_CERGY' AS source_schema
FROM users u
    JOIN sites s ON u.site_id = s.id
UNION ALL
SELECT u.id, u.login, u.last_name, u.first_name, u.email,
       s.name AS entite, s.site_code AS site, 'GLPI_PAU@LIEN_PAU' AS source_schema
FROM users@lien_pau u
    JOIN sites@lien_pau s ON u.site_id = s.id;

CREATE OR REPLACE VIEW V_STATS_GLOBAL AS
SELECT 'CERGY' AS site, COUNT(*) AS total_materiel
FROM assets
UNION ALL
SELECT 'PAU' AS site, COUNT(*) AS total_materiel
FROM assets@lien_pau;

CREATE OR REPLACE VIEW V_TICKETS_GLOBAL AS
SELECT t.id, t.title, t.status, t.priority, a.name AS materiel,
       s.name AS entite, 'GLPI_CERGY' AS source_schema
FROM tickets t
    JOIN assets a ON t.asset_id = a.id
    JOIN sites s ON t.site_id = s.id
UNION ALL
SELECT t.id, t.title, t.status, t.priority, a.name AS materiel,
       s.name AS entite, 'GLPI_PAU@LIEN_PAU' AS source_schema
FROM tickets@lien_pau t
    JOIN assets@lien_pau a ON t.asset_id = a.id
    JOIN sites@lien_pau s ON t.site_id = s.id;

-- Verification rapide.
SELECT 'GLPI_CERGY.assets' AS objet, COUNT(*) AS nb_lignes FROM assets
UNION ALL
SELECT 'GLPI_PAU.assets via lien_pau', COUNT(*) FROM assets@lien_pau
UNION ALL
SELECT 'V_ASSETS_GLOBAL', COUNT(*) FROM V_ASSETS_GLOBAL;

-- ============================================================
-- 5. DB LINK LOCAL INVERSE : GLPI_PAU -> GLPI_CERGY
-- ============================================================

CONNECT glpi_pau/&&GLPI_PAU_PASSWORD@&&LOCAL_CONNECT_ALIAS

BEGIN
    EXECUTE IMMEDIATE 'DROP DATABASE LINK lien_cergy';
EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -2024 THEN
        RAISE;
    END IF;
END;
/

CREATE DATABASE LINK lien_cergy
    CONNECT TO glpi_cergy IDENTIFIED BY "&&GLPI_CERGY_PASSWORD"
    USING '&&LOCAL_CONNECT_ALIAS';

CREATE OR REPLACE SYNONYM assets_cergy FOR assets@lien_cergy;
CREATE OR REPLACE SYNONYM users_cergy FOR users@lien_cergy;
CREATE OR REPLACE SYNONYM sites_cergy FOR sites@lien_cergy;
CREATE OR REPLACE SYNONYM tickets_cergy FOR tickets@lien_cergy;
CREATE OR REPLACE SYNONYM network_ports_cergy FOR network_ports@lien_cergy;
CREATE OR REPLACE SYNONYM ip_networks_cergy FOR ip_networks@lien_cergy;
CREATE OR REPLACE SYNONYM ip_addresses_cergy FOR ip_addresses@lien_cergy;

CREATE OR REPLACE VIEW V_ASSETS_GLOBAL AS
SELECT a.id, a.asset_type, a.name, a.serial_number, a.site_id,
       s.name AS entite, s.site_code AS site, 'GLPI_PAU' AS source_schema
FROM assets a
    JOIN sites s ON a.site_id = s.id
UNION ALL
SELECT a.id, a.asset_type, a.name, a.serial_number, a.site_id,
       s.name AS entite, s.site_code AS site, 'GLPI_CERGY@LIEN_CERGY' AS source_schema
FROM assets@lien_cergy a
    JOIN sites@lien_cergy s ON a.site_id = s.id;

CREATE OR REPLACE VIEW V_USERS_GLOBAL AS
SELECT u.id, u.login, u.last_name, u.first_name, u.email,
       s.name AS entite, s.site_code AS site, 'GLPI_PAU' AS source_schema
FROM users u
    JOIN sites s ON u.site_id = s.id
UNION ALL
SELECT u.id, u.login, u.last_name, u.first_name, u.email,
       s.name AS entite, s.site_code AS site, 'GLPI_CERGY@LIEN_CERGY' AS source_schema
FROM users@lien_cergy u
    JOIN sites@lien_cergy s ON u.site_id = s.id;

CREATE OR REPLACE VIEW V_STATS_GLOBAL AS
SELECT 'PAU' AS site, COUNT(*) AS total_materiel
FROM assets
UNION ALL
SELECT 'CERGY' AS site, COUNT(*) AS total_materiel
FROM assets@lien_cergy;

CREATE OR REPLACE VIEW V_TICKETS_GLOBAL AS
SELECT t.id, t.title, t.status, t.priority, a.name AS materiel,
       s.name AS entite, 'GLPI_PAU' AS source_schema
FROM tickets t
    JOIN assets a ON t.asset_id = a.id
    JOIN sites s ON t.site_id = s.id
UNION ALL
SELECT t.id, t.title, t.status, t.priority, a.name AS materiel,
       s.name AS entite, 'GLPI_CERGY@LIEN_CERGY' AS source_schema
FROM tickets@lien_cergy t
    JOIN assets@lien_cergy a ON t.asset_id = a.id
    JOIN sites@lien_cergy s ON t.site_id = s.id;

-- Verification rapide cote Pau.
SELECT 'GLPI_PAU.assets' AS objet, COUNT(*) AS nb_lignes FROM assets
UNION ALL
SELECT 'GLPI_CERGY.assets via lien_cergy', COUNT(*) FROM assets@lien_cergy
UNION ALL
SELECT 'V_ASSETS_GLOBAL', COUNT(*) FROM V_ASSETS_GLOBAL;
