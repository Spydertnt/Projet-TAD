-- ============================================================
-- 08_query_plans.sql
-- Analyse des plans d'execution - Schema simplifie
-- Oracle XE
-- ============================================================

SET LINESIZE 180
SET PAGESIZE 80

-- Q1 : recherche d'un materiel par nom, index fonctionnel idx_assets_name_upper.
EXPLAIN PLAN FOR
SELECT a.id, a.name, a.serial_number, e.site_code
FROM assets a
    JOIN sites e ON a.site_id = e.id
WHERE UPPER(a.name) LIKE 'PC-CERGY%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q2 : inventaire d'un site par type, index composite idx_assets_site_type.
EXPLAIN PLAN FOR
SELECT e.site_code, a.asset_type, COUNT(*) AS nb_assets
FROM assets a
    JOIN sites e ON a.site_id = e.id
WHERE e.site_code = 'CERGY'
GROUP BY e.site_code, a.asset_type;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q3 : tickets ouverts par site et priorite, index idx_ticket_site_status_priority.
EXPLAIN PLAN FOR
SELECT e.site_code, t.status, t.priority, COUNT(*) AS nb_tickets
FROM tickets t
    JOIN sites e ON t.site_id = e.id
WHERE t.status IN ('NOUVEAU', 'ASSIGNE', 'EN_COURS')
GROUP BY e.site_code, t.status, t.priority;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q4 : recherche d'un numero de serie, index fonctionnel idx_assets_serial_upper.
EXPLAIN PLAN FOR
SELECT a.id, a.name, a.serial_number
FROM assets a
WHERE UPPER(a.serial_number) = 'SN-2026-CERGY-00001';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q5 : reseau des appareils, index sur asset_id, network_port_id et ip_network_id.
EXPLAIN PLAN FOR
SELECT a.name, np.port_name, np.mac_address, ipn.network_name, ipn.vlan_tag, ia.ip_address
FROM assets a
    JOIN network_ports np ON np.asset_id = a.id
    LEFT JOIN ip_addresses ia ON ia.network_port_id = np.id
    LEFT JOIN ip_networks ipn ON ia.ip_network_id = ipn.id
WHERE a.asset_type = 'NETWORK_EQUIPMENT';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q6 : utilisateurs et profils.
EXPLAIN PLAN FOR
SELECT u.login, p.name AS profil, e.site_code
FROM users u
    JOIN profiles_users pu ON pu.user_id = u.id
    JOIN profiles p ON p.id = pu.profile_id
    JOIN sites e ON e.id = pu.site_id
WHERE u.is_active = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
