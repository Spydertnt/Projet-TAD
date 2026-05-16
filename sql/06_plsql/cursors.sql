-- ============================================================
-- cursors.sql
-- Curseurs PL/SQL - Schema simplifie
-- Oracle XE
-- ============================================================

DECLARE
    CURSOR c_inventaire_site (p_site VARCHAR2) IS
        SELECT a.id, a.asset_type, a.name, a.serial_number, e.name AS entite,
               m.name AS fabricant, s.name AS etat
        FROM assets a
            JOIN sites e ON a.site_id = e.id
            LEFT JOIN manufacturers m ON a.manufacturer_id = m.id
            LEFT JOIN states s ON a.state_id = s.id
        WHERE e.site_code = p_site
        ORDER BY a.asset_type, a.name;

    v_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('INVENTAIRE SITE CERGY');

    FOR rec IN c_inventaire_site('CERGY') LOOP
        v_total := v_total + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.asset_type, 18) || ' | ' ||
            RPAD(rec.name, 25) || ' | ' ||
            RPAD(NVL(rec.serial_number, 'N/A'), 15) || ' | ' ||
            NVL(rec.etat, '-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total: ' || v_total || ' materiels');
END;
/

DECLARE
    CURSOR c_ports_sans_ip IS
        SELECT np.id, np.port_name, np.mac_address,
               a.name AS equipement, e.site_code
        FROM network_ports np
            JOIN assets a ON np.asset_id = a.id
            JOIN sites e ON np.site_id = e.id
        WHERE NOT EXISTS (
            SELECT 1
            FROM ip_addresses ia
            WHERE ia.network_port_id = np.id
        );

    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('PORTS RESEAU SANS ADRESSE IP');

    FOR rec IN c_ports_sans_ip LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            'Port: ' || RPAD(NVL(rec.port_name, 'N/A'), 15) ||
            ' | MAC: ' || RPAD(NVL(rec.mac_address, 'N/A'), 18) ||
            ' | Equip: ' || RPAD(rec.equipement, 25) ||
            ' | Site: ' || rec.site_code
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total ports sans IP: ' || v_count);
END;
/

DECLARE
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('UTILISATEURS SANS PROFIL ACTIF');

    FOR rec IN (
        SELECT u.id, u.login,
               u.last_name || ' ' || u.first_name AS nom_complet,
               e.name AS entite, e.site_code
        FROM users u
            JOIN sites e ON u.site_id = e.id
            LEFT JOIN profiles_users pu ON u.id = pu.user_id
        WHERE pu.id IS NULL
          AND u.is_active = 1
        ORDER BY e.site_code, u.last_name
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(RPAD(rec.login, 20) || ' | ' || rec.entite);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total: ' || v_count || ' utilisateurs sans profil');
END;
/

DECLARE
    TYPE t_ref_cursor IS REF CURSOR;
    c_stats t_ref_cursor;
    v_entite VARCHAR2(255);
    v_site VARCHAR2(10);
    v_nb_assets NUMBER;
    v_nb_users NUMBER;
    v_nb_ports NUMBER;
    v_query VARCHAR2(2000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('RAPPORT RECAPITULATIF PAR ENTITE');

    v_query := '
        SELECT e.name, e.site_code,
               (SELECT COUNT(*) FROM assets WHERE site_id = e.id),
               (SELECT COUNT(*) FROM users WHERE site_id = e.id),
               (SELECT COUNT(*) FROM network_ports WHERE site_id = e.id)
        FROM sites e
        WHERE e.site_code IS NOT NULL
        ORDER BY e.site_code, e.name';

    OPEN c_stats FOR v_query;
    LOOP
        FETCH c_stats INTO v_entite, v_site, v_nb_assets, v_nb_users, v_nb_ports;
        EXIT WHEN c_stats%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_entite, 25) || ' | Site: ' || RPAD(v_site, 6) ||
            ' | Assets: ' || LPAD(v_nb_assets, 5) ||
            ' | Users: ' || LPAD(v_nb_users, 5) ||
            ' | Ports: ' || LPAD(v_nb_ports, 5)
        );
    END LOOP;
    CLOSE c_stats;
END;
/
