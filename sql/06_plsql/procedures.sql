-- ============================================================
-- procedures.sql
-- Procédures stockées PL/SQL
-- Oracle XE
-- ============================================================

-- =========================
-- SP_TRANSFERT_MATERIEL
-- Transfère un ordinateur d'un site à un autre
-- =========================

CREATE OR REPLACE PROCEDURE SP_TRANSFERT_MATERIEL (
    p_computer_id   IN NUMBER,
    p_new_entity_id IN NUMBER,
    p_new_user_id   IN NUMBER DEFAULT NULL
)
AS
    v_old_entity    NUMBER;
    v_old_site      VARCHAR2(10);
    v_new_site      VARCHAR2(10);
    v_computer_name VARCHAR2(255);
BEGIN
    -- Vérifier que l'ordinateur existe
    SELECT entities_id, name
    INTO v_old_entity, v_computer_name
    FROM computers
    WHERE id = p_computer_id;

    -- Récupérer les sites source et destination
    SELECT site_code INTO v_old_site
    FROM entities WHERE id = v_old_entity;

    SELECT site_code INTO v_new_site
    FROM entities WHERE id = p_new_entity_id;

    -- Effectuer le transfert
    UPDATE computers
    SET entities_id = p_new_entity_id,
        users_id = p_new_user_id,
        date_mod = SYSTIMESTAMP
    WHERE id = p_computer_id;

    -- Transférer aussi les ports réseau associés
    UPDATE network_ports
    SET entities_id = p_new_entity_id
    WHERE computers_id = p_computer_id;

    DBMS_OUTPUT.PUT_LINE('Transfert réussi: ' || v_computer_name ||
        ' de ' || v_old_site || ' vers ' || v_new_site);

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Ordinateur (id=' || p_computer_id ||
            ') ou entité (id=' || p_new_entity_id || ') introuvable');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20011,
            'Erreur lors du transfert: ' || SQLERRM);
END SP_TRANSFERT_MATERIEL;
/

-- =========================
-- SP_AFFECTER_PROFIL
-- Affecte un profil à un utilisateur sur une entité
-- =========================

CREATE OR REPLACE PROCEDURE SP_AFFECTER_PROFIL (
    p_user_id       IN NUMBER,
    p_profile_id    IN NUMBER,
    p_entity_id     IN NUMBER,
    p_is_recursive  IN NUMBER DEFAULT 0
)
AS
    v_exists NUMBER;
    v_user_name VARCHAR2(255);
    v_profile_name VARCHAR2(255);
BEGIN
    -- Vérifier que l'utilisateur existe
    SELECT name INTO v_user_name FROM users WHERE id = p_user_id;

    -- Vérifier que le profil existe
    SELECT name INTO v_profile_name FROM profiles WHERE id = p_profile_id;

    -- Vérifier si l'affectation existe déjà
    SELECT COUNT(*) INTO v_exists
    FROM profiles_users
    WHERE users_id = p_user_id
      AND profiles_id = p_profile_id
      AND entities_id = p_entity_id;

    IF v_exists > 0 THEN
        -- Mettre à jour le flag is_recursive
        UPDATE profiles_users
        SET is_recursive = p_is_recursive
        WHERE users_id = p_user_id
          AND profiles_id = p_profile_id
          AND entities_id = p_entity_id;

        DBMS_OUTPUT.PUT_LINE('Profil mis à jour pour ' || v_user_name);
    ELSE
        -- Créer la nouvelle affectation
        INSERT INTO profiles_users (users_id, profiles_id, entities_id, is_recursive)
        VALUES (p_user_id, p_profile_id, p_entity_id, p_is_recursive);

        DBMS_OUTPUT.PUT_LINE('Profil "' || v_profile_name ||
            '" affecté à ' || v_user_name);
    END IF;

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20020,
            'Utilisateur ou profil introuvable');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20021,
            'Erreur affectation profil: ' || SQLERRM);
END SP_AFFECTER_PROFIL;
/

-- =========================
-- SP_INVENTAIRE_SITE
-- Génère un rapport d'inventaire complet pour un site
-- =========================

CREATE OR REPLACE PROCEDURE SP_INVENTAIRE_SITE (
    p_site_code IN VARCHAR2
)
AS
    v_nb_computers  NUMBER;
    v_nb_monitors   NUMBER;
    v_nb_peripherals NUMBER;
    v_nb_printers   NUMBER;
    v_nb_phones     NUMBER;
    v_nb_netequip   NUMBER;
    v_nb_users      NUMBER;
    v_nb_ports      NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_nb_computers
    FROM computers c JOIN entities e ON c.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_monitors
    FROM monitors m JOIN entities e ON m.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_peripherals
    FROM peripherals p JOIN entities e ON p.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_printers
    FROM printers p JOIN entities e ON p.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_phones
    FROM phones p JOIN entities e ON p.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_netequip
    FROM network_equipments n JOIN entities e ON n.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_users
    FROM users u JOIN entities e ON u.entities_id = e.id
    WHERE e.site_code = p_site_code;

    SELECT COUNT(*) INTO v_nb_ports
    FROM network_ports np JOIN entities e ON np.entities_id = e.id
    WHERE e.site_code = p_site_code;

    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('  RAPPORT D''INVENTAIRE - SITE ' || p_site_code);
    DBMS_OUTPUT.PUT_LINE('  Date : ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI'));
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('  Ordinateurs       : ' || LPAD(v_nb_computers, 6));
    DBMS_OUTPUT.PUT_LINE('  Écrans            : ' || LPAD(v_nb_monitors, 6));
    DBMS_OUTPUT.PUT_LINE('  Périphériques      : ' || LPAD(v_nb_peripherals, 6));
    DBMS_OUTPUT.PUT_LINE('  Imprimantes       : ' || LPAD(v_nb_printers, 6));
    DBMS_OUTPUT.PUT_LINE('  Téléphones        : ' || LPAD(v_nb_phones, 6));
    DBMS_OUTPUT.PUT_LINE('  Équipements réseau: ' || LPAD(v_nb_netequip, 6));
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('  TOTAL matériels   : ' ||
        LPAD(v_nb_computers + v_nb_monitors + v_nb_peripherals +
             v_nb_printers + v_nb_phones + v_nb_netequip, 6));
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('  Utilisateurs      : ' || LPAD(v_nb_users, 6));
    DBMS_OUTPUT.PUT_LINE('  Ports réseau      : ' || LPAD(v_nb_ports, 6));
    DBMS_OUTPUT.PUT_LINE('============================================');
END SP_INVENTAIRE_SITE;
/

-- =========================
-- SP_NETTOYER_ARCHIVES
-- Purge les archives de plus de N mois
-- =========================

CREATE OR REPLACE PROCEDURE SP_NETTOYER_ARCHIVES (
    p_nb_mois IN NUMBER DEFAULT 12
)
AS
    v_count NUMBER;
    v_date_limite TIMESTAMP;
BEGIN
    v_date_limite := SYSTIMESTAMP - NUMTOYMINTERVAL(p_nb_mois, 'MONTH');

    SELECT COUNT(*) INTO v_count
    FROM archives_materiel
    WHERE archive_date < v_date_limite;

    DBMS_OUTPUT.PUT_LINE('Archives à supprimer (> ' || p_nb_mois ||
        ' mois) : ' || v_count);

    IF v_count > 0 THEN
        DELETE FROM archives_materiel
        WHERE archive_date < v_date_limite;

        DBMS_OUTPUT.PUT_LINE(v_count || ' archives supprimées.');
        COMMIT;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Aucune archive à purger.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20030,
            'Erreur purge archives: ' || SQLERRM);
END SP_NETTOYER_ARCHIVES;
/
