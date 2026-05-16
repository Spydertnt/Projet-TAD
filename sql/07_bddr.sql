-- ============================================================
-- 07_bddr.sql
-- Base de Donnees Repartie (BDDR) - Schema simplifie
-- Oracle XE - Database Links, synonymes, vues distribuees
-- ============================================================

-- Prerequis :
-- - Instance Cergy : alias TNS XECERGY
-- - Instance Pau   : alias TNS XEPAU
-- - Utilisateur distant cree sur l'instance cible
--   Exemple reel : admin_glpi
--   Exemple simulation locale : glpi_pau

-- DEFINE BDDR_REMOTE_USER = admin_glpi
-- DEFINE BDDR_REMOTE_PASSWORD = mot_de_passe_admin
-- DEFINE BDDR_REMOTE_SERVICE = XEPAU
--
-- Pour la simulation locale :
-- DEFINE BDDR_REMOTE_USER = glpi_pau
-- DEFINE BDDR_REMOTE_PASSWORD = glpi_pau
-- DEFINE BDDR_REMOTE_SERVICE = (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XE)))
--
-- Si DBL_PAU existe deja, le supprimer avant de relancer :
-- DROP DATABASE LINK DBL_PAU;

CREATE DATABASE LINK DBL_PAU
    CONNECT TO &&BDDR_REMOTE_USER IDENTIFIED BY "&&BDDR_REMOTE_PASSWORD"
    USING '&&BDDR_REMOTE_SERVICE';

-- A executer sur l'instance de Pau :
-- CREATE DATABASE LINK DBL_CERGY
--     CONNECT TO admin_glpi IDENTIFIED BY "&&ADMIN_GLPI_PASSWORD"
--     USING 'XECERGY';

-- Synonymes utiles depuis Cergy vers Pau.
CREATE SYNONYM assets_pau FOR assets@DBL_PAU;
CREATE SYNONYM users_pau FOR users@DBL_PAU;
CREATE SYNONYM sites_pau FOR sites@DBL_PAU;
CREATE SYNONYM network_ports_pau FOR network_ports@DBL_PAU;
CREATE SYNONYM ip_networks_pau FOR ip_networks@DBL_PAU;
CREATE SYNONYM ip_addresses_pau FOR ip_addresses@DBL_PAU;
CREATE SYNONYM tickets_pau FOR tickets@DBL_PAU;
CREATE SYNONYM ticket_users_pau FOR ticket_users@DBL_PAU;
CREATE SYNONYM ticket_followups_pau FOR ticket_followups@DBL_PAU;

-- Strategie :
-- - assets, users, tickets, network_ports, ip_networks, ip_addresses : fragmentation horizontale par sites.site_code
-- - manufacturers, states, ticket_categories : replication
-- - Un transfert inter-sites suppose que les sites et les utilisateurs referents
--   existent sur l'instance cible avec les memes identifiants.

CREATE OR REPLACE PROCEDURE SP_REPLIQUER_REFERENTIELS
AS
BEGIN
    MERGE INTO manufacturers@DBL_PAU dest
    USING manufacturers src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name
    WHEN NOT MATCHED THEN
        INSERT (id, name)
        VALUES (src.id, src.name);

    MERGE INTO states@DBL_PAU dest
    USING states src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name
    WHEN NOT MATCHED THEN
        INSERT (id, name)
        VALUES (src.id, src.name);

    MERGE INTO ticket_categories@DBL_PAU dest
    USING ticket_categories src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name,
                   dest.description = src.description
    WHEN NOT MATCHED THEN
        INSERT (id, name, description)
        VALUES (src.id, src.name, src.description);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Replication des referentiels terminee.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20040, 'Erreur replication: ' || SQLERRM);
END SP_REPLIQUER_REFERENTIELS;
/

CREATE OR REPLACE VIEW V_ASSETS_GLOBAL AS
SELECT a.id, a.asset_type, a.name, a.serial_number, a.site_id, e.name AS entite,
       e.site_code AS site, 'CERGY' AS source_instance
FROM assets a
    JOIN sites e ON a.site_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT a.id, a.asset_type, a.name, a.serial_number, a.site_id, e.name AS entite,
       e.site_code AS site, 'PAU' AS source_instance
FROM assets@DBL_PAU a
    JOIN sites@DBL_PAU e ON a.site_id = e.id
WHERE e.site_code = 'PAU';

CREATE OR REPLACE VIEW V_USERS_GLOBAL AS
SELECT u.id, u.login, u.last_name, u.first_name, u.email,
       e.name AS entite, 'CERGY' AS source_instance
FROM users u
    JOIN sites e ON u.site_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT u.id, u.login, u.last_name, u.first_name, u.email,
       e.name AS entite, 'PAU' AS source_instance
FROM users@DBL_PAU u
    JOIN sites@DBL_PAU e ON u.site_id = e.id
WHERE e.site_code = 'PAU';

CREATE OR REPLACE VIEW V_STATS_GLOBAL AS
SELECT 'CERGY' AS site, FN_COMPTER_MATERIEL_SITE('CERGY') AS total_materiel
FROM DUAL
UNION ALL
SELECT 'PAU' AS site,
       (SELECT COUNT(*) FROM assets@DBL_PAU a JOIN sites@DBL_PAU e ON a.site_id = e.id WHERE e.site_code = 'PAU') AS total_materiel
FROM DUAL;

CREATE OR REPLACE VIEW V_TICKETS_GLOBAL AS
SELECT t.id, t.title, t.status, t.priority, a.name AS materiel,
       e.name AS entite, 'CERGY' AS source_instance
FROM tickets t
    JOIN assets a ON t.asset_id = a.id
    JOIN sites e ON t.site_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT t.id, t.title, t.status, t.priority, a.name AS materiel,
       e.name AS entite, 'PAU' AS source_instance
FROM tickets@DBL_PAU t
    JOIN assets@DBL_PAU a ON t.asset_id = a.id
    JOIN sites@DBL_PAU e ON t.site_id = e.id
WHERE e.site_code = 'PAU';
