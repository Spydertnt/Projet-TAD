-- ============================================================
-- triggers.sql
-- Triggers PL/SQL - Schema simplifie
-- Oracle XE
-- ============================================================

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_ASSETS
BEFORE UPDATE ON assets
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_USERS
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_NETPORTS
BEFORE UPDATE ON network_ports
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_TICKETS
BEFORE UPDATE ON tickets
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;

    IF :OLD.status = 'NOUVEAU'
       AND :NEW.status IN ('ASSIGNE', 'EN_COURS')
       AND :NEW.assigned_at IS NULL THEN
        :NEW.assigned_at := SYSTIMESTAMP;
    END IF;

    IF :OLD.status != 'RESOLU'
       AND :NEW.status = 'RESOLU'
       AND :NEW.resolved_at IS NULL THEN
        :NEW.resolved_at := SYSTIMESTAMP;
    END IF;

    IF :OLD.status != 'CLOS'
       AND :NEW.status = 'CLOS'
       AND :NEW.closed_at IS NULL THEN
        :NEW.closed_at := SYSTIMESTAMP;
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
        JOIN profiles p ON pu.profile_id = p.id
        JOIN tickets t ON t.id = :NEW.ticket_id
    WHERE pu.user_id = :NEW.user_id
      AND p.name = 'Technicien'
      AND (pu.site_id = t.site_id OR pu.is_recursive = 1);

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
        v_new := 'asset_type=' || :NEW.asset_type || ', name=' || :NEW.name ||
                 ', serial_number=' || :NEW.serial_number || ', site_id=' || :NEW.site_id;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_id := :NEW.id;
        v_old := 'asset_type=' || :OLD.asset_type || ', name=' || :OLD.name ||
                 ', serial_number=' || :OLD.serial_number || ', state_id=' || :OLD.state_id;
        v_new := 'asset_type=' || :NEW.asset_type || ', name=' || :NEW.name ||
                 ', serial_number=' || :NEW.serial_number || ', state_id=' || :NEW.state_id;
    ELSIF DELETING THEN
        v_action := 'DELETE';
        v_id := :OLD.id;
        v_old := 'asset_type=' || :OLD.asset_type || ', name=' || :OLD.name ||
                 ', serial_number=' || :OLD.serial_number || ', site_id=' || :OLD.site_id;
    END IF;

    INSERT INTO audit_log (table_name, row_id, action, old_data, new_data)
    VALUES ('ASSETS', v_id, v_action, v_old, v_new);
END;
/

CREATE OR REPLACE TRIGGER TRG_ARCHIVE_ASSET_DELETE
BEFORE DELETE ON assets
FOR EACH ROW
BEGIN
    INSERT INTO archives_materiel (original_table, original_id, archived_data)
    VALUES (
        'ASSETS',
        :OLD.id,
        '{"asset_type":"' || :OLD.asset_type ||
        '","name":"' || :OLD.name ||
        '","serial_number":"' || :OLD.serial_number ||
        '","site_id":' || :OLD.site_id ||
        ',"owner_user_id":' || NVL(TO_CHAR(:OLD.owner_user_id), 'null') ||
        ',"state_id":' || NVL(TO_CHAR(:OLD.state_id), 'null') ||
        ',"created_at":"' || TO_CHAR(:OLD.created_at, 'YYYY-MM-DD HH24:MI:SS') ||
        '"}'
    );
END;
/

CREATE OR REPLACE TRIGGER TRG_CASCADE_SITE_CODE
AFTER UPDATE OF site_code ON sites
FOR EACH ROW
BEGIN
    UPDATE sites
    SET site_code = :NEW.site_code
    WHERE parent_site_id = :NEW.id;
END;
/
