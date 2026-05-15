-- ============================================================
-- triggers.sql
-- Triggers PL/SQL - Schema simplifie
-- Oracle XE
-- ============================================================

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_ASSETS
BEFORE UPDATE ON assets
FOR EACH ROW
BEGIN
    :NEW.date_mod := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_USERS
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    :NEW.date_mod := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_NETPORTS
BEFORE UPDATE ON network_ports
FOR EACH ROW
BEGIN
    :NEW.date_mod := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_TICKETS
BEFORE UPDATE ON tickets
FOR EACH ROW
BEGIN
    :NEW.date_mod := SYSTIMESTAMP;

    IF :OLD.status = 'NOUVEAU'
       AND :NEW.status IN ('ASSIGNE', 'EN_COURS')
       AND :NEW.date_assigned IS NULL THEN
        :NEW.date_assigned := SYSTIMESTAMP;
    END IF;

    IF :OLD.status != 'RESOLU'
       AND :NEW.status = 'RESOLU'
       AND :NEW.date_resolved IS NULL THEN
        :NEW.date_resolved := SYSTIMESTAMP;
    END IF;

    IF :OLD.status != 'CLOS'
       AND :NEW.status = 'CLOS'
       AND :NEW.date_closed IS NULL THEN
        :NEW.date_closed := SYSTIMESTAMP;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_CHECK_TICKET_USER_TECH
BEFORE INSERT OR UPDATE ON ticket_users
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM profiles_users pu
        JOIN profiles p ON pu.profiles_id = p.id
        JOIN tickets t ON t.id = :NEW.tickets_id
    WHERE pu.users_id = :NEW.users_id
      AND p.name = 'Technicien'
      AND (pu.entities_id = t.entities_id OR pu.is_recursive = 1);

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20060,
            'Un ticket ne peut etre assigne qu''a un utilisateur avec le profil Technicien');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_AUDIT_ASSETS
AFTER INSERT OR UPDATE OR DELETE ON assets
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
    v_old CLOB;
    v_new CLOB;
    v_id NUMBER;
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_id := :NEW.id;
        v_new := 'category=' || :NEW.category || ', name=' || :NEW.name ||
                 ', serial=' || :NEW.serial || ', entities_id=' || :NEW.entities_id;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_id := :NEW.id;
        v_old := 'category=' || :OLD.category || ', name=' || :OLD.name ||
                 ', serial=' || :OLD.serial || ', states_id=' || :OLD.states_id;
        v_new := 'category=' || :NEW.category || ', name=' || :NEW.name ||
                 ', serial=' || :NEW.serial || ', states_id=' || :NEW.states_id;
    ELSIF DELETING THEN
        v_action := 'DELETE';
        v_id := :OLD.id;
        v_old := 'category=' || :OLD.category || ', name=' || :OLD.name ||
                 ', serial=' || :OLD.serial || ', entities_id=' || :OLD.entities_id;
    END IF;

    INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
    VALUES ('ASSETS', v_id, v_action, v_old, v_new);
END;
/

CREATE OR REPLACE TRIGGER TRG_CHECK_ASSET_MODEL_CATEGORY
BEFORE INSERT OR UPDATE ON assets
FOR EACH ROW
DECLARE
    v_category VARCHAR2(50);
BEGIN
    IF :NEW.asset_models_id IS NOT NULL THEN
        SELECT category INTO v_category
        FROM asset_models
        WHERE id = :NEW.asset_models_id;

        IF v_category != :NEW.category THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Le modele doit etre de categorie ' || :NEW.category ||
                ', trouve: ' || v_category);
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_ARCHIVE_ASSET_DELETE
BEFORE DELETE ON assets
FOR EACH ROW
BEGIN
    INSERT INTO archives_materiel (source_table, source_id, data)
    VALUES (
        'ASSETS',
        :OLD.id,
        '{"category":"' || :OLD.category ||
        '","name":"' || :OLD.name ||
        '","serial":"' || :OLD.serial ||
        '","entities_id":' || :OLD.entities_id ||
        ',"users_id":' || NVL(TO_CHAR(:OLD.users_id), 'null') ||
        ',"states_id":' || NVL(TO_CHAR(:OLD.states_id), 'null') ||
        ',"date_creation":"' || TO_CHAR(:OLD.date_creation, 'YYYY-MM-DD HH24:MI:SS') ||
        '"}'
    );
END;
/

CREATE OR REPLACE TRIGGER TRG_CASCADE_SITE_CODE
AFTER UPDATE OF site_code ON entities
FOR EACH ROW
BEGIN
    UPDATE entities
    SET site_code = :NEW.site_code
    WHERE entities_id = :NEW.id;
END;
/
