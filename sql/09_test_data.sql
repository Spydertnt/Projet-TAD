-- ============================================================
-- 09_test_data.sql
-- Jeu de test simplifie et coherent avec la table assets
-- Oracle XE
-- ============================================================

SET SERVEROUTPUT ON

CREATE OR REPLACE PROCEDURE SP_GENERER_JEU_DE_TEST (
    p_assets_cergy IN NUMBER DEFAULT 300,
    p_assets_pau   IN NUMBER DEFAULT 200
)
AS
    v_cergy_id NUMBER;
    v_pau_id NUMBER;
    v_loc_cergy_id NUMBER;
    v_loc_pau_id NUMBER;
    v_group_cergy_id NUMBER;
    v_group_pau_id NUMBER;
    v_profile_tech_id NUMBER;
    v_profile_user_id NUMBER;
    v_user_id NUMBER;
    v_asset_id NUMBER;
    v_port_id NUMBER;
    v_ip_network_id NUMBER;
    v_manuf_id NUMBER;
    v_state_id NUMBER;
    v_asset_type VARCHAR2(50);
    v_site VARCHAR2(10);
    v_site_id NUMBER;
    v_location_id NUMBER;
    v_group_id NUMBER;
    v_limit NUMBER;
BEGIN
    -- Nettoyage permettant de relancer la procedure.
    DELETE FROM ticket_followups;
    DELETE FROM ticket_users;
    DELETE FROM tickets;
    DELETE FROM ip_addresses;
    DELETE FROM network_ports;
    DELETE FROM ip_networks;
    DELETE FROM groups_users;
    DELETE FROM profiles_users;
    DELETE FROM assets;
    DELETE FROM users;
    DELETE FROM groups;
    DELETE FROM locations;
    DELETE FROM sites;
    DELETE FROM ticket_categories;
    DELETE FROM manufacturers;
    DELETE FROM states;
    DELETE FROM audit_log;
    DELETE FROM archives_materiel;
    COMMIT;

    INSERT INTO sites (name, site_code, full_name)
    VALUES ('CY Tech Cergy', 'CERGY', 'CY Tech Cergy')
    RETURNING id INTO v_cergy_id;

    INSERT INTO sites (name, site_code, full_name)
    VALUES ('CY Tech Pau', 'PAU', 'CY Tech Pau')
    RETURNING id INTO v_pau_id;

    INSERT INTO locations (site_id, name, full_name, building, room)
    VALUES (v_cergy_id, 'Batiment A', 'CY Tech Cergy > Batiment A', 'A', 'Open Space')
    RETURNING id INTO v_loc_cergy_id;

    INSERT INTO locations (site_id, name, full_name, building, room)
    VALUES (v_pau_id, 'Batiment B', 'CY Tech Pau > Batiment B', 'B', 'Open Space')
    RETURNING id INTO v_loc_pau_id;

    INSERT INTO manufacturers (name) VALUES ('Dell');
    INSERT INTO manufacturers (name) VALUES ('HP');
    INSERT INTO manufacturers (name) VALUES ('Lenovo');
    INSERT INTO manufacturers (name) VALUES ('Cisco');
    INSERT INTO manufacturers (name) VALUES ('Epson');

    INSERT INTO states (name) VALUES ('En service');
    INSERT INTO states (name) VALUES ('En stock');
    INSERT INTO states (name) VALUES ('En maintenance');
    INSERT INTO states (name) VALUES ('Hors service');

    INSERT INTO profiles (name, interface, is_default) VALUES ('Technicien', 'central', 0)
    RETURNING id INTO v_profile_tech_id;
    INSERT INTO profiles (name, interface, is_default) VALUES ('Utilisateur', 'helpdesk', 1)
    RETURNING id INTO v_profile_user_id;

    INSERT INTO ticket_categories (name, description) VALUES ('Incident materiel', 'Panne ou degradation d''un equipement');
    INSERT INTO ticket_categories (name, description) VALUES ('Demande reseau', 'Demande liee aux ports, IP ou sous-reseaux');
    INSERT INTO ticket_categories (name, description) VALUES ('Installation', 'Installation ou renouvellement de materiel');

    INSERT INTO groups (site_id, name, full_name)
    VALUES (v_cergy_id, 'Support IT Cergy', 'CY Tech Cergy > Support IT')
    RETURNING id INTO v_group_cergy_id;

    INSERT INTO groups (site_id, name, full_name)
    VALUES (v_pau_id, 'Support IT Pau', 'CY Tech Pau > Support IT')
    RETURNING id INTO v_group_pau_id;

    FOR i IN 1..120 LOOP
        IF i <= 70 THEN
            v_site := 'CERGY';
            v_site_id := v_cergy_id;
            v_location_id := v_loc_cergy_id;
            v_group_id := v_group_cergy_id;
        ELSE
            v_site := 'PAU';
            v_site_id := v_pau_id;
            v_location_id := v_loc_pau_id;
            v_group_id := v_group_pau_id;
        END IF;

        INSERT INTO users (login, last_name, first_name, email, site_id, location_id)
        VALUES (
            LOWER('user_' || v_site || '_' || LPAD(i, 3, '0')),
            'Nom' || i,
            'Prenom' || i,
            LOWER('user_' || v_site || '_' || LPAD(i, 3, '0') || '@cy-tech.fr'),
            v_site_id,
            v_location_id
        )
        RETURNING id INTO v_user_id;

        INSERT INTO profiles_users (user_id, profile_id, site_id, is_recursive)
        VALUES (v_user_id, CASE WHEN MOD(i, 10) = 0 THEN v_profile_tech_id ELSE v_profile_user_id END, v_site_id, 0);

        IF MOD(i, 10) = 0 THEN
            INSERT INTO groups_users (user_id, group_id, is_manager)
            VALUES (v_user_id, v_group_id, CASE WHEN MOD(i, 30) = 0 THEN 1 ELSE 0 END);
        END IF;
    END LOOP;

    FOR site_idx IN 1..2 LOOP
        IF site_idx = 1 THEN
            v_site := 'CERGY';
            v_site_id := v_cergy_id;
            v_location_id := v_loc_cergy_id;
            v_group_id := v_group_cergy_id;
            v_limit := p_assets_cergy;
        ELSE
            v_site := 'PAU';
            v_site_id := v_pau_id;
            v_location_id := v_loc_pau_id;
            v_group_id := v_group_pau_id;
            v_limit := p_assets_pau;
        END IF;

        INSERT INTO ip_networks (site_id, network_name, network_address, subnet_mask, gateway_address, vlan_name, vlan_tag)
        VALUES (
            v_site_id,
            'LAN ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN '10.10.0.0' ELSE '10.20.0.0' END,
            '255.255.0.0',
            CASE WHEN v_site = 'CERGY' THEN '10.10.0.1' ELSE '10.20.0.1' END,
            'VLAN Users ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN 10 ELSE 20 END
        )
        RETURNING id INTO v_ip_network_id;

        FOR i IN 1..v_limit LOOP
            CASE MOD(i, 6)
                WHEN 0 THEN v_asset_type := 'NETWORK_EQUIPMENT';
                WHEN 1 THEN v_asset_type := 'COMPUTER';
                WHEN 2 THEN v_asset_type := 'MONITOR';
                WHEN 3 THEN v_asset_type := 'PRINTER';
                WHEN 4 THEN v_asset_type := 'PHONE';
                ELSE v_asset_type := 'PERIPHERAL';
            END CASE;

            SELECT id INTO v_manuf_id FROM manufacturers WHERE name =
                CASE
                    WHEN v_asset_type = 'NETWORK_EQUIPMENT' THEN 'Cisco'
                    WHEN v_asset_type = 'PRINTER' THEN 'Epson'
                    WHEN MOD(i, 2) = 0 THEN 'Dell'
                    ELSE 'Lenovo'
                END;
            SELECT id INTO v_state_id FROM states WHERE name =
                CASE WHEN MOD(i, 17) = 0 THEN 'En maintenance' ELSE 'En service' END;
            SELECT MIN(id) INTO v_user_id
            FROM users
            WHERE site_id = v_site_id;

            INSERT INTO assets (
                site_id, asset_type, name, serial_number,
                owner_user_id, location_id, manufacturer_id,
                state_id
            )
            VALUES (
                v_site_id,
                v_asset_type,
                SUBSTR(v_asset_type, 1, 3) || '-' || v_site || '-' || LPAD(i, 5, '0'),
                'SN-2026-' || v_site || '-' || LPAD(i, 5, '0'),
                CASE WHEN v_asset_type IN ('COMPUTER','PHONE','PERIPHERAL') THEN v_user_id END,
                v_location_id,
                v_manuf_id,
                v_state_id
            )
            RETURNING id INTO v_asset_id;

            IF v_asset_type IN ('COMPUTER','PRINTER','NETWORK_EQUIPMENT') THEN
                INSERT INTO network_ports (site_id, asset_id, port_name, mac_address, port_type)
                VALUES (
                    v_site_id,
                    v_asset_id,
                    'eth0',
                    '02:' || LPAD(MOD(i, 255), 2, '0') || ':AA:' || LPAD(MOD(i * 3, 255), 2, '0') ||
                    ':BB:' || LPAD(MOD(i * 7, 255), 2, '0'),
                    'Ethernet'
                )
                RETURNING id INTO v_port_id;

                INSERT INTO ip_addresses (site_id, network_port_id, ip_network_id, ip_address)
                VALUES (
                    v_site_id,
                    v_port_id,
                    v_ip_network_id,
                    CASE WHEN v_site = 'CERGY' THEN '10.10.' ELSE '10.20.' END ||
                    TO_CHAR(TRUNC(i / 250)) || '.' || TO_CHAR(MOD(i, 250) + 1)
                );
            END IF;

            IF MOD(i, 25) = 0 THEN
                INSERT INTO tickets (
                    site_id, asset_id, title, description, status, priority,
                    requester_user_id, assigned_group_id, category_id
                )
                VALUES (
                    v_site_id,
                    v_asset_id,
                    'Incident sur ' || v_asset_type || ' #' || i,
                    'Ticket genere automatiquement pour les tests.',
                    CASE WHEN MOD(i, 50) = 0 THEN 'RESOLU' ELSE 'NOUVEAU' END,
                    CASE WHEN MOD(i, 75) = 0 THEN 'HAUTE' ELSE 'MOYENNE' END,
                    v_user_id,
                    v_group_id,
                    1
                );
            END IF;
        END LOOP;
    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Jeu de test genere.');
    DBMS_OUTPUT.PUT_LINE('Assets: ' || (p_assets_cergy + p_assets_pau));
    DBMS_OUTPUT.PUT_LINE('Utilisateurs: 120');
END SP_GENERER_JEU_DE_TEST;
/

BEGIN
    SP_GENERER_JEU_DE_TEST;
END;
/

SELECT 'sites' AS table_name, COUNT(*) AS nb_lignes FROM sites UNION ALL
SELECT 'users', COUNT(*) FROM users UNION ALL
SELECT 'assets', COUNT(*) FROM assets UNION ALL
SELECT 'tickets', COUNT(*) FROM tickets UNION ALL
SELECT 'network_ports', COUNT(*) FROM network_ports UNION ALL
SELECT 'ip_networks', COUNT(*) FROM ip_networks UNION ALL
SELECT 'ip_addresses', COUNT(*) FROM ip_addresses;
