-- ============================================================
-- 07_bddr.sql
-- Base de Données Répartie (BDDR) — Cergy / Pau
-- Oracle XE — Database Links, Synonymes, Vues distribuées
-- ============================================================
-- PRÉREQUIS :
-- - Deux instances Oracle XE configurées (une par site)
-- - Instance Cergy : SID = XECERGY (ou service name)
-- - Instance Pau   : SID = XEPAU
-- - Connexion réseau entre les deux serveurs (tnsnames.ora)
-- ============================================================

-- =========================
-- 1. CONFIGURATION TNS (à ajouter dans tnsnames.ora)
-- =========================
-- XECERGY =
--   (DESCRIPTION =
--     (ADDRESS = (PROTOCOL = TCP)(HOST = srv-cergy)(PORT = 1521))
--     (CONNECT_DATA = (SERVICE_NAME = XEPDB1))
--   )
--
-- XEPAU =
--   (DESCRIPTION =
--     (ADDRESS = (PROTOCOL = TCP)(HOST = srv-pau)(PORT = 1521))
--     (CONNECT_DATA = (SERVICE_NAME = XEPDB1))
--   )

-- =========================
-- 2. DATABASE LINKS
-- =========================

-- Avant execution SQL*Plus/SQLcl :
-- DEFINE ADMIN_GLPI_PASSWORD = mot_de_passe_admin

-- Depuis le site CERGY → accès au site PAU
CREATE DATABASE LINK DBL_PAU
    CONNECT TO admin_glpi IDENTIFIED BY "&&ADMIN_GLPI_PASSWORD"
    USING 'XEPAU';

-- Depuis le site PAU → accès au site CERGY
-- (à exécuter sur l'instance de Pau)
-- CREATE DATABASE LINK DBL_CERGY
--     CONNECT TO admin_glpi IDENTIFIED BY "&&ADMIN_GLPI_PASSWORD"
--     USING 'XECERGY';

-- Test du lien :
-- SELECT * FROM computers@DBL_PAU WHERE ROWNUM <= 5;

-- =========================
-- 3. SYNONYMES
-- Accès transparent aux tables distantes
-- =========================

-- Synonymes pour accéder aux tables de Pau depuis Cergy
CREATE SYNONYM computers_pau FOR computers@DBL_PAU;
CREATE SYNONYM monitors_pau FOR monitors@DBL_PAU;
CREATE SYNONYM peripherals_pau FOR peripherals@DBL_PAU;
CREATE SYNONYM printers_pau FOR printers@DBL_PAU;
CREATE SYNONYM phones_pau FOR phones@DBL_PAU;
CREATE SYNONYM network_equipments_pau FOR network_equipments@DBL_PAU;
CREATE SYNONYM users_pau FOR users@DBL_PAU;
CREATE SYNONYM network_ports_pau FOR network_ports@DBL_PAU;
CREATE SYNONYM entities_pau FOR entities@DBL_PAU;
CREATE SYNONYM tickets_pau FOR tickets@DBL_PAU;
CREATE SYNONYM ticket_followups_pau FOR ticket_followups@DBL_PAU;
CREATE SYNONYM ticket_categories_pau FOR ticket_categories@DBL_PAU;

-- =========================
-- 4. FRAGMENTATION HORIZONTALE
-- Chaque site stocke ses propres matériels
-- =========================

-- Les données sont réparties selon le site_code de l'entité :
-- - Site CERGY : entities.site_code = 'CERGY' → stocké sur instance Cergy
-- - Site PAU   : entities.site_code = 'PAU'   → stocké sur instance Pau
--
-- L'insertion est guidee par la procedure SP_TRANSFERT_MATERIEL.
-- Pour un transfert inter-sites, elle copie l'ordinateur et ses ports
-- directs via DB link, puis supprime les lignes locales transferees.

-- =========================
-- 5. TABLES RÉPLIQUÉES (référentiels communs)
-- Les tables de référence sont identiques sur les deux sites
-- =========================

-- Procédure de réplication des référentiels
CREATE OR REPLACE PROCEDURE SP_REPLIQUER_REFERENTIELS
AS
BEGIN
    -- Réplication des fabricants
    MERGE INTO manufacturers@DBL_PAU dest
    USING manufacturers src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name,
                   dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, name, date_creation, date_mod)
        VALUES (src.id, src.name, src.date_creation, src.date_mod);

    -- Réplication des états
    MERGE INTO states@DBL_PAU dest
    USING states src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name,
                   dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, name, entities_id, date_creation, date_mod)
        VALUES (src.id, src.name, src.entities_id,
                src.date_creation, src.date_mod);

    -- Réplication des types d'assets
    MERGE INTO asset_types@DBL_PAU dest
    USING asset_types src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name,
                   dest.category = src.category,
                   dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, category, name, date_creation, date_mod)
        VALUES (src.id, src.category, src.name,
                src.date_creation, src.date_mod);

    -- Réplication des modèles d'assets
    MERGE INTO asset_models@DBL_PAU dest
    USING asset_models src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name,
                   dest.category = src.category,
                   dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, category, name, date_creation, date_mod)
        VALUES (src.id, src.category, src.name,
                src.date_creation, src.date_mod);

    -- Replication des categories de tickets
    MERGE INTO ticket_categories@DBL_PAU dest
    USING ticket_categories src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name,
                   dest.description = src.description,
                   dest.date_mod = src.date_mod
    WHEN NOT MATCHED THEN
        INSERT (id, name, description, date_creation, date_mod)
        VALUES (src.id, src.name, src.description,
                src.date_creation, src.date_mod);

    -- Réplication des réseaux
    MERGE INTO networks@DBL_PAU dest
    USING networks src ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET dest.name = src.name
    WHEN NOT MATCHED THEN
        INSERT (id, name) VALUES (src.id, src.name);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Réplication des référentiels terminée.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20040,
            'Erreur réplication: ' || SQLERRM);
END SP_REPLIQUER_REFERENTIELS;
/

-- =========================
-- 6. VUES DISTRIBUÉES
-- Requêtes fédérées sur les deux sites
-- =========================

-- Vue globale des ordinateurs (les deux sites)
CREATE OR REPLACE VIEW V_COMPUTERS_GLOBAL AS
SELECT c.*, 'CERGY' AS source_site
FROM computers c
    JOIN entities e ON c.entities_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT c.*, 'PAU' AS source_site
FROM computers@DBL_PAU c
    JOIN entities@DBL_PAU e ON c.entities_id = e.id
WHERE e.site_code = 'PAU';

-- Vue globale des utilisateurs
CREATE OR REPLACE VIEW V_USERS_GLOBAL AS
SELECT u.id, u.name, u.realname, u.firstname, u.email,
       e.name AS entite, 'CERGY' AS source_site
FROM users u JOIN entities e ON u.entities_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT u.id, u.name, u.realname, u.firstname, u.email,
       e.name AS entite, 'PAU' AS source_site
FROM users@DBL_PAU u
    JOIN entities@DBL_PAU e ON u.entities_id = e.id
WHERE e.site_code = 'PAU';

-- Vue globale des statistiques des deux sites
CREATE OR REPLACE VIEW V_STATS_GLOBAL AS
SELECT 'CERGY' AS site,
       FN_COMPTER_MATERIEL_SITE('CERGY') AS total_materiel
FROM DUAL
UNION ALL
SELECT 'PAU' AS site,
       (SELECT COUNT(*) FROM computers@DBL_PAU) +
       (SELECT COUNT(*) FROM monitors@DBL_PAU) +
       (SELECT COUNT(*) FROM printers@DBL_PAU) AS total_materiel
FROM DUAL;

-- Vue globale des tickets support
CREATE OR REPLACE VIEW V_TICKETS_GLOBAL AS
SELECT t.id, t.title, t.status, t.priority, t.requester_users_id,
       t.assigned_users_id, t.assigned_groups_id, t.date_creation,
       e.name AS entite, 'CERGY' AS source_site
FROM tickets t
    JOIN entities e ON t.entities_id = e.id
WHERE e.site_code = 'CERGY'
UNION ALL
SELECT t.id, t.title, t.status, t.priority, t.requester_users_id,
       t.assigned_users_id, t.assigned_groups_id, t.date_creation,
       e.name AS entite, 'PAU' AS source_site
FROM tickets@DBL_PAU t
    JOIN entities@DBL_PAU e ON t.entities_id = e.id
WHERE e.site_code = 'PAU';

-- =========================
-- 7. REQUÊTE DISTRIBUÉE EXEMPLE
-- Jointure entre données locales et distantes
-- =========================

-- Trouver tous les ordinateurs Dell sur les deux sites
-- SELECT * FROM V_COMPUTERS_GLOBAL cg
--     JOIN manufacturers m ON cg.manufacturers_id = m.id
-- WHERE m.name = 'Dell';
