-- ============================================================
-- 09_test_data.sql
-- Jeu de test etoffe - GLPI Multi-Sites
-- Oracle XE
-- ============================================================

SET SERVEROUTPUT ON

CREATE OR REPLACE PROCEDURE SP_GENERER_JEU_DE_TEST (
    p_assets_cergy IN NUMBER DEFAULT 800,
    p_assets_pau   IN NUMBER DEFAULT 600
)
AS
    v_cergy_id NUMBER;
    v_pau_id NUMBER;

    v_loc_cergy_a NUMBER;
    v_loc_cergy_b NUMBER;
    v_loc_cergy_dc NUMBER;
    v_loc_pau_a NUMBER;
    v_loc_pau_b NUMBER;
    v_loc_pau_dc NUMBER;

    v_group_cergy_support NUMBER;
    v_group_cergy_reseau NUMBER;
    v_group_cergy_admin NUMBER;
    v_group_pau_support NUMBER;
    v_group_pau_reseau NUMBER;
    v_group_pau_admin NUMBER;

    v_profile_admin_id NUMBER;
    v_profile_tech_id NUMBER;
    v_profile_manager_id NUMBER;
    v_profile_user_id NUMBER;

    v_cat_incident_id NUMBER;
    v_cat_reseau_id NUMBER;
    v_cat_install_id NUMBER;
    v_cat_acces_id NUMBER;
    v_cat_stock_id NUMBER;

    v_user_id NUMBER;
    v_tech_user_id NUMBER;
    v_asset_id NUMBER;
    v_ticket_id NUMBER;
    v_port_id NUMBER;
    v_ip_network_id NUMBER;
    v_net_users_id NUMBER;
    v_net_servers_id NUMBER;
    v_net_printers_id NUMBER;
    v_net_wifi_id NUMBER;
    v_manuf_id NUMBER;
    v_state_id NUMBER;
    v_user_count NUMBER;

    v_asset_type VARCHAR2(50);
    v_site VARCHAR2(10);
    v_site_id NUMBER;
    v_location_id NUMBER;
    v_group_id NUMBER;
    v_limit NUMBER;
    v_phone VARCHAR2(100);
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
    DELETE FROM profiles;
    DELETE FROM audit_log;
    DELETE FROM archives_materiel;
    COMMIT;

    -- Sites.
    INSERT INTO sites (name, site_code, full_name)
    VALUES ('CY Tech Cergy', 'CERGY', 'CY Tech Cergy')
    RETURNING id INTO v_cergy_id;

    INSERT INTO sites (name, site_code, full_name)
    VALUES ('CY Tech Pau', 'PAU', 'CY Tech Pau')
    RETURNING id INTO v_pau_id;

    -- Localisations.
    INSERT INTO locations (site_id, name, full_name, building, room)
    VALUES (v_cergy_id, 'Batiment A', 'CY Tech Cergy > Batiment A', 'A', 'Open Space')
    RETURNING id INTO v_loc_cergy_a;

    INSERT INTO locations (site_id, name, full_name, building, room)
    VALUES (v_cergy_id, 'Batiment B', 'CY Tech Cergy > Batiment B', 'B', 'Salles de cours')
    RETURNING id INTO v_loc_cergy_b;

    INSERT INTO locations (site_id, name, full_name, building, room)
    VALUES (v_cergy_id, 'Salle serveur Cergy', 'CY Tech Cergy > Salle serveur', 'A', 'DC-01')
    RETURNING id INTO v_loc_cergy_dc;

    INSERT INTO locations (site_id, name, full_name, building, room)
    VALUES (v_pau_id, 'Batiment A', 'CY Tech Pau > Batiment A', 'A', 'Administration')
    RETURNING id INTO v_loc_pau_a;

    INSERT INTO locations (site_id, name, full_name, building, room)
    VALUES (v_pau_id, 'Batiment B', 'CY Tech Pau > Batiment B', 'B', 'Salles projets')
    RETURNING id INTO v_loc_pau_b;

    INSERT INTO locations (site_id, name, full_name, building, room)
    VALUES (v_pau_id, 'Salle serveur Pau', 'CY Tech Pau > Salle serveur', 'B', 'DC-02')
    RETURNING id INTO v_loc_pau_dc;

    -- Referentiels.
    INSERT INTO manufacturers (name) VALUES ('Dell');
    INSERT INTO manufacturers (name) VALUES ('HP');
    INSERT INTO manufacturers (name) VALUES ('Lenovo');
    INSERT INTO manufacturers (name) VALUES ('Cisco');
    INSERT INTO manufacturers (name) VALUES ('Epson');
    INSERT INTO manufacturers (name) VALUES ('Apple');
    INSERT INTO manufacturers (name) VALUES ('Samsung');
    INSERT INTO manufacturers (name) VALUES ('Ubiquiti');

    INSERT INTO states (name) VALUES ('En service');
    INSERT INTO states (name) VALUES ('En stock');
    INSERT INTO states (name) VALUES ('En maintenance');
    INSERT INTO states (name) VALUES ('Hors service');
    INSERT INTO states (name) VALUES ('A renouveler');

    INSERT INTO profiles (name, interface, is_default) VALUES ('Administrateur', 'central', 0)
    RETURNING id INTO v_profile_admin_id;
    INSERT INTO profiles (name, interface, is_default) VALUES ('Technicien', 'central', 0)
    RETURNING id INTO v_profile_tech_id;
    INSERT INTO profiles (name, interface, is_default) VALUES ('Manager site', 'central', 0)
    RETURNING id INTO v_profile_manager_id;
    INSERT INTO profiles (name, interface, is_default) VALUES ('Utilisateur', 'helpdesk', 1)
    RETURNING id INTO v_profile_user_id;

    INSERT INTO ticket_categories (name, description)
    VALUES ('Incident materiel', 'Panne ou degradation d''un equipement')
    RETURNING id INTO v_cat_incident_id;
    INSERT INTO ticket_categories (name, description)
    VALUES ('Demande reseau', 'Demande liee aux ports, IP ou sous-reseaux')
    RETURNING id INTO v_cat_reseau_id;
    INSERT INTO ticket_categories (name, description)
    VALUES ('Installation', 'Installation ou renouvellement de materiel')
    RETURNING id INTO v_cat_install_id;
    INSERT INTO ticket_categories (name, description)
    VALUES ('Acces utilisateur', 'Demande de profil, groupe ou rattachement')
    RETURNING id INTO v_cat_acces_id;
    INSERT INTO ticket_categories (name, description)
    VALUES ('Gestion du stock', 'Mouvement ou controle du parc en stock')
    RETURNING id INTO v_cat_stock_id;

    -- Groupes.
    INSERT INTO groups (site_id, name, full_name)
    VALUES (v_cergy_id, 'Support IT Cergy', 'CY Tech Cergy > Support IT')
    RETURNING id INTO v_group_cergy_support;
    INSERT INTO groups (site_id, name, full_name)
    VALUES (v_cergy_id, 'Equipe reseau Cergy', 'CY Tech Cergy > Equipe reseau')
    RETURNING id INTO v_group_cergy_reseau;
    INSERT INTO groups (site_id, name, full_name)
    VALUES (v_cergy_id, 'Administration Cergy', 'CY Tech Cergy > Administration')
    RETURNING id INTO v_group_cergy_admin;

    INSERT INTO groups (site_id, name, full_name)
    VALUES (v_pau_id, 'Support IT Pau', 'CY Tech Pau > Support IT')
    RETURNING id INTO v_group_pau_support;
    INSERT INTO groups (site_id, name, full_name)
    VALUES (v_pau_id, 'Equipe reseau Pau', 'CY Tech Pau > Equipe reseau')
    RETURNING id INTO v_group_pau_reseau;
    INSERT INTO groups (site_id, name, full_name)
    VALUES (v_pau_id, 'Administration Pau', 'CY Tech Pau > Administration')
    RETURNING id INTO v_group_pau_admin;

    -- Utilisateurs : 180 a Cergy, 120 a Pau.
    FOR i IN 1..300 LOOP
        IF i <= 180 THEN
            v_site := 'CERGY';
            v_site_id := v_cergy_id;
            v_location_id := CASE MOD(i, 3)
                WHEN 0 THEN v_loc_cergy_dc
                WHEN 1 THEN v_loc_cergy_a
                ELSE v_loc_cergy_b
            END;
            v_group_id := CASE
                WHEN MOD(i, 15) = 0 THEN v_group_cergy_reseau
                WHEN MOD(i, 12) = 0 THEN v_group_cergy_admin
                ELSE v_group_cergy_support
            END;
        ELSE
            v_site := 'PAU';
            v_site_id := v_pau_id;
            v_location_id := CASE MOD(i, 3)
                WHEN 0 THEN v_loc_pau_dc
                WHEN 1 THEN v_loc_pau_a
                ELSE v_loc_pau_b
            END;
            v_group_id := CASE
                WHEN MOD(i, 15) = 0 THEN v_group_pau_reseau
                WHEN MOD(i, 12) = 0 THEN v_group_pau_admin
                ELSE v_group_pau_support
            END;
        END IF;

        v_phone := '01' || LPAD(i, 8, '0');

        INSERT INTO users (login, last_name, first_name, email, phone, site_id, location_id, is_active)
        VALUES (
            LOWER('user_' || v_site || '_' || LPAD(i, 3, '0')),
            'Nom' || i,
            'Prenom' || i,
            LOWER('user_' || v_site || '_' || LPAD(i, 3, '0') || '@cy-tech.fr'),
            v_phone,
            v_site_id,
            v_location_id,
            CASE WHEN MOD(i, 37) = 0 THEN 0 ELSE 1 END
        )
        RETURNING id INTO v_user_id;

        INSERT INTO profiles_users (user_id, profile_id, site_id, is_recursive)
        VALUES (
            v_user_id,
            CASE
                WHEN MOD(i, 60) = 0 THEN v_profile_admin_id
                WHEN MOD(i, 10) = 0 THEN v_profile_tech_id
                WHEN MOD(i, 18) = 0 THEN v_profile_manager_id
                ELSE v_profile_user_id
            END,
            v_site_id,
            CASE WHEN MOD(i, 45) = 0 THEN 1 ELSE 0 END
        );

        IF MOD(i, 4) = 0 OR MOD(i, 10) = 0 THEN
            INSERT INTO groups_users (user_id, group_id, is_manager)
            VALUES (v_user_id, v_group_id, CASE WHEN MOD(i, 60) = 0 THEN 1 ELSE 0 END);
        END IF;
    END LOOP;

    -- Inventaire, reseau, tickets.
    FOR site_idx IN 1..2 LOOP
        IF site_idx = 1 THEN
            v_site := 'CERGY';
            v_site_id := v_cergy_id;
            v_group_id := v_group_cergy_support;
            v_limit := p_assets_cergy;
        ELSE
            v_site := 'PAU';
            v_site_id := v_pau_id;
            v_group_id := v_group_pau_support;
            v_limit := p_assets_pau;
        END IF;

        INSERT INTO ip_networks (site_id, network_name, network_address, subnet_mask, gateway_address, vlan_name, vlan_tag)
        VALUES (
            v_site_id, 'LAN Utilisateurs ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN '10.10.0.0' ELSE '10.20.0.0' END,
            '255.255.0.0',
            CASE WHEN v_site = 'CERGY' THEN '10.10.0.1' ELSE '10.20.0.1' END,
            'VLAN Users ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN 10 ELSE 20 END
        )
        RETURNING id INTO v_net_users_id;

        INSERT INTO ip_networks (site_id, network_name, network_address, subnet_mask, gateway_address, vlan_name, vlan_tag)
        VALUES (
            v_site_id, 'Serveurs ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN '10.10.100.0' ELSE '10.20.100.0' END,
            '255.255.255.0',
            CASE WHEN v_site = 'CERGY' THEN '10.10.100.1' ELSE '10.20.100.1' END,
            'VLAN Servers ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN 110 ELSE 120 END
        )
        RETURNING id INTO v_net_servers_id;

        INSERT INTO ip_networks (site_id, network_name, network_address, subnet_mask, gateway_address, vlan_name, vlan_tag)
        VALUES (
            v_site_id, 'Imprimantes ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN '10.10.50.0' ELSE '10.20.50.0' END,
            '255.255.255.0',
            CASE WHEN v_site = 'CERGY' THEN '10.10.50.1' ELSE '10.20.50.1' END,
            'VLAN Printers ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN 50 ELSE 60 END
        )
        RETURNING id INTO v_net_printers_id;

        INSERT INTO ip_networks (site_id, network_name, network_address, subnet_mask, gateway_address, vlan_name, vlan_tag)
        VALUES (
            v_site_id, 'Wi-Fi ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN '10.10.200.0' ELSE '10.20.200.0' END,
            '255.255.255.0',
            CASE WHEN v_site = 'CERGY' THEN '10.10.200.1' ELSE '10.20.200.1' END,
            'VLAN WiFi ' || v_site,
            CASE WHEN v_site = 'CERGY' THEN 210 ELSE 220 END
        )
        RETURNING id INTO v_net_wifi_id;

        SELECT COUNT(*) INTO v_user_count FROM users WHERE site_id = v_site_id;

        FOR i IN 1..v_limit LOOP
            CASE MOD(i, 6)
                WHEN 0 THEN v_asset_type := 'NETWORK_EQUIPMENT';
                WHEN 1 THEN v_asset_type := 'COMPUTER';
                WHEN 2 THEN v_asset_type := 'MONITOR';
                WHEN 3 THEN v_asset_type := 'PRINTER';
                WHEN 4 THEN v_asset_type := 'PHONE';
                ELSE v_asset_type := 'PERIPHERAL';
            END CASE;

            v_location_id := CASE
                WHEN v_site = 'CERGY' AND v_asset_type = 'NETWORK_EQUIPMENT' THEN v_loc_cergy_dc
                WHEN v_site = 'CERGY' AND MOD(i, 2) = 0 THEN v_loc_cergy_a
                WHEN v_site = 'CERGY' THEN v_loc_cergy_b
                WHEN v_site = 'PAU' AND v_asset_type = 'NETWORK_EQUIPMENT' THEN v_loc_pau_dc
                WHEN v_site = 'PAU' AND MOD(i, 2) = 0 THEN v_loc_pau_a
                ELSE v_loc_pau_b
            END;

            SELECT id INTO v_manuf_id FROM manufacturers WHERE name =
                CASE
                    WHEN v_asset_type = 'NETWORK_EQUIPMENT' AND MOD(i, 2) = 0 THEN 'Cisco'
                    WHEN v_asset_type = 'NETWORK_EQUIPMENT' THEN 'Ubiquiti'
                    WHEN v_asset_type = 'PRINTER' THEN 'Epson'
                    WHEN v_asset_type = 'PHONE' THEN 'Samsung'
                    WHEN MOD(i, 5) = 0 THEN 'Apple'
                    WHEN MOD(i, 2) = 0 THEN 'Dell'
                    ELSE 'Lenovo'
                END;

            SELECT id INTO v_state_id FROM states WHERE name =
                CASE
                    WHEN MOD(i, 89) = 0 THEN 'Hors service'
                    WHEN MOD(i, 37) = 0 THEN 'A renouveler'
                    WHEN MOD(i, 17) = 0 THEN 'En maintenance'
                    WHEN MOD(i, 11) = 0 THEN 'En stock'
                    ELSE 'En service'
                END;

            SELECT MIN(id) + MOD(i, v_user_count)
            INTO v_user_id
            FROM users
            WHERE site_id = v_site_id;

            INSERT INTO assets (
                site_id, asset_type, name, serial_number,
                owner_user_id, technician_user_id, location_id, manufacturer_id,
                state_id
            )
            VALUES (
                v_site_id,
                v_asset_type,
                CASE v_asset_type
                    WHEN 'COMPUTER' THEN 'PC'
                    WHEN 'NETWORK_EQUIPMENT' THEN 'NET'
                    WHEN 'MONITOR' THEN 'MON'
                    WHEN 'PRINTER' THEN 'PRI'
                    WHEN 'PHONE' THEN 'PHO'
                    ELSE 'PER'
                END || '-' || v_site || '-' || LPAD(i, 5, '0'),
                'SN-2026-' || v_site || '-' || LPAD(i, 5, '0'),
                CASE WHEN v_asset_type IN ('COMPUTER','PHONE','PERIPHERAL') THEN v_user_id END,
                NULL,
                v_location_id,
                v_manuf_id,
                v_state_id
            )
            RETURNING id INTO v_asset_id;

            IF v_asset_type IN ('COMPUTER','PRINTER','NETWORK_EQUIPMENT','PHONE') THEN
                v_ip_network_id := CASE
                    WHEN v_asset_type = 'NETWORK_EQUIPMENT' THEN v_net_servers_id
                    WHEN v_asset_type = 'PRINTER' THEN v_net_printers_id
                    WHEN v_asset_type = 'PHONE' THEN v_net_wifi_id
                    ELSE v_net_users_id
                END;

                INSERT INTO network_ports (site_id, asset_id, port_name, mac_address, port_type)
                VALUES (
                    v_site_id,
                    v_asset_id,
                    CASE WHEN v_asset_type = 'PHONE' THEN 'wifi0' ELSE 'eth0' END,
                    '02:' || LPAD(MOD(i, 255), 2, '0') || ':AA:' || LPAD(MOD(i * 3, 255), 2, '0') ||
                    ':BB:' || LPAD(MOD(i * 7, 255), 2, '0'),
                    CASE WHEN v_asset_type = 'PHONE' THEN 'Wi-Fi' ELSE 'Ethernet' END
                )
                RETURNING id INTO v_port_id;

                INSERT INTO ip_addresses (site_id, network_port_id, ip_network_id, ip_address)
                VALUES (
                    v_site_id,
                    v_port_id,
                    v_ip_network_id,
                    CASE
                        WHEN v_site = 'CERGY' AND v_ip_network_id = v_net_servers_id THEN '10.10.100.'
                        WHEN v_site = 'CERGY' AND v_ip_network_id = v_net_printers_id THEN '10.10.50.'
                        WHEN v_site = 'CERGY' AND v_ip_network_id = v_net_wifi_id THEN '10.10.200.'
                        WHEN v_site = 'CERGY' THEN '10.10.' || TO_CHAR(TRUNC(i / 250)) || '.'
                        WHEN v_ip_network_id = v_net_servers_id THEN '10.20.100.'
                        WHEN v_ip_network_id = v_net_printers_id THEN '10.20.50.'
                        WHEN v_ip_network_id = v_net_wifi_id THEN '10.20.200.'
                        ELSE '10.20.' || TO_CHAR(TRUNC(i / 250)) || '.'
                    END || TO_CHAR(MOD(i, 240) + 10)
                );
            END IF;

            IF MOD(i, 12) = 0 THEN
                SELECT MIN(u.id)
                INTO v_tech_user_id
                FROM users u
                    JOIN profiles_users pu ON pu.user_id = u.id
                WHERE u.site_id = v_site_id
                  AND pu.profile_id = v_profile_tech_id;

                v_group_id := CASE
                    WHEN v_asset_type = 'NETWORK_EQUIPMENT' AND v_site = 'CERGY' THEN v_group_cergy_reseau
                    WHEN v_asset_type = 'NETWORK_EQUIPMENT' THEN v_group_pau_reseau
                    WHEN v_site = 'CERGY' THEN v_group_cergy_support
                    ELSE v_group_pau_support
                END;

                INSERT INTO tickets (
                    site_id, asset_id, title, description, status, priority,
                    requester_user_id, assigned_group_id, category_id, assigned_at,
                    resolved_at, closed_at
                )
                VALUES (
                    v_site_id,
                    v_asset_id,
                    'Ticket ' || v_site || ' sur ' || v_asset_type || ' #' || i,
                    'Ticket genere automatiquement pour tester les vues, index et procedures.',
                    CASE
                        WHEN MOD(i, 60) = 0 THEN 'CLOS'
                        WHEN MOD(i, 48) = 0 THEN 'RESOLU'
                        WHEN MOD(i, 36) = 0 THEN 'EN_COURS'
                        WHEN MOD(i, 24) = 0 THEN 'ASSIGNE'
                        ELSE 'NOUVEAU'
                    END,
                    CASE
                        WHEN MOD(i, 96) = 0 THEN 'CRITIQUE'
                        WHEN MOD(i, 48) = 0 THEN 'HAUTE'
                        WHEN MOD(i, 18) = 0 THEN 'BASSE'
                        ELSE 'MOYENNE'
                    END,
                    v_user_id,
                    v_group_id,
                    CASE
                        WHEN v_asset_type = 'NETWORK_EQUIPMENT' THEN v_cat_reseau_id
                        WHEN v_asset_type = 'PRINTER' THEN v_cat_incident_id
                        WHEN MOD(i, 5) = 0 THEN v_cat_install_id
                        WHEN MOD(i, 7) = 0 THEN v_cat_acces_id
                        ELSE v_cat_stock_id
                    END,
                    CASE WHEN MOD(i, 24) = 0 THEN SYSTIMESTAMP - INTERVAL '2' DAY END,
                    CASE WHEN MOD(i, 48) = 0 THEN SYSTIMESTAMP - INTERVAL '1' DAY END,
                    CASE WHEN MOD(i, 60) = 0 THEN SYSTIMESTAMP END
                )
                RETURNING id INTO v_ticket_id;

                INSERT INTO ticket_users (ticket_id, user_id, assigned_by_user_id)
                VALUES (v_ticket_id, v_tech_user_id, v_tech_user_id);

                INSERT INTO ticket_followups (ticket_id, user_id, content)
                VALUES (v_ticket_id, v_user_id, 'Demande initiale creee automatiquement.');

                IF MOD(i, 24) = 0 THEN
                    INSERT INTO ticket_followups (ticket_id, user_id, content)
                    VALUES (v_ticket_id, v_tech_user_id, 'Diagnostic effectue par le support.');
                END IF;

                IF MOD(i, 48) = 0 THEN
                    INSERT INTO ticket_followups (ticket_id, user_id, content)
                    VALUES (v_ticket_id, v_tech_user_id, 'Resolution appliquee et controle effectue.');
                END IF;
            END IF;
        END LOOP;
    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Jeu de test etoffe genere.');
    DBMS_OUTPUT.PUT_LINE('Assets: ' || (p_assets_cergy + p_assets_pau));
    DBMS_OUTPUT.PUT_LINE('Utilisateurs: 300');
END SP_GENERER_JEU_DE_TEST;
/

BEGIN
    SP_GENERER_JEU_DE_TEST;
END;
/

SELECT 'sites' AS table_name, COUNT(*) AS nb_lignes FROM sites UNION ALL
SELECT 'locations', COUNT(*) FROM locations UNION ALL
SELECT 'users', COUNT(*) FROM users UNION ALL
SELECT 'profiles_users', COUNT(*) FROM profiles_users UNION ALL
SELECT 'groups_users', COUNT(*) FROM groups_users UNION ALL
SELECT 'assets', COUNT(*) FROM assets UNION ALL
SELECT 'tickets', COUNT(*) FROM tickets UNION ALL
SELECT 'ticket_users', COUNT(*) FROM ticket_users UNION ALL
SELECT 'ticket_followups', COUNT(*) FROM ticket_followups UNION ALL
SELECT 'network_ports', COUNT(*) FROM network_ports UNION ALL
SELECT 'ip_networks', COUNT(*) FROM ip_networks UNION ALL
SELECT 'ip_addresses', COUNT(*) FROM ip_addresses;
