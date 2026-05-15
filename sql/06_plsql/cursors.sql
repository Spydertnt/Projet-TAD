-- ============================================================
-- cursors.sql
-- Curseurs PL/SQL - Schema simplifie
-- Oracle XE
-- ============================================================

DECLARE
    CURSOR c_inventaire_site (p_site VARCHAR2) IS
        SELECT a.id, a.category, a.name, a.serial, e.name AS entite,
               m.name AS fabricant, s.name AS etat
        FROM assets a
            JOIN entities e ON a.entities_id = e.id
            LEFT JOIN manufacturers m ON a.manufacturers_id = m.id
            LEFT JOIN states s ON a.states_id = s.id
        WHERE e.site_code = p_site
        ORDER BY a.category, a.name;

    v_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('INVENTAIRE SITE CERGY');

    FOR rec IN c_inventaire_site('CERGY') LOOP
        v_total := v_total + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.category, 18) || ' | ' ||
            RPAD(rec.name, 25) || ' | ' ||
            RPAD(NVL(rec.serial, 'N/A'), 15) || ' | ' ||
            NVL(rec.etat, '-')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total: ' || v_total || ' materiels');
END;
/

DECLARE
    CURSOR c_ports_orphelins IS
        SELECT np.id, np.name AS port_name, np.mac,
               a.name AS equipement, e.site_code
        FROM network_ports np
            LEFT JOIN network_connections nc1 ON np.id = nc1.network_ports_id_1
            LEFT JOIN network_connections nc2 ON np.id = nc2.network_ports_id_2
            JOIN assets a ON np.assets_id = a.id
            JOIN entities e ON np.entities_id = e.id
        WHERE nc1.id IS NULL AND nc2.id IS NULL;

    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('PORTS RESEAU SANS CONNEXION');

    FOR rec IN c_ports_orphelins LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            'Port: ' || RPAD(NVL(rec.port_name, 'N/A'), 15) ||
            ' | MAC: ' || RPAD(NVL(rec.mac, 'N/A'), 18) ||
            ' | Equip: ' || RPAD(rec.equipement, 25) ||
            ' | Site: ' || rec.site_code
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total ports orphelins: ' || v_count);
END;
/

DECLARE
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('UTILISATEURS SANS PROFIL ACTIF');

    FOR rec IN (
        SELECT u.id, u.login,
               u.realname || ' ' || u.firstname AS nom_complet,
               e.name AS entite, e.site_code
        FROM users u
            JOIN entities e ON u.entities_id = e.id
            LEFT JOIN profiles_users pu ON u.id = pu.users_id
        WHERE pu.id IS NULL
          AND u.is_active = 1
        ORDER BY e.site_code, u.realname
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
               (SELECT COUNT(*) FROM assets WHERE entities_id = e.id),
               (SELECT COUNT(*) FROM users WHERE entities_id = e.id),
               (SELECT COUNT(*) FROM network_ports WHERE entities_id = e.id)
        FROM entities e
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
