-- ============================================================
-- 08_query_plans.sql
-- Analyse des Plans d'Exécution — Optimisation des requêtes
-- Oracle XE
-- ============================================================

-- =========================
-- REQUÊTE 1 : Recherche d'un matériel par nom (SANS index fonctionnel)
-- =========================

-- D'abord, désactiver l'index pour montrer la différence
-- ALTER INDEX idx_comp_name_upper INVISIBLE;

EXPLAIN PLAN SET STATEMENT_ID = 'Q1_SEARCH_NAME' FOR
SELECT c.id, c.name, c.serial, e.name AS entite, m.name AS fabricant
FROM computers c
    JOIN entities e ON c.entities_id = e.id
    LEFT JOIN manufacturers m ON c.manufacturers_id = m.id
WHERE UPPER(c.name) = 'PC-CERGY-001';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    NULL, 'Q1_SEARCH_NAME', 'ALL'));

-- Après : réactiver l'index et relancer pour comparer
-- ALTER INDEX idx_comp_name_upper VISIBLE;

-- =========================
-- REQUÊTE 2 : Liste des matériels d'un site avec utilisateur
-- Requête fréquente — devrait utiliser l'index composite
-- =========================

EXPLAIN PLAN SET STATEMENT_ID = 'Q2_SITE_ASSETS' FOR
SELECT c.name, c.serial,
       u.realname || ' ' || u.firstname AS proprietaire,
       s.name AS etat,
       l.completename AS localisation
FROM computers c
    JOIN entities e ON c.entities_id = e.id
    LEFT JOIN users u ON c.users_id = u.id
    LEFT JOIN states s ON c.states_id = s.id
    LEFT JOIN locations l ON c.locations_id = l.id
WHERE e.site_code = 'CERGY'
ORDER BY c.name;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    NULL, 'Q2_SITE_ASSETS', 'ALL'));

-- =========================
-- REQUÊTE 3 : Statistiques réseau par VLAN
-- Requête agrégée avec jointures multiples
-- =========================

EXPLAIN PLAN SET STATEMENT_ID = 'Q3_VLAN_STATS' FOR
SELECT v.name AS vlan_name, v.tag,
       e.name AS entite,
       COUNT(npv.id) AS nb_ports,
       COUNT(DISTINCT np.computers_id) AS nb_computers,
       COUNT(DISTINCT np.network_equipments_id) AS nb_equip_reseau
FROM vlans v
    JOIN entities e ON v.entities_id = e.id
    LEFT JOIN network_port_vlans npv ON v.id = npv.vlans_id
    LEFT JOIN network_ports np ON npv.network_ports_id = np.id
GROUP BY v.name, v.tag, e.name
ORDER BY v.tag;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    NULL, 'Q3_VLAN_STATS', 'ALL'));

-- =========================
-- REQUÊTE 4 : Recherche par numéro de série (index fonctionnel)
-- =========================

EXPLAIN PLAN SET STATEMENT_ID = 'Q4_SEARCH_SERIAL' FOR
SELECT c.id, c.name, c.serial, e.name AS entite
FROM computers c
    JOIN entities e ON c.entities_id = e.id
WHERE UPPER(c.serial) = 'SN-2026-00042';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    NULL, 'Q4_SEARCH_SERIAL', 'ALL'));

-- =========================
-- REQUÊTE 5 : Inventaire complet multi-tables (via la vue)
-- Mesure du coût de la vue V_INVENTAIRE_COMPLET
-- =========================

EXPLAIN PLAN SET STATEMENT_ID = 'Q5_VIEW_INVENTAIRE' FOR
SELECT type_materiel, COUNT(*) AS nombre
FROM V_INVENTAIRE_COMPLET
WHERE site = 'CERGY'
GROUP BY type_materiel
ORDER BY nombre DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    NULL, 'Q5_VIEW_INVENTAIRE', 'ALL'));

-- =========================
-- REQUÊTE 6 : Jointure complexe utilisateurs-profils-entités
-- =========================

EXPLAIN PLAN SET STATEMENT_ID = 'Q6_USER_PROFILES' FOR
SELECT u.name AS login,
       u.realname || ' ' || u.firstname AS nom,
       p.name AS profil,
       e.name AS entite_profil,
       e.site_code
FROM users u
    JOIN profiles_users pu ON u.id = pu.users_id
    JOIN profiles p ON pu.profiles_id = p.id
    JOIN entities e ON pu.entities_id = e.id
WHERE u.is_active = 1
ORDER BY e.site_code, u.realname;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    NULL, 'Q6_USER_PROFILES', 'ALL'));

-- =========================
-- REQUÊTE 7 : Requête distribuée (cross-site via DB Link)
-- Coût d'une requête fédérée
-- =========================

-- EXPLAIN PLAN SET STATEMENT_ID = 'Q7_DISTRIBUTED' FOR
-- SELECT c.name, c.serial, 'CERGY' AS site
-- FROM computers c
--     JOIN entities e ON c.entities_id = e.id
-- WHERE e.site_code = 'CERGY'
-- UNION ALL
-- SELECT c.name, c.serial, 'PAU' AS site
-- FROM computers@DBL_PAU c
--     JOIN entities@DBL_PAU e ON c.entities_id = e.id
-- WHERE e.site_code = 'PAU';
--
-- SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
--     NULL, 'Q7_DISTRIBUTED', 'ALL'));

-- =========================
-- COMPARAISON AVANT/APRÈS INDEX
-- =========================

-- Étape 1 : Rendre les index invisibles
-- ALTER INDEX idx_comp_entity INVISIBLE;
-- ALTER INDEX idx_comp_entity_state INVISIBLE;
-- ALTER INDEX idx_comp_name_upper INVISIBLE;

-- Étape 2 : Exécuter les requêtes Q1, Q2 et noter le coût
-- (full table scan attendu)

-- Étape 3 : Rendre les index visibles
-- ALTER INDEX idx_comp_entity VISIBLE;
-- ALTER INDEX idx_comp_entity_state VISIBLE;
-- ALTER INDEX idx_comp_name_upper VISIBLE;

-- Étape 4 : Relancer les mêmes requêtes et comparer
-- (index scan attendu → coût réduit)

-- =========================
-- RÉSUMÉ DES MÉTRIQUES À OBSERVER
-- =========================
-- | Métrique          | Description                              |
-- |--------------------|------------------------------------------|
-- | Cost               | Coût estimé par l'optimiseur             |
-- | Rows               | Nombre de lignes estimées                |
-- | Bytes              | Volume de données estimé                 |
-- | Operation          | TABLE ACCESS FULL vs INDEX RANGE SCAN    |
-- | Predicate Info     | Filtres et conditions de jointure        |
-- | Time               | Temps estimé d'exécution                 |
