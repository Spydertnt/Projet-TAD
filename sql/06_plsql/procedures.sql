-- ============================================================
-- procedures.sql
-- Procedures stockees PL/SQL - Schema simplifie
-- Oracle XE
-- ============================================================

CREATE OR REPLACE PROCEDURE SP_TRANSFERT_MATERIEL (
    p_asset_id      IN NUMBER,
    p_new_site_id IN NUMBER,
    p_new_user_id   IN NUMBER DEFAULT NULL
)
AS
    v_old_site_id NUMBER;
    v_old_site VARCHAR2(10);
    v_new_site VARCHAR2(10);
    v_asset_name VARCHAR2(255);
BEGIN
    SELECT site_id, name
    INTO v_old_site_id, v_asset_name
    FROM assets
    WHERE id = p_asset_id;

    SELECT site_code INTO v_old_site FROM sites WHERE id = v_old_site_id;
    SELECT site_code INTO v_new_site FROM sites WHERE id = p_new_site_id;

    IF v_new_site NOT IN ('CERGY', 'PAU') THEN
        RAISE_APPLICATION_ERROR(-20012, 'Site destination non supporte');
    END IF;

    UPDATE assets
    SET site_id = p_new_site_id,
        owner_user_id = NVL(p_new_user_id, owner_user_id),
        updated_at = SYSTIMESTAMP
    WHERE id = p_asset_id;

    UPDATE network_ports
    SET site_id = p_new_site_id,
        updated_at = SYSTIMESTAMP
    WHERE asset_id = p_asset_id;

    UPDATE ip_addresses
    SET site_id = p_new_site_id,
        updated_at = SYSTIMESTAMP
    WHERE network_port_id IN (
        SELECT id
        FROM network_ports
        WHERE asset_id = p_asset_id
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Transfert inter-sites simule reussi: ' || v_asset_name ||
                         ' (' || v_old_site || ' -> ' || v_new_site || ')');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20010, 'Materiel ou site introuvable');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20011, 'Erreur lors du transfert: ' || SQLERRM);
END SP_TRANSFERT_MATERIEL;
/

CREATE OR REPLACE PROCEDURE SP_AFFECTER_PROFIL (
    p_user_id IN NUMBER,
    p_profile_id IN NUMBER,
    p_site_id IN NUMBER,
    p_is_recursive IN NUMBER DEFAULT 0
)
AS
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists
    FROM profiles_users
    WHERE user_id = p_user_id
      AND profile_id = p_profile_id
      AND site_id = p_site_id;

    IF v_exists > 0 THEN
        UPDATE profiles_users
        SET is_recursive = p_is_recursive
        WHERE user_id = p_user_id
          AND profile_id = p_profile_id
          AND site_id = p_site_id;
    ELSE
        INSERT INTO profiles_users (user_id, profile_id, site_id, is_recursive)
        VALUES (p_user_id, p_profile_id, p_site_id, p_is_recursive);
    END IF;

    COMMIT;
END SP_AFFECTER_PROFIL;
/

CREATE OR REPLACE PROCEDURE SP_CREER_TICKET_MATERIEL (
    p_site_id IN NUMBER,
    p_requester_id IN NUMBER,
    p_title IN VARCHAR2,
    p_description IN CLOB,
    p_asset_id IN NUMBER,
    p_priority IN VARCHAR2 DEFAULT 'MOYENNE',
    p_category_id IN NUMBER DEFAULT NULL,
    p_assigned_group_id IN NUMBER DEFAULT NULL,
    p_assigned_user_id IN NUMBER DEFAULT NULL,
    p_ticket_id OUT NUMBER
)
AS
    v_asset_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_asset_count
    FROM assets
    WHERE id = p_asset_id
      AND site_id = p_site_id;

    IF v_asset_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20051, 'Materiel introuvable dans le site indique');
    END IF;

    INSERT INTO tickets (
        site_id, asset_id, title, description, priority,
        requester_user_id, category_id, assigned_group_id,
        status, assigned_at
    )
    VALUES (
        p_site_id, p_asset_id, p_title, p_description, UPPER(p_priority),
        p_requester_id, p_category_id, p_assigned_group_id,
        CASE WHEN p_assigned_group_id IS NULL AND p_assigned_user_id IS NULL THEN 'NOUVEAU' ELSE 'ASSIGNE' END,
        CASE WHEN p_assigned_group_id IS NULL AND p_assigned_user_id IS NULL THEN NULL ELSE SYSTIMESTAMP END
    )
    RETURNING id INTO p_ticket_id;

    IF p_assigned_user_id IS NOT NULL THEN
        INSERT INTO ticket_users (ticket_id, user_id, assigned_by_user_id)
        VALUES (p_ticket_id, p_assigned_user_id, p_requester_id);
    END IF;

    COMMIT;
END SP_CREER_TICKET_MATERIEL;
/

GRANT EXECUTE ON SP_CREER_TICKET_MATERIEL
    TO ROLE_TECHNICIEN, ROLE_MANAGER_SITE, ROLE_ADMIN;

CREATE OR REPLACE PROCEDURE SP_ASSIGNER_TECH_TICKET (
    p_ticket_id IN NUMBER,
    p_user_id IN NUMBER,
    p_assigned_by IN NUMBER DEFAULT NULL
)
AS
BEGIN
    INSERT INTO ticket_users (ticket_id, user_id, assigned_by_user_id)
    VALUES (p_ticket_id, p_user_id, p_assigned_by);

    UPDATE tickets
    SET status = CASE WHEN status = 'NOUVEAU' THEN 'ASSIGNE' ELSE status END,
        assigned_at = NVL(assigned_at, SYSTIMESTAMP)
    WHERE id = p_ticket_id;

    COMMIT;
END SP_ASSIGNER_TECH_TICKET;
/

GRANT EXECUTE ON SP_ASSIGNER_TECH_TICKET
    TO ROLE_TECHNICIEN, ROLE_MANAGER_SITE, ROLE_ADMIN;

CREATE OR REPLACE PROCEDURE SP_INVENTAIRE_SITE (
    p_site_code IN VARCHAR2
)
AS
    v_nb_assets NUMBER;
    v_nb_users NUMBER;
    v_nb_ports NUMBER;
    v_nb_tickets NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_nb_assets
    FROM assets a JOIN sites e ON a.site_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_users
    FROM users u JOIN sites e ON u.site_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_ports
    FROM network_ports np JOIN sites e ON np.site_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_tickets
    FROM tickets t JOIN sites e ON t.site_id = e.id
    WHERE e.site_code = p_site_code;

    DBMS_OUTPUT.PUT_LINE('Inventaire site ' || p_site_code);
    DBMS_OUTPUT.PUT_LINE('Materiels : ' || v_nb_assets);
    DBMS_OUTPUT.PUT_LINE('Utilisateurs : ' || v_nb_users);
    DBMS_OUTPUT.PUT_LINE('Ports reseau : ' || v_nb_ports);
    DBMS_OUTPUT.PUT_LINE('Tickets : ' || v_nb_tickets);
END SP_INVENTAIRE_SITE;
/

CREATE OR REPLACE PROCEDURE SP_NETTOYER_ARCHIVES (
    p_nb_mois IN NUMBER DEFAULT 12
)
AS
    v_date_limite TIMESTAMP;
BEGIN
    v_date_limite := SYSTIMESTAMP - NUMTOYMINTERVAL(p_nb_mois, 'MONTH');

    DELETE FROM archives_materiel
    WHERE archived_at < v_date_limite;

    DBMS_OUTPUT.PUT_LINE(SQL%ROWCOUNT || ' archives supprimees.');
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20030, 'Erreur purge archives: ' || SQLERRM);
END SP_NETTOYER_ARCHIVES;
/
