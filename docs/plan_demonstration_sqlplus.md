# Plan de demonstration SQL*Plus

Ce document donne un deroule complet pour presenter le projet au professeur. Les commandes sont prevues pour SQL*Plus.

## 0. Ouvrir SQL*Plus

Dans PowerShell :

```powershell
cd "H:\Desktop\Ing-2\TAD\Projet\Projet-TAD"
sqlplus / as sysdba
```

## 1. Verifier les tablespaces

Dans SQL*Plus :

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name IN (
    'TS_MATERIEL',
    'TS_UTILISATEURS',
    'TS_RESEAU',
    'TS_SUPPORT',
    'TS_INDEX',
    'TS_TEMP_GLPI'
)
ORDER BY tablespace_name;
```

Si un tablespace manque :

```sql
@sql/01_tablespaces.sql
```

Si Oracle affiche `ORA-01543: tablespace already exists`, ce n'est pas grave.

## 2. Creer l'utilisateur de demonstration locale

```sql
ALTER SESSION SET "_ORACLE_SCRIPT"=true;

DROP USER glpi_app CASCADE;

CREATE USER glpi_app IDENTIFIED BY glpi_app
    DEFAULT TABLESPACE TS_MATERIEL
    TEMPORARY TABLESPACE TS_TEMP_GLPI
    QUOTA UNLIMITED ON TS_MATERIEL
    QUOTA UNLIMITED ON TS_UTILISATEURS
    QUOTA UNLIMITED ON TS_RESEAU
    QUOTA UNLIMITED ON TS_SUPPORT
    QUOTA UNLIMITED ON TS_INDEX;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE,
      CREATE TRIGGER, CREATE SYNONYM, RESOURCE
TO glpi_app;
```

Si `DROP USER glpi_app CASCADE;` echoue car l'utilisateur n'existe pas, ignorer l'erreur et continuer.

## 3. Installer le projet dans `glpi_app`

```sql
CONNECT glpi_app/glpi_app

SET SERVEROUTPUT ON SIZE UNLIMITED
SET SQLBLANKLINES ON

@sql/02_schema_tables.sql
@sql/04_clusters_indexes.sql
@sql/05_views.sql
@sql/06_plsql/functions.sql
@sql/06_plsql/procedures.sql
@sql/06_plsql/triggers.sql
@sql/06_plsql/cursors.sql
@sql/09_test_data.sql
@sql/10_benchmark.sql
```

## 4. Generer les donnees

```sql
EXEC SP_GENERER_JEU_DE_TEST;
```

Verifier :

```sql
SELECT COUNT(*) AS nb_sites FROM sites;
SELECT COUNT(*) AS nb_users FROM users;
SELECT COUNT(*) AS nb_assets FROM assets;
SELECT COUNT(*) AS nb_tickets FROM tickets;
SELECT COUNT(*) AS nb_ports FROM network_ports;
SELECT COUNT(*) AS nb_ip FROM ip_addresses;
```

## 5. Regler l'affichage SQL*Plus

```sql
SET LINESIZE 220
SET PAGESIZE 50
SET WRAP OFF
SET TRIMSPOOL ON

COLUMN id FORMAT 9999
COLUMN site_id FORMAT 9999
COLUMN site FORMAT A8
COLUMN type_materiel FORMAT A18
COLUMN nom_materiel FORMAT A22
COLUMN numero_serie FORMAT A24
COLUMN fabricant FORMAT A12
COLUMN etat FORMAT A16
COLUMN nombre FORMAT 9999
COLUMN title FORMAT A30
COLUMN status FORMAT A12
COLUMN priority FORMAT A10
COLUMN asset_name FORMAT A22
COLUMN source_instance FORMAT A16
```

## 6. Montrer le modele simplifie

Commande :

```sql
SELECT table_name
FROM user_tables
ORDER BY table_name;
```

Phrase a dire :

> Le modele GLPI original est tres large. Ici, on garde le noyau utile : sites, utilisateurs, assets, tickets, reseau, audit et archivage. La table centrale `assets` remplace les tables separees comme computers, printers, phones, etc.

## 7. Montrer l'inventaire

Commande :

```sql
SELECT id,
       site,
       type_materiel,
       nom_materiel,
       numero_serie,
       fabricant,
       etat
FROM V_INVENTAIRE_COMPLET
WHERE ROWNUM <= 10;
```

Commande plus synthetique :

```sql
SELECT site,
       type_materiel,
       COUNT(*) AS nombre
FROM V_INVENTAIRE_COMPLET
GROUP BY site, type_materiel
ORDER BY site, type_materiel;
```

Phrase a dire :

> La vue `V_INVENTAIRE_COMPLET` masque les jointures et donne une vision directement exploitable de l'inventaire.

## 8. Montrer les statistiques par site

```sql
SELECT site,
       nb_assets,
       nb_users,
       nb_tickets,
       nb_ports
FROM V_STATISTIQUES_SITE;
```

Phrase a dire :

> Les donnees sont deja separees par `site_code`, ce qui prepare la fragmentation horizontale de la BDDR.

## 9. Montrer les tickets

```sql
SELECT t.id,
       t.title,
       t.status,
       t.priority,
       a.name AS asset_name,
       s.site_code AS site
FROM tickets t
JOIN assets a ON t.asset_id = a.id
JOIN sites s ON t.site_id = s.id
WHERE ROWNUM <= 10;
```

Phrase a dire :

> Un ticket est rattache a un site, un materiel, un demandeur, une categorie et eventuellement plusieurs techniciens.

## 10. Creer un ticket pendant la demonstration

Ne pas utiliser d'ID en dur. Cette commande choisit automatiquement un asset et un demandeur valides sur Cergy.

```sql
VAR new_ticket_id NUMBER

DECLARE
    v_site_id NUMBER;
    v_asset_id NUMBER;
    v_requester_id NUMBER;
BEGIN
    SELECT a.site_id, a.id
    INTO v_site_id, v_asset_id
    FROM assets a
    JOIN sites s ON a.site_id = s.id
    WHERE s.site_code = 'CERGY'
      AND ROWNUM = 1;

    SELECT u.id
    INTO v_requester_id
    FROM users u
    WHERE u.site_id = v_site_id
      AND ROWNUM = 1;

    SP_CREER_TICKET_MATERIEL(
        p_site_id => v_site_id,
        p_requester_id => v_requester_id,
        p_title => 'Test soutenance',
        p_description => 'Ticket cree pendant la demonstration',
        p_asset_id => v_asset_id,
        p_priority => 'HAUTE',
        p_ticket_id => :new_ticket_id
    );
END;
/

PRINT new_ticket_id
```

Verifier le ticket :

```sql
SELECT id, title, status, priority
FROM tickets
WHERE id = :new_ticket_id;
```

## 11. Montrer une procedure PL/SQL

```sql
EXEC SP_INVENTAIRE_SITE('CERGY');
```

Phrase a dire :

> La procedure agrege les informations du site et fournit un rapport directement lisible dans SQL*Plus.

## 12. Lancer le benchmark

```sql
EXEC SP_RUN_FULL_BENCHMARK;
```

Voir les resultats :

```sql
SELECT query_id, scenario, execution_ms, rows_returned
FROM benchmark_results
ORDER BY query_id, scenario;
```

Phrase a dire :

> Le benchmark compare plusieurs requetes metier. Il sert surtout a montrer la demarche de mesure et l'effet possible des index selon le volume.

## 13. Verifier que tout compile

```sql
SELECT object_name, object_type, status
FROM user_objects
WHERE status <> 'VALID';
```

Resultat attendu :

```text
no rows selected
```

## 14. Simulation BDDR avec deux schemas

La simulation utilise deux utilisateurs Oracle dans la meme base :

- `glpi_cergy`
- `glpi_pau`

Ils representent deux instances logiques.

Depuis `SYS` :

```sql
CONNECT / AS SYSDBA
ALTER SESSION SET "_ORACLE_SCRIPT"=true;

DROP USER glpi_cergy CASCADE;
DROP USER glpi_pau CASCADE;

CREATE USER glpi_cergy IDENTIFIED BY glpi_cergy
    DEFAULT TABLESPACE TS_MATERIEL
    TEMPORARY TABLESPACE TS_TEMP_GLPI
    QUOTA UNLIMITED ON TS_MATERIEL
    QUOTA UNLIMITED ON TS_UTILISATEURS
    QUOTA UNLIMITED ON TS_RESEAU
    QUOTA UNLIMITED ON TS_SUPPORT
    QUOTA UNLIMITED ON TS_INDEX;

CREATE USER glpi_pau IDENTIFIED BY glpi_pau
    DEFAULT TABLESPACE TS_MATERIEL
    TEMPORARY TABLESPACE TS_TEMP_GLPI
    QUOTA UNLIMITED ON TS_MATERIEL
    QUOTA UNLIMITED ON TS_UTILISATEURS
    QUOTA UNLIMITED ON TS_RESEAU
    QUOTA UNLIMITED ON TS_SUPPORT
    QUOTA UNLIMITED ON TS_INDEX;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE,
      CREATE TRIGGER, CREATE SYNONYM, CREATE DATABASE LINK, RESOURCE
TO glpi_cergy;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE,
      CREATE TRIGGER, CREATE SYNONYM, CREATE DATABASE LINK, RESOURCE
TO glpi_pau;
```

Si les `DROP USER` echouent parce que les utilisateurs n'existent pas, ignorer et continuer.

## 15. Installer le schema dans Cergy et Pau

Installer Cergy :

```sql
CONNECT glpi_cergy/glpi_cergy

SET SERVEROUTPUT ON SIZE UNLIMITED
SET SQLBLANKLINES ON

@sql/02_schema_tables.sql
@sql/04_clusters_indexes.sql
@sql/05_views.sql
@sql/06_plsql/functions.sql
@sql/06_plsql/procedures.sql
@sql/06_plsql/triggers.sql
@sql/09_test_data.sql
EXEC SP_GENERER_JEU_DE_TEST;
```

Installer Pau :

```sql
CONNECT glpi_pau/glpi_pau

SET SERVEROUTPUT ON SIZE UNLIMITED
SET SQLBLANKLINES ON

@sql/02_schema_tables.sql
@sql/04_clusters_indexes.sql
@sql/05_views.sql
@sql/06_plsql/functions.sql
@sql/06_plsql/procedures.sql
@sql/06_plsql/triggers.sql
@sql/09_test_data.sql
EXEC SP_GENERER_JEU_DE_TEST;
```

Verifier :

```sql
CONNECT glpi_cergy/glpi_cergy
SELECT COUNT(*) FROM assets;

CONNECT glpi_pau/glpi_pau
SELECT COUNT(*) FROM assets;
```

## 16. Creer les DB links

Depuis Cergy vers Pau :

```sql
CONNECT glpi_cergy/glpi_cergy

DROP DATABASE LINK DBL_PAU;

CREATE DATABASE LINK DBL_PAU
    CONNECT TO glpi_pau IDENTIFIED BY "glpi_pau"
    USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XE)))';

SELECT COUNT(*) FROM assets@DBL_PAU;
```

Depuis Pau vers Cergy :

```sql
CONNECT glpi_pau/glpi_pau

DROP DATABASE LINK DBL_CERGY;

CREATE DATABASE LINK DBL_CERGY
    CONNECT TO glpi_cergy IDENTIFIED BY "glpi_cergy"
    USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XE)))';

SELECT COUNT(*) FROM assets@DBL_CERGY;
```

Si `DROP DATABASE LINK` renvoie `ORA-02024`, ignorer et continuer.

Si `ORA-12170` apparait, refaire le lien avec `xepdb1` :

```sql
USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=xepdb1)))'
```

## 17. Creer les vues globales BDDR cote Cergy

```sql
CONNECT glpi_cergy/glpi_cergy

DROP DATABASE LINK DBL_PAU;

DEFINE BDDR_REMOTE_USER = glpi_pau
DEFINE BDDR_REMOTE_PASSWORD = glpi_pau
DEFINE BDDR_REMOTE_SERVICE = (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XE)))

@sql/07_bddr.sql
```

Tester :

```sql
SELECT source_instance, site, COUNT(*) AS nb_assets
FROM V_ASSETS_GLOBAL
GROUP BY source_instance, site
ORDER BY source_instance, site;
```

Tickets globaux :

```sql
SELECT source_instance, COUNT(*) AS nb_tickets
FROM V_TICKETS_GLOBAL
GROUP BY source_instance
ORDER BY source_instance;
```

Phrase a dire :

> La vue globale cache la repartition : Cergy lit ses donnees locales et les donnees de Pau via `DBL_PAU`.

## 18. Simuler un transfert inter-sites

Depuis `glpi_cergy`, ne pas utiliser d'ID en dur.

```sql
CONNECT glpi_cergy/glpi_cergy

VAR transferred_asset_id NUMBER

DECLARE
    v_asset_id NUMBER;
    v_pau_site_id NUMBER;
BEGIN
    SELECT a.id
    INTO v_asset_id
    FROM assets a
    JOIN sites s ON a.site_id = s.id
    WHERE s.site_code = 'CERGY'
      AND ROWNUM = 1;

    SELECT id
    INTO v_pau_site_id
    FROM sites
    WHERE site_code = 'PAU'
      AND ROWNUM = 1;

    SP_TRANSFERT_MATERIEL(
        p_asset_id => v_asset_id,
        p_new_site_id => v_pau_site_id,
        p_new_user_id => NULL
    );

    :transferred_asset_id := v_asset_id;
END;
/

PRINT transferred_asset_id
```

Verifier :

```sql
SELECT source_instance, site, id, name
FROM V_ASSETS_GLOBAL
WHERE id = :transferred_asset_id;
```

Phrase a dire :

> Le transfert copie le materiel vers l'instance cible avec ses ports, IP et tickets, puis supprime la version locale.

## 19. Fin de demonstration

Commande finale :

```sql
SELECT object_name, object_type, status
FROM user_objects
WHERE status <> 'VALID';
```

Conclusion orale :

> Le projet montre une base Oracle simplifiee, contrainte, peuplee avec un jeu de test, exploitable via vues et PL/SQL, et capable de simuler une BDDR Cergy/Pau avec DB links.
