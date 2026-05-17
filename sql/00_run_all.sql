-- ============================================================
-- 00_run_all.sql
-- Lancement simple de tous les scripts du projet
-- ============================================================

-- A lancer depuis SQL*Plus avec SYSTEM :
-- CONNECT system/mot_de_passe@localhost:1521/XE
-- START H:\Desktop\S4\Administration_et_traitement_des_donnees\Projet-TAD\sql\00_run_all.sql

-- Mots de passe utilises par 03_users_roles.sql
DEFINE ADMIN_GLPI_PASSWORD = admin123
DEFINE TECH_CERGY_PASSWORD = techcergy123
DEFINE TECH_PAU_PASSWORD = techpau123
DEFINE CONSULTANT_PASSWORD = consultant123
DEFINE MANAGER_CERGY_PASSWORD = managercergy123
DEFINE MANAGER_PAU_PASSWORD = managerpau123/

START H:\Documents\BDD\ING2\Projet-TAD\sql\01_tablespaces.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\02_schema_tables.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\04_clusters_indexes.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\03_users_roles.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\05_views.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\06_plsql\triggers.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\06_plsql\procedures.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\06_plsql\functions.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\06_plsql\cursors.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\09_test_data.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\08_query_plans.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\10_benchmark.sql
START H:\Documents\BDD\ING2\Projet-TAD\sql\07_bddr.sql
CONNECT system/7z9kz8ee@localhost:1521/XE

-- A lancer a part si tu veux activer la simulation BDDR avec DB links locaux :
-- START H:\Documents\BDD\ING2\Projet-TAD\sql\07_bddr.sql
