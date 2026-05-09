-- ============================================================
-- cursors.sql
-- Curseurs PL/SQL — Parcours et traitement de données
-- Oracle XE
-- ============================================================

-- =========================
-- Curseur 1 : Inventaire des matériels d'un site
-- Curseur explicite paramétré
-- =========================

DECLARE
    -- Curseur paramétré par site_code
    CURSOR c_inventaire_site (p_site VARCHAR2) IS
        SELECT c.id, c.name, c.serial, e.name AS entite,
               m.name AS fabricant, s.name AS etat
        FROM computers c
            JOIN entities e ON c.entities_id = e.id
            LEFT JOIN manufacturers m ON c.manufacturers_id = m.id
            LEFT JOIN states s ON c.states_id = s.id
        WHERE e.site_code = p_site
        ORDER BY e.name, c.name;

    v_rec c_inventaire_site%ROWTYPE;
    v_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('INVENTAIRE SITE CERGY');
    DBMS_OUTPUT.PUT_LINE('========================================');

    OPEN c_inventaire_site('CERGY');
    LOOP
        FETCH c_inventaire_site INTO v_rec;
        EXIT WHEN c_inventaire_site%NOTFOUND;

        v_total := v_total + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_rec.name, 25) || ' | ' ||
            RPAD(NVL(v_rec.serial, 'N/A'), 15) || ' | ' ||
            RPAD(NVL(v_rec.fabricant, '-'), 15) || ' | ' ||
            NVL(v_rec.etat, '-')
        );
    END LOOP;
    CLOSE c_inventaire_site;

    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total: ' || v_total || ' ordinateurs');
END;
/

-- =========================
-- Curseur 2 : Détection des anomalies réseau
-- Ports réseau sans connexion (orphelins)
-- =========================

DECLARE
    CURSOR c_ports_orphelins IS
        SELECT np.id, np.name AS port_name, np.mac,
               COALESCE(c.name, ne.name, pr.name) AS equipement,
               e.name AS entite, e.site_code
        FROM network_ports np
            LEFT JOIN network_connections nc1
                ON np.id = nc1.network_ports_id_1
            LEFT JOIN network_connections nc2
                ON np.id = nc2.network_ports_id_2
            LEFT JOIN computers c ON np.computers_id = c.id
            LEFT JOIN network_equipments ne ON np.network_equipments_id = ne.id
            LEFT JOIN printers pr ON np.printers_id = pr.id
            JOIN entities e ON np.entities_id = e.id
        WHERE nc1.id IS NULL AND nc2.id IS NULL;

    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('PORTS RÉSEAU SANS CONNEXION');
    DBMS_OUTPUT.PUT_LINE('========================================');

    FOR rec IN c_ports_orphelins LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            'Port: ' || RPAD(NVL(rec.port_name, 'N/A'), 15) ||
            ' | MAC: ' || RPAD(NVL(rec.mac, 'N/A'), 18) ||
            ' | Equip: ' || RPAD(NVL(rec.equipement, '-'), 20) ||
            ' | Site: ' || rec.site_code
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total ports orphelins: ' || v_count);

    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('>> ATTENTION: ' || v_count ||
            ' ports non connectés détectés.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('>> OK: Tous les ports sont connectés.');
    END IF;
END;
/

-- =========================
-- Curseur 3 : Utilisateurs sans profil actif
-- Utilisation d'un curseur FOR loop implicite
-- =========================

DECLARE
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('UTILISATEURS SANS PROFIL ACTIF');
    DBMS_OUTPUT.PUT_LINE('========================================');

    FOR rec IN (
        SELECT u.id, u.name AS login,
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
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.login, 20) || ' | ' ||
            RPAD(NVL(rec.nom_complet, '-'), 30) || ' | ' ||
            rec.entite || ' (' || rec.site_code || ')'
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total: ' || v_count || ' utilisateurs sans profil');
END;
/

-- =========================
-- Curseur 4 : Rapport récapitulatif par entité
-- Utilisation d'un REF CURSOR (curseur variable)
-- =========================

DECLARE
    TYPE t_ref_cursor IS REF CURSOR;
    c_stats t_ref_cursor;

    v_entite    VARCHAR2(255);
    v_site      VARCHAR2(10);
    v_nb_comp   NUMBER;
    v_nb_users  NUMBER;
    v_nb_ports  NUMBER;

    v_query VARCHAR2(2000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('RAPPORT RÉCAPITULATIF PAR ENTITÉ');
    DBMS_OUTPUT.PUT_LINE('========================================');

    v_query := '
        SELECT e.name, e.site_code,
               (SELECT COUNT(*) FROM computers WHERE entities_id = e.id),
               (SELECT COUNT(*) FROM users WHERE entities_id = e.id),
               (SELECT COUNT(*) FROM network_ports WHERE entities_id = e.id)
        FROM entities e
        WHERE e.site_code IS NOT NULL
        ORDER BY e.site_code, e.name';

    OPEN c_stats FOR v_query;
    LOOP
        FETCH c_stats INTO v_entite, v_site, v_nb_comp, v_nb_users, v_nb_ports;
        EXIT WHEN c_stats%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_entite, 25) || ' | Site: ' || RPAD(v_site, 6) ||
            ' | Computers: ' || LPAD(v_nb_comp, 5) ||
            ' | Users: ' || LPAD(v_nb_users, 5) ||
            ' | Ports: ' || LPAD(v_nb_ports, 5)
        );
    END LOOP;
    CLOSE c_stats;
END;
/
