-- ============================================================
-- triggers.sql
-- Triggers PL/SQL — Automatisation et intégrité
-- Oracle XE
-- ============================================================

-- =========================
-- TRG_AUTO_DATE_MOD
-- Met à jour automatiquement date_mod sur les tables matériels
-- =========================

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_COMPUTERS
BEFORE UPDATE ON computers
FOR EACH ROW
BEGIN
    :NEW.date_mod := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_AUTO_DATE_MOD_MONITORS
BEFORE UPDATE ON monitors
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

-- =========================
-- TRG_AUDIT_COMPUTERS
-- Log automatique de toutes les modifications sur computers
-- =========================

CREATE OR REPLACE TRIGGER TRG_AUDIT_COMPUTERS
AFTER INSERT OR UPDATE OR DELETE ON computers
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
        v_new := 'name=' || :NEW.name || ', serial=' || :NEW.serial ||
                 ', entities_id=' || :NEW.entities_id;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_id := :NEW.id;
        v_old := 'name=' || :OLD.name || ', serial=' || :OLD.serial ||
                 ', entities_id=' || :OLD.entities_id ||
                 ', users_id=' || :OLD.users_id ||
                 ', states_id=' || :OLD.states_id;
        v_new := 'name=' || :NEW.name || ', serial=' || :NEW.serial ||
                 ', entities_id=' || :NEW.entities_id ||
                 ', users_id=' || :NEW.users_id ||
                 ', states_id=' || :NEW.states_id;
    ELSIF DELETING THEN
        v_action := 'DELETE';
        v_id := :OLD.id;
        v_old := 'name=' || :OLD.name || ', serial=' || :OLD.serial ||
                 ', entities_id=' || :OLD.entities_id;
    END IF;

    INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
    VALUES ('COMPUTERS', v_id, v_action, v_old, v_new);
END;
/

-- =========================
-- TRG_CHECK_ASSET_TYPE_CATEGORY
-- Vérifie que le type assigné correspond à la catégorie du matériel
-- =========================

CREATE OR REPLACE TRIGGER TRG_CHECK_COMPUTER_TYPE
BEFORE INSERT OR UPDATE ON computers
FOR EACH ROW
DECLARE
    v_category VARCHAR2(50);
BEGIN
    IF :NEW.asset_types_id IS NOT NULL THEN
        SELECT category INTO v_category
        FROM asset_types
        WHERE id = :NEW.asset_types_id;

        IF v_category != 'COMPUTER' THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Le type (id=' || :NEW.asset_types_id ||
                ') doit être de catégorie COMPUTER, trouvé: ' || v_category);
        END IF;
    END IF;

    IF :NEW.asset_models_id IS NOT NULL THEN
        SELECT category INTO v_category
        FROM asset_models
        WHERE id = :NEW.asset_models_id;

        IF v_category != 'COMPUTER' THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Le modèle (id=' || :NEW.asset_models_id ||
                ') doit être de catégorie COMPUTER, trouvé: ' || v_category);
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_CHECK_MONITOR_TYPE
BEFORE INSERT OR UPDATE ON monitors
FOR EACH ROW
DECLARE
    v_category VARCHAR2(50);
BEGIN
    IF :NEW.asset_types_id IS NOT NULL THEN
        SELECT category INTO v_category
        FROM asset_types WHERE id = :NEW.asset_types_id;
        IF v_category != 'MONITOR' THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Le type doit être de catégorie MONITOR, trouvé: ' || v_category);
        END IF;
    END IF;
END;
/

-- =========================
-- TRG_ARCHIVE_ON_DELETE
-- Archive automatiquement un matériel supprimé au lieu de le perdre
-- =========================

CREATE OR REPLACE TRIGGER TRG_ARCHIVE_COMPUTER_DELETE
BEFORE DELETE ON computers
FOR EACH ROW
BEGIN
    INSERT INTO archives_materiel (source_table, source_id, data)
    VALUES (
        'COMPUTERS',
        :OLD.id,
        '{"name":"' || :OLD.name ||
        '","serial":"' || :OLD.serial ||
        '","entities_id":' || :OLD.entities_id ||
        ',"users_id":' || NVL(TO_CHAR(:OLD.users_id), 'null') ||
        ',"states_id":' || NVL(TO_CHAR(:OLD.states_id), 'null') ||
        ',"date_creation":"' || TO_CHAR(:OLD.date_creation, 'YYYY-MM-DD HH24:MI:SS') ||
        '"}'
    );
END;
/

-- =========================
-- TRG_CASCADE_ENTITY_UPDATE
-- Propage le site_code quand une entité parent change
-- =========================

CREATE OR REPLACE TRIGGER TRG_CASCADE_SITE_CODE
AFTER UPDATE OF site_code ON entities
FOR EACH ROW
BEGIN
    UPDATE entities
    SET site_code = :NEW.site_code
    WHERE entities_id = :NEW.id;
END;
/
