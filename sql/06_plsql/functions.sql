-- ============================================================
-- functions.sql
-- Fonctions PL/SQL - Schema simplifie
-- Oracle XE
-- ============================================================

CREATE OR REPLACE FUNCTION FN_COMPTER_MATERIEL_SITE (
    p_site_code IN VARCHAR2
) RETURN NUMBER
AS
    v_total NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_total
    FROM assets a
        JOIN sites e ON a.site_id = e.id
    WHERE e.site_code = p_site_code;

    RETURN v_total;
EXCEPTION
    WHEN OTHERS THEN
        RETURN -1;
END FN_COMPTER_MATERIEL_SITE;
/

CREATE OR REPLACE FUNCTION FN_CALCULER_TAUX_UTILISATION (
    p_asset_id IN NUMBER
) RETURN NUMBER
AS
    v_total_ports NUMBER;
    v_ports_adresses NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_total_ports
    FROM network_ports
    WHERE asset_id = p_asset_id;

    IF v_total_ports = 0 THEN
        RETURN 0;
    END IF;

    SELECT COUNT(DISTINCT np.id) INTO v_ports_adresses
    FROM network_ports np
        JOIN ip_addresses ia ON ia.network_port_id = np.id
    WHERE np.asset_id = p_asset_id
      AND ia.ip_address IS NOT NULL;

    RETURN ROUND((v_ports_adresses / v_total_ports) * 100, 2);
EXCEPTION
    WHEN OTHERS THEN
        RETURN -1;
END FN_CALCULER_TAUX_UTILISATION;
/

CREATE OR REPLACE FUNCTION FN_OBTENIR_SITE_ENTITE (
    p_site_id IN NUMBER
) RETURN VARCHAR2
AS
    v_site_code VARCHAR2(10);
    v_current_id NUMBER := p_site_id;
    v_parent_id NUMBER;
    v_max_depth NUMBER := 10;
BEGIN
    WHILE v_current_id IS NOT NULL AND v_max_depth > 0 LOOP
        SELECT site_code, parent_site_id
        INTO v_site_code, v_parent_id
        FROM sites
        WHERE id = v_current_id;

        IF v_site_code IS NOT NULL THEN
            RETURN v_site_code;
        END IF;

        v_current_id := v_parent_id;
        v_max_depth := v_max_depth - 1;
    END LOOP;

    RETURN 'INCONNU';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'INCONNU';
    WHEN OTHERS THEN
        RETURN 'ERREUR';
END FN_OBTENIR_SITE_ENTITE;
/

CREATE OR REPLACE FUNCTION FN_VERIFIER_QUOTA_MATERIEL (
    p_site_code IN VARCHAR2,
    p_quota_max IN NUMBER DEFAULT 5000
) RETURN NUMBER
AS
    v_total NUMBER;
BEGIN
    v_total := FN_COMPTER_MATERIEL_SITE(p_site_code);

    IF v_total < 0 THEN
        RETURN -1;
    ELSIF v_total >= p_quota_max THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END FN_VERIFIER_QUOTA_MATERIEL;
/
