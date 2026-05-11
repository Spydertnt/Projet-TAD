-- ============================================================
-- 10_benchmark.sql
-- Benchmark des requetes — Comparaison avec/sans index
-- Oracle XE — Phase 3 : Tests de performance
-- ============================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

-- =========================
-- PROCEDURE DE BENCHMARK
-- =========================

CREATE OR REPLACE PROCEDURE SP_BENCHMARK_QUERY (
    p_query_id    IN VARCHAR2,
    p_query_desc  IN VARCHAR2,
    p_scenario    IN VARCHAR2,
    p_sql         IN VARCHAR2,
    p_nb_runs     IN NUMBER DEFAULT 5
)
AS
    v_start     TIMESTAMP;
    v_end       TIMESTAMP;
    v_elapsed   NUMBER;
    v_total_ms  NUMBER := 0;
    v_rows      NUMBER;
    v_cursor    SYS_REFCURSOR;
    v_dummy     VARCHAR2(4000);
BEGIN
    FOR run IN 1..p_nb_runs LOOP
        v_start := SYSTIMESTAMP;
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (' || p_sql || ')' INTO v_rows;
        v_end := SYSTIMESTAMP;
        v_elapsed := EXTRACT(DAY FROM (v_end - v_start)) * 86400000
                   + EXTRACT(HOUR FROM (v_end - v_start)) * 3600000
                   + EXTRACT(MINUTE FROM (v_end - v_start)) * 60000
                   + EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
        v_total_ms := v_total_ms + v_elapsed;
    END LOOP;

    INSERT INTO benchmark_results (query_id, query_desc, scenario, execution_ms, rows_returned)
    VALUES (p_query_id, p_query_desc, p_scenario,
            ROUND(v_total_ms / p_nb_runs, 2), v_rows);
    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        RPAD(p_query_id, 6) || ' | ' ||
        RPAD(p_scenario, 12) || ' | ' ||
        LPAD(ROUND(v_total_ms / p_nb_runs, 2), 10) || ' ms | ' ||
        LPAD(v_rows, 8) || ' rows | ' || p_query_desc);
END SP_BENCHMARK_QUERY;
/

-- =========================
-- REQUETES DE BENCHMARK
-- =========================

-- Les 8 requetes a tester
-- Q1: Recherche par nom (index fonctionnel UPPER)
-- Q2: Inventaire site complet (index composite)
-- Q3: Stats VLAN agregees (jointures multiples + GROUP BY)
-- Q4: Recherche par serial (index fonctionnel)
-- Q5: Vue V_INVENTAIRE_COMPLET
-- Q6: Utilisateurs avec profils (jointures 4 tables)
-- Q7: Comptage materiel par fabricant et site (GROUP BY)
-- Q8: Topologie reseau complete (vue 7+ jointures)

-- =========================
-- SCENARIO A : SANS INDEX (index INVISIBLE)
-- =========================

CREATE OR REPLACE PROCEDURE SP_RUN_BENCHMARK_SANS_INDEX
AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('  SCENARIO A : SANS INDEX');
    DBMS_OUTPUT.PUT_LINE('  Date: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('============================================');

    -- Desactiver les index
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_name_upper INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_serial_upper INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_entity INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_entity_state INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_entity_user INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_user INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_location INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_state INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_manuf INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_users_entity INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_users_name_upper INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_pu_user INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_pu_profile INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_pu_entity INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_pu_entity_user INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_np_entity INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_np_computer INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_np_neq INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_npv_port INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_npv_vlan INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_entities_site INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_vlans_entity_tag INVISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Vider le cache
    BEGIN EXECUTE IMMEDIATE 'ALTER SYSTEM FLUSH BUFFER_CACHE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER SYSTEM FLUSH SHARED_POOL'; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Executer les requetes
    SP_BENCHMARK_QUERY('Q1', 'Recherche par nom (UPPER)', 'SANS_INDEX',
        'SELECT c.id, c.name, c.serial, e.name AS entite, m.name AS fabricant
         FROM computers c
         JOIN entities e ON c.entities_id = e.id
         LEFT JOIN manufacturers m ON c.manufacturers_id = m.id
         WHERE UPPER(c.name) = ''PC-CERGY-0042''');

    SP_BENCHMARK_QUERY('Q2', 'Inventaire site complet', 'SANS_INDEX',
        'SELECT c.name, c.serial,
                u.realname || '' '' || u.firstname AS proprietaire,
                s.name AS etat, l.completename AS localisation
         FROM computers c
         JOIN entities e ON c.entities_id = e.id
         LEFT JOIN users u ON c.users_id = u.id
         LEFT JOIN states s ON c.states_id = s.id
         LEFT JOIN locations l ON c.locations_id = l.id
         WHERE e.site_code = ''CERGY''');

    SP_BENCHMARK_QUERY('Q3', 'Statistiques VLAN agregees', 'SANS_INDEX',
        'SELECT v.name, v.tag, e.name,
                COUNT(npv.id) AS nb_ports,
                COUNT(DISTINCT np.computers_id) AS nb_computers
         FROM vlans v
         JOIN entities e ON v.entities_id = e.id
         LEFT JOIN network_port_vlans npv ON v.id = npv.vlans_id
         LEFT JOIN network_ports np ON npv.network_ports_id = np.id
         GROUP BY v.name, v.tag, e.name');

    SP_BENCHMARK_QUERY('Q4', 'Recherche par serial (UPPER)', 'SANS_INDEX',
        'SELECT c.id, c.name, c.serial, e.name AS entite
         FROM computers c JOIN entities e ON c.entities_id = e.id
         WHERE UPPER(c.serial) = ''SN-CERGY-00042''');

    SP_BENCHMARK_QUERY('Q5', 'Vue inventaire complet par site', 'SANS_INDEX',
        'SELECT type_materiel, COUNT(*) AS nombre
         FROM V_INVENTAIRE_COMPLET
         WHERE site = ''CERGY''
         GROUP BY type_materiel');

    SP_BENCHMARK_QUERY('Q6', 'Utilisateurs avec profils', 'SANS_INDEX',
        'SELECT u.name, u.realname || '' '' || u.firstname AS nom,
                p.name AS profil, e.name AS entite, e.site_code
         FROM users u
         JOIN profiles_users pu ON u.id = pu.users_id
         JOIN profiles p ON pu.profiles_id = p.id
         JOIN entities e ON pu.entities_id = e.id
         WHERE u.is_active = 1');

    SP_BENCHMARK_QUERY('Q7', 'Materiel par fabricant et site', 'SANS_INDEX',
        'SELECT m.name AS fabricant, e.site_code, COUNT(*) AS nb
         FROM computers c
         JOIN entities e ON c.entities_id = e.id
         JOIN manufacturers m ON c.manufacturers_id = m.id
         GROUP BY m.name, e.site_code
         ORDER BY nb DESC');

    SP_BENCHMARK_QUERY('Q8', 'Topologie reseau complete', 'SANS_INDEX',
        'SELECT port_id, nom_port, mac, type_port, equipement,
                type_equipement, entite, site, vlan_name, adresse_ip
         FROM V_TOPOLOGIE_RESEAU
         WHERE site = ''CERGY''');

    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('  FIN SCENARIO A');
    DBMS_OUTPUT.PUT_LINE('============================================');
END SP_RUN_BENCHMARK_SANS_INDEX;
/

-- =========================
-- SCENARIO B : AVEC INDEX (index VISIBLE)
-- =========================

CREATE OR REPLACE PROCEDURE SP_RUN_BENCHMARK_AVEC_INDEX
AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('  SCENARIO B : AVEC INDEX');
    DBMS_OUTPUT.PUT_LINE('  Date: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('============================================');

    -- Reactiver les index
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_name_upper VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_serial_upper VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_entity VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_entity_state VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_entity_user VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_user VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_location VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_state VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_comp_manuf VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_users_entity VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_users_name_upper VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_pu_user VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_pu_profile VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_pu_entity VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_pu_entity_user VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_np_entity VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_np_computer VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_np_neq VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_npv_port VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_npv_vlan VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_entities_site VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER INDEX idx_vlans_entity_tag VISIBLE'; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Vider le cache
    BEGIN EXECUTE IMMEDIATE 'ALTER SYSTEM FLUSH BUFFER_CACHE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'ALTER SYSTEM FLUSH SHARED_POOL'; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Memes requetes que Scenario A
    SP_BENCHMARK_QUERY('Q1', 'Recherche par nom (UPPER)', 'AVEC_INDEX',
        'SELECT c.id, c.name, c.serial, e.name AS entite, m.name AS fabricant
         FROM computers c
         JOIN entities e ON c.entities_id = e.id
         LEFT JOIN manufacturers m ON c.manufacturers_id = m.id
         WHERE UPPER(c.name) = ''PC-CERGY-0042''');

    SP_BENCHMARK_QUERY('Q2', 'Inventaire site complet', 'AVEC_INDEX',
        'SELECT c.name, c.serial,
                u.realname || '' '' || u.firstname AS proprietaire,
                s.name AS etat, l.completename AS localisation
         FROM computers c
         JOIN entities e ON c.entities_id = e.id
         LEFT JOIN users u ON c.users_id = u.id
         LEFT JOIN states s ON c.states_id = s.id
         LEFT JOIN locations l ON c.locations_id = l.id
         WHERE e.site_code = ''CERGY''');

    SP_BENCHMARK_QUERY('Q3', 'Statistiques VLAN agregees', 'AVEC_INDEX',
        'SELECT v.name, v.tag, e.name,
                COUNT(npv.id) AS nb_ports,
                COUNT(DISTINCT np.computers_id) AS nb_computers
         FROM vlans v
         JOIN entities e ON v.entities_id = e.id
         LEFT JOIN network_port_vlans npv ON v.id = npv.vlans_id
         LEFT JOIN network_ports np ON npv.network_ports_id = np.id
         GROUP BY v.name, v.tag, e.name');

    SP_BENCHMARK_QUERY('Q4', 'Recherche par serial (UPPER)', 'AVEC_INDEX',
        'SELECT c.id, c.name, c.serial, e.name AS entite
         FROM computers c JOIN entities e ON c.entities_id = e.id
         WHERE UPPER(c.serial) = ''SN-CERGY-00042''');

    SP_BENCHMARK_QUERY('Q5', 'Vue inventaire complet par site', 'AVEC_INDEX',
        'SELECT type_materiel, COUNT(*) AS nombre
         FROM V_INVENTAIRE_COMPLET
         WHERE site = ''CERGY''
         GROUP BY type_materiel');

    SP_BENCHMARK_QUERY('Q6', 'Utilisateurs avec profils', 'AVEC_INDEX',
        'SELECT u.name, u.realname || '' '' || u.firstname AS nom,
                p.name AS profil, e.name AS entite, e.site_code
         FROM users u
         JOIN profiles_users pu ON u.id = pu.users_id
         JOIN profiles p ON pu.profiles_id = p.id
         JOIN entities e ON pu.entities_id = e.id
         WHERE u.is_active = 1');

    SP_BENCHMARK_QUERY('Q7', 'Materiel par fabricant et site', 'AVEC_INDEX',
        'SELECT m.name AS fabricant, e.site_code, COUNT(*) AS nb
         FROM computers c
         JOIN entities e ON c.entities_id = e.id
         JOIN manufacturers m ON c.manufacturers_id = m.id
         GROUP BY m.name, e.site_code
         ORDER BY nb DESC');

    SP_BENCHMARK_QUERY('Q8', 'Topologie reseau complete', 'AVEC_INDEX',
        'SELECT port_id, nom_port, mac, type_port, equipement,
                type_equipement, entite, site, vlan_name, adresse_ip
         FROM V_TOPOLOGIE_RESEAU
         WHERE site = ''CERGY''');

    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('  FIN SCENARIO B');
    DBMS_OUTPUT.PUT_LINE('============================================');
END SP_RUN_BENCHMARK_AVEC_INDEX;
/

-- =========================
-- PROCEDURE PRINCIPALE DE BENCHMARK
-- =========================

CREATE OR REPLACE PROCEDURE SP_RUN_FULL_BENCHMARK
AS
BEGIN
    -- Nettoyer les resultats precedents
    DELETE FROM benchmark_results;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('####################################################');
    DBMS_OUTPUT.PUT_LINE('#   BENCHMARK COMPLET — NOUVELLE BDD GLPI          #');
    DBMS_OUTPUT.PUT_LINE('#   ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') ||
                         '                            #');
    DBMS_OUTPUT.PUT_LINE('####################################################');
    DBMS_OUTPUT.PUT_LINE('');

    -- Scenario A : sans index
    SP_RUN_BENCHMARK_SANS_INDEX;

    -- Pause entre les deux scenarios
    DBMS_SESSION.SLEEP(2);

    -- Scenario B : avec index
    SP_RUN_BENCHMARK_AVEC_INDEX;

    -- Afficher le resume comparatif
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('####################################################');
    DBMS_OUTPUT.PUT_LINE('#   RESUME COMPARATIF                              #');
    DBMS_OUTPUT.PUT_LINE('####################################################');
    DBMS_OUTPUT.PUT_LINE('');

    FOR rec IN (
        SELECT a.query_id,
               a.query_desc,
               a.execution_ms AS ms_sans,
               b.execution_ms AS ms_avec,
               ROUND(((a.execution_ms - b.execution_ms) / NULLIF(a.execution_ms, 0)) * 100, 1) AS gain_pct,
               a.rows_returned
        FROM benchmark_results a
        JOIN benchmark_results b ON a.query_id = b.query_id
        WHERE a.scenario = 'SANS_INDEX'
          AND b.scenario = 'AVEC_INDEX'
        ORDER BY a.query_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.query_id, 5) || ' | ' ||
            RPAD(rec.query_desc, 35) || ' | ' ||
            LPAD(rec.ms_sans, 8) || ' ms -> ' ||
            LPAD(rec.ms_avec, 8) || ' ms | ' ||
            CASE WHEN rec.gain_pct > 0
                 THEN '+' || rec.gain_pct || '%'
                 ELSE rec.gain_pct || '%'
            END || ' | ' ||
            rec.rows_returned || ' rows'
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('####################################################');
END SP_RUN_FULL_BENCHMARK;
/

-- =========================
-- EXPORT DES RESULTATS EN FORMAT CSV
-- =========================

CREATE OR REPLACE PROCEDURE SP_EXPORT_BENCHMARK_CSV
AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('query_id,query_desc,scenario,execution_ms,rows_returned,run_date');
    FOR rec IN (
        SELECT query_id, query_desc, scenario, execution_ms, rows_returned,
               TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI:SS') AS run_dt
        FROM benchmark_results
        ORDER BY query_id, scenario
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            rec.query_id || ',' ||
            '"' || rec.query_desc || '",' ||
            rec.scenario || ',' ||
            rec.execution_ms || ',' ||
            rec.rows_returned || ',' ||
            rec.run_dt
        );
    END LOOP;
END SP_EXPORT_BENCHMARK_CSV;
/

-- =========================
-- EXECUTION
-- =========================
-- SET SERVEROUTPUT ON SIZE UNLIMITED
-- EXEC SP_GENERER_JEU_DE_TEST;   -- d'abord generer les donnees
-- EXEC SP_RUN_FULL_BENCHMARK;     -- puis lancer le benchmark
-- EXEC SP_EXPORT_BENCHMARK_CSV;   -- exporter en CSV si besoin
