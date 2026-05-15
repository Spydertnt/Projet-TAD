-- ============================================================
-- 07_bddr.sql
-- Base de Donnees Repartie (BDDR) - Schema simplifie
-- Oracle XE - Database Links, synonymes, vues distribuees
-- ============================================================

-- Prerequis :
-- - Instance Cergy : alias TNS XECERGY
-- - Instance Pau   : alias TNS XEPAU
-- - Utilisateur admin_glpi cree sur les deux instances

-- DEFINE ADMIN_GLPI_PASSWORD = mot_de_passe_admin

CREATE DATABASE LINK DBL_PAU
    CONNECT TO admin_glpi IDENTIFIED BY "&&ADMIN_GLPI_PASSWORD"
    USING 'XEPAU';

-- A executer sur l'instance de Pau :
-- CREATE DATABASE LINK DBL_CERGY
--     CONNECT TO admin_glpi IDENTIFIED BY "&&ADMIN_GLPI_PASSWORD"
--     USING 'XECERGY';

-- Synonymes utiles depuis Cergy vers Pau.
CREATE SYNONYM assets_pau FOR assets@DBL_PAU;
CREATE SYNONYM users_pau FOR users@DBL_PAU;
CREATE SYNONYM entities_pau FOR entities@DBL_PAU;
CREATE SYNONYM network_ports_pau FOR network_ports@DBL_PAU;
CREATE SYNONYM tickets_pau FOR tickets@DBL_PAU;
CREATE SYNONYM ticket_users_pau FOR ticket_users@DBL_PAU;

-- Strategie :
-- - assets, users, tickets, network_ports : fragmentation horizontale par entities.site_code
-- - manufacturers, states, networks, asset_models, ticket_categories : replication

CREATE OR REPLACE PROCEDURE SP_REPLIQUER_REFERENTIELS
AS
BEGIN
    MERGE INTO manufacturers@DBL_PAU dest
    USING manufacturers src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name, dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, name, date_creation, date_mod)
        VALUES (src.id, src.name, src.date_creation, src.date_mod);

    MERGE INTO states@DBL_PAU dest
    USING states src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name, dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, name, date_creation, date_mod)
        VALUES (src.id, src.name, src.date_creation, src.date_mod);

    MERGE INTO networks@DBL_PAU dest
    USING networks src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name, dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, name, date_creation, date_mod)
        VALUES (src.id, src.name, src.date_creation, src.date_mod);

    MERGE INTO asset_models@DBL_PAU dest
    USING asset_models src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.category = src.category,
                   dest.name = src.name,
                   dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, category, name, date_creation, date_mod)
        VALUES (src.id, src.category, src.name, src.date_creation, src.date_mod);

    MERGE INTO ticket_categories@DBL_PAU dest
    USING ticket_categories src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name,
                   dest.description = src.description,
                   dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, name, description, date_creation, date_mod)
        VALUES (src.id, src.name, src.description, src.date_creation, src.date_mod);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Replication des referentiels terminee.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20040, 'Erreur replication: ' || SQLERRM);
END SP_REPLIQUER_REFERENTIELS;
/

CREATE OR REPLACE VIEW V_ASSETS_GLOBAL AS
SELECT a.id, a.category, a.name, a.serial, a.entities_id, e.name AS entite,
       e.site_code AS site, 'CERGY' AS source_instance
FROM assets a
    JOIN entities e ON a.entities_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT a.id, a.category, a.name, a.serial, a.entities_id, e.name AS entite,
       e.site_code AS site, 'PAU' AS source_instance
FROM assets@DBL_PAU a
    JOIN entities@DBL_PAU e ON a.entities_id = e.id
WHERE e.site_code = 'PAU';

CREATE OR REPLACE VIEW V_USERS_GLOBAL AS
SELECT u.id, u.login, u.realname, u.firstname, u.email,
       e.name AS entite, 'CERGY' AS source_instance
FROM users u
    JOIN entities e ON u.entities_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT u.id, u.login, u.realname, u.firstname, u.email,
       e.name AS entite, 'PAU' AS source_instance
FROM users@DBL_PAU u
    JOIN entities@DBL_PAU e ON u.entities_id = e.id
WHERE e.site_code = 'PAU';

CREATE OR REPLACE VIEW V_STATS_GLOBAL AS
SELECT 'CERGY' AS site, FN_COMPTER_MATERIEL_SITE('CERGY') AS total_materiel
FROM DUAL
UNION ALL
SELECT 'PAU' AS site,
       (SELECT COUNT(*) FROM assets@DBL_PAU a JOIN entities@DBL_PAU e ON a.entities_id = e.id WHERE e.site_code = 'PAU') AS total_materiel
FROM DUAL;

CREATE OR REPLACE VIEW V_TICKETS_GLOBAL AS
SELECT t.id, t.title, t.status, t.priority, a.name AS materiel,
       e.name AS entite, 'CERGY' AS source_instance
FROM tickets t
    JOIN assets a ON t.assets_id = a.id
    JOIN entities e ON t.entities_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT t.id, t.title, t.status, t.priority, a.name AS materiel,
       e.name AS entite, 'PAU' AS source_instance
FROM tickets@DBL_PAU t
    JOIN assets@DBL_PAU a ON t.assets_id = a.id
    JOIN entities@DBL_PAU e ON t.entities_id = e.id
WHERE e.site_code = 'PAU';
