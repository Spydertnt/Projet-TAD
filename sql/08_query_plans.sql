-- ============================================================
-- 08_query_plans.sql
-- Analyse des plans d'execution - Schema simplifie
-- Oracle XE
-- ============================================================

SET LINESIZE 180
SET PAGESIZE 80

-- Q1 : recherche d'un materiel par nom, index fonctionnel idx_assets_name_upper.
EXPLAIN PLAN FOR
SELECT a.id, a.name, a.serial, e.site_code
FROM assets a
    JOIN entities e ON a.entities_id = e.id
WHERE UPPER(a.name) LIKE 'PC-CERGY%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q2 : inventaire d'un site par type, index composite idx_assets_entity_category.
EXPLAIN PLAN FOR
SELECT e.site_code, a.category, COUNT(*) AS nb_assets
FROM assets a
    JOIN entities e ON a.entities_id = e.id
WHERE e.site_code = 'CERGY'
GROUP BY e.site_code, a.category;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q3 : tickets ouverts par site et priorite, index idx_ticket_entity_status_priority.
EXPLAIN PLAN FOR
SELECT e.site_code, t.status, t.priority, COUNT(*) AS nb_tickets
FROM tickets t
    JOIN entities e ON t.entities_id = e.id
WHERE t.status IN ('NOUVEAU', 'ASSIGNE', 'EN_COURS')
GROUP BY e.site_code, t.status, t.priority;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q4 : recherche d'un numero de serie, index fonctionnel idx_assets_serial_upper.
EXPLAIN PLAN FOR
SELECT a.id, a.name, a.serial
FROM assets a
WHERE UPPER(a.serial) = 'SN-2026-CERGY-00001';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q5 : topologie reseau, index sur assets_id et network_ports_id.
EXPLAIN PLAN FOR
SELECT a.name, np.name AS port_name, np.mac, v.name AS vlan_name, ia.address
FROM assets a
    JOIN network_ports np ON np.assets_id = a.id
    LEFT JOIN network_port_vlans npv ON npv.network_ports_id = np.id
    LEFT JOIN vlans v ON npv.vlans_id = v.id
    LEFT JOIN ip_addresses ia ON ia.network_ports_id = np.id
WHERE a.category = 'NETWORK_EQUIPMENT';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Q6 : utilisateurs et profils.
EXPLAIN PLAN FOR
SELECT u.login, p.name AS profil, e.site_code
FROM users u
    JOIN profiles_users pu ON pu.users_id = u.id
    JOIN profiles p ON p.id = pu.profiles_id
    JOIN entities e ON e.id = pu.entities_id
WHERE u.is_active = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
