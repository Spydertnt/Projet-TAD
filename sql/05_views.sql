-- ============================================================
-- 05_views.sql
-- Vues metier - Schema simplifie
-- Oracle XE
-- ============================================================

SET SQLBLANKLINES ON

-- Inventaire unifie : une ligne = un materiel.
CREATE OR REPLACE VIEW V_INVENTAIRE_COMPLET AS
SELECT
    a.id,
    a.site_id,
    a.asset_type AS type_materiel,
    a.name AS nom_materiel,
    a.serial_number AS numero_serie,
    e.name AS entite,
    e.site_code AS site,
    l.full_name AS localisation,
    u.last_name || ' ' || u.first_name AS proprietaire,
    ut.last_name || ' ' || ut.first_name AS technicien,
    m.name AS fabricant,
    s.name AS etat,
    a.created_at,
    a.updated_at
FROM assets a
    JOIN sites e ON a.site_id = e.id
    LEFT JOIN locations l ON a.location_id = l.id
    LEFT JOIN users u ON a.owner_user_id = u.id
    LEFT JOIN users ut ON a.technician_user_id = ut.id
    LEFT JOIN manufacturers m ON a.manufacturer_id = m.id
    LEFT JOIN states s ON a.state_id = s.id;

CREATE OR REPLACE VIEW V_MATERIEL_PAR_SITE AS
SELECT
    site_id,
    site,
    entite,
    type_materiel,
    COUNT(*) AS nombre
FROM V_INVENTAIRE_COMPLET
GROUP BY site_id, site, entite, type_materiel;

CREATE OR REPLACE VIEW V_UTILISATEURS_PROFILS AS
SELECT
    u.id AS user_id,
    u.login,
    u.last_name || ' ' || u.first_name AS nom_complet,
    u.email,
    e_user.name AS entite_rattachement,
    e_user.site_code AS site,
    p.name AS profil,
    e_profil.name AS entite_profil,
    pu.is_recursive,
    u.is_active
FROM users u
    JOIN sites e_user ON u.site_id = e_user.id
    LEFT JOIN profiles_users pu ON u.id = pu.user_id
    LEFT JOIN profiles p ON pu.profile_id = p.id
    LEFT JOIN sites e_profil ON pu.site_id = e_profil.id;

CREATE OR REPLACE VIEW V_TOPOLOGIE_RESEAU AS
SELECT
    np.id AS port_id,
    np.port_name AS nom_port,
    np.mac_address,
    np.port_type,
    a.id AS asset_id,
    a.name AS equipement,
    a.asset_type AS type_equipement,
    e.name AS entite,
    e.site_code AS site,
    ipn.network_name AS reseau_ip,
    ipn.network_address AS adresse_reseau,
    ipn.subnet_mask,
    ipn.gateway_address,
    ipn.vlan_name,
    ipn.vlan_tag,
    ia.ip_address AS adresse_ip
FROM network_ports np
    JOIN assets a ON np.asset_id = a.id
    JOIN sites e ON np.site_id = e.id
    LEFT JOIN ip_addresses ia ON ia.network_port_id = np.id
    LEFT JOIN ip_networks ipn ON ia.ip_network_id = ipn.id;

CREATE OR REPLACE VIEW V_STATISTIQUES_SITE AS
SELECT
    e.site_code AS site,
    e.name AS entite,
    (SELECT COUNT(*) FROM assets a WHERE a.site_id = e.id) AS nb_assets,
    (SELECT COUNT(*) FROM assets a WHERE a.site_id = e.id AND a.asset_type = 'COMPUTER') AS nb_computers,
    (SELECT COUNT(*) FROM assets a WHERE a.site_id = e.id AND a.asset_type = 'PRINTER') AS nb_printers,
    (SELECT COUNT(*) FROM assets a WHERE a.site_id = e.id AND a.asset_type = 'NETWORK_EQUIPMENT') AS nb_network_equip,
    (SELECT COUNT(*) FROM users u WHERE u.site_id = e.id) AS nb_users,
    (SELECT COUNT(*) FROM network_ports np WHERE np.site_id = e.id) AS nb_ports,
    (SELECT COUNT(*) FROM tickets t WHERE t.site_id = e.id) AS nb_tickets
FROM sites e
WHERE e.site_code IS NOT NULL;

CREATE OR REPLACE VIEW V_MATERIEL_RECENT AS
SELECT *
FROM V_INVENTAIRE_COMPLET
WHERE updated_at >= SYSTIMESTAMP - INTERVAL '30' DAY;

CREATE OR REPLACE VIEW V_TICKETS_SUPPORT AS
SELECT
    t.id AS ticket_id,
    t.title AS titre,
    t.status AS statut,
    t.priority AS priorite,
    tc.name AS categorie,
    e.name AS entite,
    e.site_code AS site,
    req.last_name || ' ' || req.first_name AS demandeur,
    (
        SELECT LISTAGG(tech.last_name || ' ' || tech.first_name, ', ')
               WITHIN GROUP (ORDER BY tech.last_name, tech.first_name)
        FROM ticket_users tu
            JOIN users tech ON tu.user_id = tech.id
        WHERE tu.ticket_id = t.id
    ) AS techniciens,
    g.name AS groupe_it,
    a.asset_type AS type_materiel,
    a.name AS nom_materiel,
    a.serial_number AS numero_serie,
    t.created_at,
    t.updated_at,
    t.assigned_at,
    t.resolved_at,
    t.closed_at
FROM tickets t
    JOIN sites e ON t.site_id = e.id
    JOIN assets a ON t.asset_id = a.id
    JOIN users req ON t.requester_user_id = req.id
    LEFT JOIN groups g ON t.assigned_group_id = g.id
    LEFT JOIN ticket_categories tc ON t.category_id = tc.id;
