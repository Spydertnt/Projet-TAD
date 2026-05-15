-- ============================================================
-- procedures.sql
-- Procedures stockees PL/SQL - Schema simplifie
-- Oracle XE
-- ============================================================

CREATE OR REPLACE PROCEDURE SP_TRANSFERT_MATERIEL (
    p_asset_id      IN NUMBER,
    p_new_entity_id IN NUMBER,
    p_new_user_id   IN NUMBER DEFAULT NULL
)
AS
    v_old_entity NUMBER;
    v_old_site VARCHAR2(10);
    v_new_site VARCHAR2(10);
    v_asset_name VARCHAR2(255);
    v_db_link VARCHAR2(30);
    v_remote_count NUMBER;
BEGIN
    SELECT entities_id, name
    INTO v_old_entity, v_asset_name
    FROM assets
    WHERE id = p_asset_id;

    SELECT site_code INTO v_old_site FROM entities WHERE id = v_old_entity;
    SELECT site_code INTO v_new_site FROM entities WHERE id = p_new_entity_id;

    IF v_old_site = v_new_site THEN
        UPDATE assets
        SET entities_id = p_new_entity_id,
            users_id = NVL(p_new_user_id, users_id),
            date_mod = SYSTIMESTAMP
        WHERE id = p_asset_id;

        UPDATE network_ports
        SET entities_id = p_new_entity_id,
            date_mod = SYSTIMESTAMP
        WHERE assets_id = p_asset_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Transfert local reussi: ' || v_asset_name);
        RETURN;
    END IF;

    IF v_new_site = 'PAU' THEN
        v_db_link := 'DBL_PAU';
    ELSIF v_new_site = 'CERGY' THEN
        v_db_link := 'DBL_CERGY';
    ELSE
        RAISE_APPLICATION_ERROR(-20012, 'Site destination non supporte');
    END IF;

    EXECUTE IMMEDIATE
        'SELECT COUNT(*) FROM assets@' || v_db_link || ' WHERE id = :asset_id'
        INTO v_remote_count
        USING p_asset_id;

    IF v_remote_count = 0 THEN
        EXECUTE IMMEDIATE
            'INSERT INTO assets@' || v_db_link || ' (
                id, entities_id, category, name, serial, inventory_tag, uuid,
                users_id, users_id_tech, locations_id, asset_models_id,
                manufacturers_id, states_id, networks_id, notes, date_creation, date_mod
            )
            SELECT
                id, :new_entity_id, category, name, serial, inventory_tag, uuid,
                NVL(:new_user_id, users_id), users_id_tech, locations_id, asset_models_id,
                manufacturers_id, states_id, networks_id, notes, date_creation, SYSTIMESTAMP
            FROM assets
            WHERE id = :asset_id'
            USING p_new_entity_id, p_new_user_id, p_asset_id;
    ELSE
        EXECUTE IMMEDIATE
            'UPDATE assets@' || v_db_link || '
             SET entities_id = :new_entity_id,
                 users_id = NVL(:new_user_id, users_id),
                 date_mod = SYSTIMESTAMP
             WHERE id = :asset_id'
            USING p_new_entity_id, p_new_user_id, p_asset_id;
    END IF;

    EXECUTE IMMEDIATE
        'DELETE FROM network_ports@' || v_db_link || ' WHERE assets_id = :asset_id'
        USING p_asset_id;

    EXECUTE IMMEDIATE
        'INSERT INTO network_ports@' || v_db_link || ' (
            id, entities_id, assets_id, name, mac, port_type, logical_number,
            date_creation, date_mod
        )
        SELECT
            id, :new_entity_id, assets_id, name, mac, port_type, logical_number,
            date_creation, SYSTIMESTAMP
        FROM network_ports
        WHERE assets_id = :asset_id'
        USING p_new_entity_id, p_asset_id;

    DELETE FROM network_ports WHERE assets_id = p_asset_id;
    DELETE FROM assets WHERE id = p_asset_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Transfert inter-sites reussi: ' || v_asset_name);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20010, 'Materiel ou entite introuvable');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20011, 'Erreur lors du transfert: ' || SQLERRM);
END SP_TRANSFERT_MATERIEL;
/

CREATE OR REPLACE PROCEDURE SP_AFFECTER_PROFIL (
    p_user_id IN NUMBER,
    p_profile_id IN NUMBER,
    p_entity_id IN NUMBER,
    p_is_recursive IN NUMBER DEFAULT 0
)
AS
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists
    FROM profiles_users
    WHERE users_id = p_user_id
      AND profiles_id = p_profile_id
      AND entities_id = p_entity_id;

    IF v_exists > 0 THEN
        UPDATE profiles_users
        SET is_recursive = p_is_recursive
        WHERE users_id = p_user_id
          AND profiles_id = p_profile_id
          AND entities_id = p_entity_id;
    ELSE
        INSERT INTO profiles_users (users_id, profiles_id, entities_id, is_recursive)
        VALUES (p_user_id, p_profile_id, p_entity_id, p_is_recursive);
    END IF;

    COMMIT;
END SP_AFFECTER_PROFIL;
/

CREATE OR REPLACE PROCEDURE SP_CREER_TICKET_MATERIEL (
    p_entity_id IN NUMBER,
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
      AND entities_id = p_entity_id;

    IF v_asset_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20051, 'Materiel introuvable dans l''entite indiquee');
    END IF;

    INSERT INTO tickets (
        entities_id, assets_id, title, description, priority,
        requester_users_id, ticket_categories_id, assigned_groups_id,
        status, date_assigned
    )
    VALUES (
        p_entity_id, p_asset_id, p_title, p_description, UPPER(p_priority),
        p_requester_id, p_category_id, p_assigned_group_id,
        CASE WHEN p_assigned_group_id IS NULL AND p_assigned_user_id IS NULL THEN 'NOUVEAU' ELSE 'ASSIGNE' END,
        CASE WHEN p_assigned_group_id IS NULL AND p_assigned_user_id IS NULL THEN NULL ELSE SYSTIMESTAMP END
    )
    RETURNING id INTO p_ticket_id;

    IF p_assigned_user_id IS NOT NULL THEN
        INSERT INTO ticket_users (tickets_id, users_id, assigned_by)
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
    INSERT INTO ticket_users (tickets_id, users_id, assigned_by)
    VALUES (p_ticket_id, p_user_id, p_assigned_by);

    UPDATE tickets
    SET status = CASE WHEN status = 'NOUVEAU' THEN 'ASSIGNE' ELSE status END,
        date_assigned = NVL(date_assigned, SYSTIMESTAMP)
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
    FROM assets a JOIN entities e ON a.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_users
    FROM users u JOIN entities e ON u.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_ports
    FROM network_ports np JOIN entities e ON np.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_tickets
    FROM tickets t JOIN entities e ON t.entities_id = e.id
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
    WHERE archive_date < v_date_limite;

    DBMS_OUTPUT.PUT_LINE(SQL%ROWCOUNT || ' archives supprimees.');
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20030, 'Erreur purge archives: ' || SQLERRM);
END SP_NETTOYER_ARCHIVES;
/
