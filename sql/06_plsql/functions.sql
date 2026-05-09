-- ============================================================
-- functions.sql
-- Fonctions PL/SQL
-- Oracle XE
-- ============================================================

-- =========================
-- FN_COMPTER_MATERIEL_SITE
-- Retourne le nombre total de matériels d'un site
-- =========================

CREATE OR REPLACE FUNCTION FN_COMPTER_MATERIEL_SITE (
    p_site_code IN VARCHAR2
) RETURN NUMBER
AS
    v_total NUMBER := 0;
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM computers c JOIN entities e ON c.entities_id = e.id
    WHERE e.site_code = p_site_code;
    v_total := v_total + v_count;

    SELECT COUNT(*) INTO v_count
    FROM monitors m JOIN entities e ON m.entities_id = e.id
    WHERE e.site_code = p_site_code;
    v_total := v_total + v_count;

    SELECT COUNT(*) INTO v_count
    FROM peripherals p JOIN entities e ON p.entities_id = e.id
    WHERE e.site_code = p_site_code;
    v_total := v_total + v_count;

    SELECT COUNT(*) INTO v_count
    FROM printers p JOIN entities e ON p.entities_id = e.id
    WHERE e.site_code = p_site_code;
    v_total := v_total + v_count;

    SELECT COUNT(*) INTO v_count
    FROM phones p JOIN entities e ON p.entities_id = e.id
    WHERE e.site_code = p_site_code;
    v_total := v_total + v_count;

    SELECT COUNT(*) INTO v_count
    FROM network_equipments n JOIN entities e ON n.entities_id = e.id
    WHERE e.site_code = p_site_code;
    v_total := v_total + v_count;

    RETURN v_total;
EXCEPTION
    WHEN OTHERS THEN
        RETURN -1;
END FN_COMPTER_MATERIEL_SITE;
/

-- Exemple d'utilisation dans une requête SQL :
-- SELECT FN_COMPTER_MATERIEL_SITE('CERGY') AS total_cergy FROM DUAL;
-- SELECT FN_COMPTER_MATERIEL_SITE('PAU') AS total_pau FROM DUAL;

-- =========================
-- FN_CALCULER_TAUX_UTILISATION
-- Calcule le taux d'utilisation des ports réseau d'un équipement
-- Retourne un pourcentage (0-100)
-- =========================

CREATE OR REPLACE FUNCTION FN_CALCULER_TAUX_UTILISATION (
    p_equipment_id IN NUMBER
) RETURN NUMBER
AS
    v_total_ports   NUMBER;
    v_ports_connectes NUMBER;
BEGIN
    -- Compter le nombre total de ports de l'équipement
    SELECT COUNT(*) INTO v_total_ports
    FROM network_ports
    WHERE network_equipments_id = p_equipment_id;

    IF v_total_ports = 0 THEN
        RETURN 0;
    END IF;

    -- Compter les ports qui ont une connexion
    SELECT COUNT(*) INTO v_ports_connectes
    FROM network_ports np
    WHERE np.network_equipments_id = p_equipment_id
      AND (
          EXISTS (SELECT 1 FROM network_connections nc
                  WHERE nc.network_ports_id_1 = np.id)
          OR
          EXISTS (SELECT 1 FROM network_connections nc
                  WHERE nc.network_ports_id_2 = np.id)
      );

    RETURN ROUND((v_ports_connectes / v_total_ports) * 100, 2);
EXCEPTION
    WHEN OTHERS THEN
        RETURN -1;
END FN_CALCULER_TAUX_UTILISATION;
/

-- Exemple d'utilisation :
-- SELECT ne.name, FN_CALCULER_TAUX_UTILISATION(ne.id) AS taux_pct
-- FROM network_equipments ne;

-- =========================
-- FN_OBTENIR_SITE_MATERIEL
-- Retourne le code site d'un matériel à partir de son entities_id
-- =========================

CREATE OR REPLACE FUNCTION FN_OBTENIR_SITE_MATERIEL (
    p_entities_id IN NUMBER
) RETURN VARCHAR2
AS
    v_site_code VARCHAR2(10);
    v_current_id NUMBER := p_entities_id;
    v_max_depth NUMBER := 10;  -- Protection contre boucle infinie
BEGIN
    -- Remonter la hiérarchie des entités jusqu'à trouver un site_code
    WHILE v_current_id IS NOT NULL AND v_max_depth > 0 LOOP
        SELECT site_code, entities_id
        INTO v_site_code, v_current_id
        FROM entities
        WHERE id = v_current_id;

        IF v_site_code IS NOT NULL THEN
            RETURN v_site_code;
        END IF;

        v_max_depth := v_max_depth - 1;
    END LOOP;

    RETURN 'INCONNU';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'INCONNU';
    WHEN OTHERS THEN
        RETURN 'ERREUR';
END FN_OBTENIR_SITE_MATERIEL;
/

-- Exemple d'utilisation :
-- SELECT c.name, FN_OBTENIR_SITE_MATERIEL(c.entities_id) AS site
-- FROM computers c;

-- =========================
-- FN_VERIFIER_QUOTA_MATERIEL
-- Vérifie si un site a dépassé son quota de matériels
-- Retourne 1 si quota dépassé, 0 sinon
-- =========================

CREATE OR REPLACE FUNCTION FN_VERIFIER_QUOTA_MATERIEL (
    p_site_code     IN VARCHAR2,
    p_quota_max     IN NUMBER DEFAULT 5000
) RETURN NUMBER
AS
    v_total NUMBER;
BEGIN
    v_total := FN_COMPTER_MATERIEL_SITE(p_site_code);

    IF v_total < 0 THEN
        RETURN -1;  -- Erreur
    ELSIF v_total >= p_quota_max THEN
        DBMS_OUTPUT.PUT_LINE('ALERTE: Le site ' || p_site_code ||
            ' a atteint son quota (' || v_total || '/' || p_quota_max || ')');
        RETURN 1;  -- Quota dépassé
    ELSE
        DBMS_OUTPUT.PUT_LINE('OK: Le site ' || p_site_code ||
            ' utilise ' || v_total || '/' || p_quota_max || ' matériels');
        RETURN 0;  -- Quota OK
    END IF;
END FN_VERIFIER_QUOTA_MATERIEL;
/

-- Exemple d'utilisation :
-- SELECT FN_VERIFIER_QUOTA_MATERIEL('CERGY', 1000) FROM DUAL;
