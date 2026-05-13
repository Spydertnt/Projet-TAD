-- ============================================================
-- 05_views.sql
-- Vues métier — Accès simplifié aux données complexes
-- Oracle XE
-- ============================================================

SET SQLBLANKLINES ON

-- =========================
-- V_INVENTAIRE_COMPLET
-- Vue consolidée de tous les matériels avec infos associées
-- =========================

CREATE OR REPLACE VIEW V_INVENTAIRE_COMPLET AS
SELECT
    'COMPUTER' AS type_materiel,
    c.id,
    c.entities_id,
    c.name AS nom_materiel,
    c.serial AS numero_serie,
    e.name AS entite,
    e.site_code AS site,
    l.completename AS localisation,
    u.realname || ' ' || u.firstname AS proprietaire,
    ut.realname || ' ' || ut.firstname AS technicien,
    m.name AS fabricant,
    s.name AS etat,
    at.name AS type_asset,
    am.name AS modele,
    c.date_creation,
    c.date_mod
FROM computers c
    LEFT JOIN entities e ON c.entities_id = e.id
    LEFT JOIN locations l ON c.locations_id = l.id
    LEFT JOIN users u ON c.users_id = u.id
    LEFT JOIN users ut ON c.users_id_tech = ut.id
    LEFT JOIN manufacturers m ON c.manufacturers_id = m.id
    LEFT JOIN states s ON c.states_id = s.id
    LEFT JOIN asset_types at ON c.asset_types_id = at.id
    LEFT JOIN asset_models am ON c.asset_models_id = am.id

UNION ALL

SELECT
    'MONITOR', mo.id, mo.entities_id, mo.name, mo.serial,
    e.name, e.site_code,
    l.completename,
    u.realname || ' ' || u.firstname, NULL,
    m.name, s.name, at.name, am.name,
    mo.date_creation, mo.date_mod
FROM monitors mo
    LEFT JOIN entities e ON mo.entities_id = e.id
    LEFT JOIN locations l ON mo.locations_id = l.id
    LEFT JOIN users u ON mo.users_id = u.id
    LEFT JOIN manufacturers m ON mo.manufacturers_id = m.id
    LEFT JOIN states s ON mo.states_id = s.id
    LEFT JOIN asset_types at ON mo.asset_types_id = at.id
    LEFT JOIN asset_models am ON mo.asset_models_id = am.id

UNION ALL

SELECT
    'PERIPHERAL', p.id, p.entities_id, p.name, p.serial,
    e.name, e.site_code,
    l.completename,
    u.realname || ' ' || u.firstname, NULL,
    m.name, s.name, at.name, NULL,
    p.date_creation, p.date_mod
FROM peripherals p
    LEFT JOIN entities e ON p.entities_id = e.id
    LEFT JOIN locations l ON p.locations_id = l.id
    LEFT JOIN users u ON p.users_id = u.id
    LEFT JOIN manufacturers m ON p.manufacturers_id = m.id
    LEFT JOIN states s ON p.states_id = s.id
    LEFT JOIN asset_types at ON p.asset_types_id = at.id

UNION ALL

SELECT
    'PRINTER', pr.id, pr.entities_id, pr.name, pr.serial,
    e.name, e.site_code,
    l.completename,
    u.realname || ' ' || u.firstname, NULL,
    m.name, s.name, at.name, NULL,
    pr.date_creation, pr.date_mod
FROM printers pr
    LEFT JOIN entities e ON pr.entities_id = e.id
    LEFT JOIN locations l ON pr.locations_id = l.id
    LEFT JOIN users u ON pr.users_id = u.id
    LEFT JOIN manufacturers m ON pr.manufacturers_id = m.id
    LEFT JOIN states s ON pr.states_id = s.id
    LEFT JOIN asset_types at ON pr.asset_types_id = at.id

UNION ALL

SELECT
    'PHONE', ph.id, ph.entities_id, ph.name, ph.serial,
    e.name, e.site_code,
    l.completename,
    u.realname || ' ' || u.firstname, NULL,
    m.name, s.name, at.name, NULL,
    ph.date_creation, ph.date_mod
FROM phones ph
    LEFT JOIN entities e ON ph.entities_id = e.id
    LEFT JOIN locations l ON ph.locations_id = l.id
    LEFT JOIN users u ON ph.users_id = u.id
    LEFT JOIN manufacturers m ON ph.manufacturers_id = m.id
    LEFT JOIN states s ON ph.states_id = s.id
    LEFT JOIN asset_types at ON ph.asset_types_id = at.id

UNION ALL

SELECT
    'NETWORK_EQUIPMENT', ne.id, ne.entities_id, ne.name, ne.serial,
    e.name, e.site_code,
    l.completename,
    u.realname || ' ' || u.firstname, NULL,
    m.name, s.name, at.name, am.name,
    ne.date_creation, ne.date_mod
FROM network_equipments ne
    LEFT JOIN entities e ON ne.entities_id = e.id
    LEFT JOIN locations l ON ne.locations_id = l.id
    LEFT JOIN users u ON ne.users_id = u.id
    LEFT JOIN manufacturers m ON ne.manufacturers_id = m.id
    LEFT JOIN states s ON ne.states_id = s.id
    LEFT JOIN asset_types at ON ne.asset_types_id = at.id
    LEFT JOIN asset_models am ON ne.asset_models_id = am.id;

-- =========================
-- V_MATERIEL_PAR_SITE
-- Matériels filtrés par site avec compteurs
-- =========================

CREATE OR REPLACE VIEW V_MATERIEL_PAR_SITE AS
SELECT
    entities_id,
    site,
    entite,
    type_materiel,
    COUNT(*) AS nombre
FROM V_INVENTAIRE_COMPLET v
GROUP BY entities_id, site, entite, type_materiel
ORDER BY site, type_materiel;

-- =========================
-- V_UTILISATEURS_PROFILS
-- Utilisateurs avec leurs profils et droits agrégés
-- =========================

CREATE OR REPLACE VIEW V_UTILISATEURS_PROFILS AS
SELECT
    u.id AS user_id,
    u.name AS login,
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
    LEFT JOIN entities e_profil ON pu.entities_id = e_profil.id
ORDER BY u.realname, u.firstname;

-- =========================
-- V_TOPOLOGIE_RESEAU
-- Ports réseau avec connexions, VLANs et adresses IP
-- =========================

CREATE OR REPLACE VIEW V_TOPOLOGIE_RESEAU AS
SELECT
    np.id AS port_id,
    np.name AS nom_port,
    np.mac,
    np.instantiation_type AS type_port,
    COALESCE(
        c.name, mo.name, pe.name,
        pr.name, ph.name, ne.name
    ) AS equipement,
    CASE
        WHEN np.computers_id IS NOT NULL THEN 'COMPUTER'
        WHEN np.monitors_id IS NOT NULL THEN 'MONITOR'
        WHEN np.peripherals_id IS NOT NULL THEN 'PERIPHERAL'
        WHEN np.printers_id IS NOT NULL THEN 'PRINTER'
        WHEN np.phones_id IS NOT NULL THEN 'PHONE'
        WHEN np.network_equipments_id IS NOT NULL THEN 'NETWORK_EQUIPMENT'
    END AS type_equipement,
    e.name AS entite,
    e.site_code AS site,
    v.name AS vlan_name,
    v.tag AS vlan_tag,
    nn.name AS nom_dns,
    ia.name AS adresse_ip
FROM network_ports np
    JOIN entities e ON np.entities_id = e.id
    LEFT JOIN computers c ON np.computers_id = c.id
    LEFT JOIN monitors mo ON np.monitors_id = mo.id
    LEFT JOIN peripherals pe ON np.peripherals_id = pe.id
    LEFT JOIN printers pr ON np.printers_id = pr.id
    LEFT JOIN phones ph ON np.phones_id = ph.id
    LEFT JOIN network_equipments ne ON np.network_equipments_id = ne.id
    LEFT JOIN network_port_vlans npv ON np.id = npv.network_ports_id
    LEFT JOIN vlans v ON npv.vlans_id = v.id
    LEFT JOIN network_names nn ON nn.network_ports_id = np.id
    LEFT JOIN ip_addresses ia ON ia.network_names_id = nn.id;

-- =========================
-- V_STATISTIQUES_SITE
-- Compteurs et statistiques par site/entité
-- =========================

CREATE OR REPLACE VIEW V_STATISTIQUES_SITE AS
SELECT
    e.site_code AS site,
    e.name AS entite,
    (SELECT COUNT(*) FROM computers WHERE entities_id = e.id) AS nb_computers,
    (SELECT COUNT(*) FROM monitors WHERE entities_id = e.id) AS nb_monitors,
    (SELECT COUNT(*) FROM peripherals WHERE entities_id = e.id) AS nb_peripherals,
    (SELECT COUNT(*) FROM printers WHERE entities_id = e.id) AS nb_printers,
    (SELECT COUNT(*) FROM phones WHERE entities_id = e.id) AS nb_phones,
    (SELECT COUNT(*) FROM network_equipments WHERE entities_id = e.id) AS nb_network_equip,
    (SELECT COUNT(*) FROM users WHERE entities_id = e.id) AS nb_users,
    (SELECT COUNT(*) FROM network_ports WHERE entities_id = e.id) AS nb_ports
FROM entities e
WHERE e.site_code IS NOT NULL
ORDER BY e.site_code, e.name;

-- =========================
-- V_MATERIEL_RECENT
-- Matériels ajoutés ou modifiés dans les 30 derniers jours
-- =========================

CREATE OR REPLACE VIEW V_MATERIEL_RECENT AS
SELECT *
FROM V_INVENTAIRE_COMPLET
WHERE date_mod >= SYSTIMESTAMP - INTERVAL '30' DAY
ORDER BY date_mod DESC;

-- =========================
-- V_TICKETS_SUPPORT
-- Suivi des tickets envoyes au service IT
-- =========================

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
    CASE
        WHEN t.computers_id IS NOT NULL THEN 'COMPUTER'
        WHEN t.monitors_id IS NOT NULL THEN 'MONITOR'
        WHEN t.peripherals_id IS NOT NULL THEN 'PERIPHERAL'
        WHEN t.printers_id IS NOT NULL THEN 'PRINTER'
        WHEN t.phones_id IS NOT NULL THEN 'PHONE'
        WHEN t.network_equipments_id IS NOT NULL THEN 'NETWORK_EQUIPMENT'
    END AS type_materiel,
    COALESCE(c.name, mo.name, p.name, pr.name, ph.name, ne.name) AS nom_materiel,
    COALESCE(c.serial, mo.serial, p.serial, pr.serial, ph.serial, ne.serial) AS numero_serie,
    t.date_creation,
    t.date_mod,
    t.date_assigned,
    t.date_resolved,
    t.date_closed
FROM tickets t
    JOIN entities e ON t.entities_id = e.id
    JOIN users req ON t.requester_users_id = req.id
    LEFT JOIN groups g ON t.assigned_groups_id = g.id
    LEFT JOIN ticket_categories tc ON t.ticket_categories_id = tc.id
    LEFT JOIN computers c ON t.computers_id = c.id
    LEFT JOIN monitors mo ON t.monitors_id = mo.id
    LEFT JOIN peripherals p ON t.peripherals_id = p.id
    LEFT JOIN printers pr ON t.printers_id = pr.id
    LEFT JOIN phones ph ON t.phones_id = ph.id
    LEFT JOIN network_equipments ne ON t.network_equipments_id = ne.id;
