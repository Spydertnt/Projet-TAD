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
    a.entities_id,
    a.category AS type_materiel,
    a.name AS nom_materiel,
    a.serial AS numero_serie,
    a.inventory_tag,
    e.name AS entite,
    e.site_code AS site,
    l.completename AS localisation,
    u.realname || ' ' || u.firstname AS proprietaire,
    ut.realname || ' ' || ut.firstname AS technicien,
    m.name AS fabricant,
    s.name AS etat,
    am.name AS modele,
    n.name AS reseau,
    a.date_creation,
    a.date_mod
FROM assets a
    JOIN entities e ON a.entities_id = e.id
    LEFT JOIN locations l ON a.locations_id = l.id
    LEFT JOIN users u ON a.users_id = u.id
    LEFT JOIN users ut ON a.users_id_tech = ut.id
    LEFT JOIN manufacturers m ON a.manufacturers_id = m.id
    LEFT JOIN states s ON a.states_id = s.id
    LEFT JOIN asset_models am ON a.asset_models_id = am.id
    LEFT JOIN networks n ON a.networks_id = n.id;

CREATE OR REPLACE VIEW V_MATERIEL_PAR_SITE AS
SELECT
    entities_id,
    site,
    entite,
    type_materiel,
    COUNT(*) AS nombre
FROM V_INVENTAIRE_COMPLET
GROUP BY entities_id, site, entite, type_materiel;

CREATE OR REPLACE VIEW V_UTILISATEURS_PROFILS AS
SELECT
    u.id AS user_id,
    u.login,
    u.realname || ' ' || u.firstname AS nom_complet,
    u.email,
    e_user.name AS entite_rattachement,
    e_user.site_code AS site,
    p.name AS profil,
    e_profil.name AS entite_profil,
    pu.is_recursive,
    u.is_active
FROM users u
    JOIN entities e_user ON u.entities_id = e_user.id
    LEFT JOIN profiles_users pu ON u.id = pu.users_id
    LEFT JOIN profiles p ON pu.profiles_id = p.id
    LEFT JOIN entities e_profil ON pu.entities_id = e_profil.id;

CREATE OR REPLACE VIEW V_TOPOLOGIE_RESEAU AS
SELECT
    np.id AS port_id,
    np.name AS nom_port,
    np.mac,
    np.port_type,
    a.id AS assets_id,
    a.name AS equipement,
    a.category AS type_equipement,
    e.name AS entite,
    e.site_code AS site,
    v.name AS vlan_name,
    v.tag AS vlan_tag,
    ia.address AS adresse_ip
FROM network_ports np
    JOIN assets a ON np.assets_id = a.id
    JOIN entities e ON np.entities_id = e.id
    LEFT JOIN network_port_vlans npv ON np.id = npv.network_ports_id
    LEFT JOIN vlans v ON npv.vlans_id = v.id
    LEFT JOIN ip_addresses ia ON ia.network_ports_id = np.id;

CREATE OR REPLACE VIEW V_STATISTIQUES_SITE AS
SELECT
    e.site_code AS site,
    e.name AS entite,
    (SELECT COUNT(*) FROM assets a WHERE a.entities_id = e.id) AS nb_assets,
    (SELECT COUNT(*) FROM assets a WHERE a.entities_id = e.id AND a.category = 'COMPUTER') AS nb_computers,
    (SELECT COUNT(*) FROM assets a WHERE a.entities_id = e.id AND a.category = 'PRINTER') AS nb_printers,
    (SELECT COUNT(*) FROM assets a WHERE a.entities_id = e.id AND a.category = 'NETWORK_EQUIPMENT') AS nb_network_equip,
    (SELECT COUNT(*) FROM users u WHERE u.entities_id = e.id) AS nb_users,
    (SELECT COUNT(*) FROM network_ports np WHERE np.entities_id = e.id) AS nb_ports,
    (SELECT COUNT(*) FROM tickets t WHERE t.entities_id = e.id) AS nb_tickets
FROM entities e
WHERE e.site_code IS NOT NULL;

CREATE OR REPLACE VIEW V_MATERIEL_RECENT AS
SELECT *
FROM V_INVENTAIRE_COMPLET
WHERE date_mod >= SYSTIMESTAMP - INTERVAL '30' DAY;

CREATE OR REPLACE VIEW V_TICKETS_SUPPORT AS
SELECT
    t.id AS ticket_id,
    t.title AS titre,
    t.status AS statut,
    t.priority AS priorite,
    t.urgency AS urgence,
    t.impact,
    tc.name AS categorie,
    e.name AS entite,
    e.site_code AS site,
    req.realname || ' ' || req.firstname AS demandeur,
    (
        SELECT LISTAGG(tech.realname || ' ' || tech.firstname, ', ')
               WITHIN GROUP (ORDER BY tech.realname, tech.firstname)
        FROM ticket_users tu
            JOIN users tech ON tu.users_id = tech.id
        WHERE tu.tickets_id = t.id
    ) AS techniciens,
    g.name AS groupe_it,
    a.category AS type_materiel,
    a.name AS nom_materiel,
    a.serial AS numero_serie,
    t.date_creation,
    t.date_mod,
    t.date_assigned,
    t.date_resolved,
    t.date_closed
FROM tickets t
    JOIN entities e ON t.entities_id = e.id
    JOIN assets a ON t.assets_id = a.id
    JOIN users req ON t.requester_users_id = req.id
    LEFT JOIN groups g ON t.assigned_groups_id = g.id
    LEFT JOIN ticket_categories tc ON t.ticket_categories_id = tc.id;
