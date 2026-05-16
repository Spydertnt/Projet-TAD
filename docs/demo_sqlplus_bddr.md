# Demonstration SQL*Plus et simulation BDDR

Ce document explique comment presenter le projet au professeur avec SQL*Plus, puis comment simuler les deux sites `CERGY` et `PAU`.

## 1. Idee de la demonstration

Le projet refond une base GLPI en une base Oracle XE simplifiee et defendable.

Points a montrer :

- le schema est plus lisible que GLPI original ;
- les tables sont contraintes par des cles primaires, cles etrangeres et contraintes `CHECK` ;
- l'inventaire est centralise dans `assets` ;
- les tickets sont relies au materiel ;
- les ports reseau et IP sont rattaches aux assets ;
- les vues donnent une lecture metier ;
- le PL/SQL automatise les transferts, tickets, audit et archivage ;
- la BDDR est simulee avec deux sites : `CERGY` et `PAU`.

## 2. Regle importante

Ne pas executer le projet dans `SYS`.

`SYS` sert uniquement a creer les tablespaces et les utilisateurs Oracle. Les tables du projet doivent etre creees dans un utilisateur applicatif, par exemple `glpi_app`, `glpi_cergy` ou `glpi_pau`.

Si tu crees les tables dans `SYS`, les triggers echouent avec :

```sql
ORA-04089: cannot create triggers on objects owned by SYS
```

## 3. Preparation simple pour une demo locale

Depuis PowerShell :

```powershell
cd "H:\Desktop\Ing-2\TAD\Projet\Projet-TAD"
sqlplus / as sysdba
```

Dans SQL*Plus, si les tablespaces existent deja, ne relance pas `01_tablespaces.sql`.

Verifier :

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
);
```

Si un tablespace manque, lancer :

```sql
@sql/01_tablespaces.sql
```

Si Oracle dit `ORA-01543: tablespace already exists`, ce n'est pas grave : le tablespace existe deja.

## 4. Reglage d'affichage SQL*Plus

Avant de montrer les vues au professeur, regler l'affichage. Sinon SQL*Plus coupe les lignes et affiche chaque colonne l'une sous l'autre.

```sql
SET LINESIZE 220
SET PAGESIZE 50
SET WRAP OFF
SET TRIMSPOOL ON

COLUMN id FORMAT 9999
COLUMN site_id FORMAT 9999
COLUMN type_materiel FORMAT A18
COLUMN nom_materiel FORMAT A22
COLUMN numero_serie FORMAT A24
COLUMN entite FORMAT A18
COLUMN site FORMAT A8
COLUMN localisation FORMAT A28
COLUMN proprietaire FORMAT A22
COLUMN technicien FORMAT A22
COLUMN fabricant FORMAT A12
COLUMN etat FORMAT A16
COLUMN created_at FORMAT A20
COLUMN updated_at FORMAT A20
COLUMN nombre FORMAT 9999
```

Regle de soutenance : eviter `SELECT *` sur les vues larges. Selectionner seulement les colonnes utiles.

## 5. Creer un utilisateur applicatif

Toujours depuis `SYS` :

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

Puis se connecter avec l'utilisateur du projet :

```sql
CONNECT glpi_app/glpi_app
```

## 6. Installer le projet

Lancer les scripts dans cet ordre :

```sql
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

Remarque : `03_users_roles.sql` cree des utilisateurs Oracle metier. Pour une demonstration simple, il n'est pas obligatoire. Il peut etre montre dans le code, mais pas forcement execute.

## 7. Generer les donnees de test

```sql
EXEC SP_GENERER_JEU_DE_TEST;
```

Verifier les volumes :

```sql
SELECT COUNT(*) AS nb_sites FROM sites;
SELECT COUNT(*) AS nb_users FROM users;
SELECT COUNT(*) AS nb_assets FROM assets;
SELECT COUNT(*) AS nb_tickets FROM tickets;
SELECT COUNT(*) AS nb_ports FROM network_ports;
SELECT COUNT(*) AS nb_ip FROM ip_addresses;
```

Verifier les donnees par site :

```sql
SELECT s.site_code, COUNT(*) AS nb_assets
FROM assets a
JOIN sites s ON a.site_id = s.id
GROUP BY s.site_code
ORDER BY s.site_code;
```

## 8. Ce qu'il faut montrer au professeur

### 8.1 Le modele simplifie

```sql
SELECT table_name
FROM user_tables
ORDER BY table_name;
```

Phrase a dire :

> GLPI original contient beaucoup de tables specialisees. Ici, on simplifie le modele avec une table centrale `assets`, puis on garde les tables utiles autour : sites, utilisateurs, tickets, reseau, audit.

### 8.2 L'inventaire multi-sites

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

Si l'affichage reste trop large, utiliser une version encore plus courte :

```sql
SELECT site,
       type_materiel,
       nom_materiel,
       numero_serie
FROM V_INVENTAIRE_COMPLET
WHERE ROWNUM <= 10;
```

Puis :

```sql
SELECT site, type_materiel, COUNT(*) AS nombre
FROM V_INVENTAIRE_COMPLET
GROUP BY site, type_materiel
ORDER BY site, type_materiel;
```

Phrase a dire :

> La vue cache les jointures et donne une vision metier directement exploitable.

### 8.3 Les statistiques par site

```sql
SELECT site,
       nb_assets,
       nb_users,
       nb_tickets,
       nb_ports
FROM V_STATISTIQUES_SITE;
```

Phrase a dire :

> On voit que les donnees sont deja separees logiquement par site, ce qui prepare la fragmentation horizontale BDDR.

### 8.4 Les tickets lies au materiel

```sql
SELECT t.id, t.title, t.status, t.priority, a.name AS asset_name, s.site_code
FROM tickets t
JOIN assets a ON t.asset_id = a.id
JOIN sites s ON t.site_id = s.id
WHERE ROWNUM <= 10;
```

Phrase a dire :

> Les tickets ne sont pas isoles : ils sont rattaches a un materiel, un site, un demandeur et eventuellement plusieurs techniciens.

### 8.5 Le PL/SQL

```sql
EXEC SP_INVENTAIRE_SITE('CERGY');
```

Puis :

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

Ne pas mettre `p_site_id => 1` ou `p_asset_id => 1` en dur : apres plusieurs generations de donnees, les sequences Oracle continuent d'augmenter et les IDs peuvent etre `1050`, `1072`, etc.

### 8.6 Les benchmarks

```sql
EXEC SP_RUN_FULL_BENCHMARK;

SELECT query_id, scenario, execution_ms, rows_returned
FROM benchmark_results
ORDER BY query_id, scenario;
```

Phrase a dire :

> Le benchmark montre une demarche de comparaison. Les gains dependent du volume et de l'optimiseur Oracle, mais le projet contient les index et les requetes d'analyse.

## 9. Verifier que tout compile

```sql
SELECT object_name, object_type, status
FROM user_objects
WHERE status <> 'VALID';
```

Resultat attendu :

```text
no rows selected
```

## 10. Simulation simple des deux sites dans une seule base

Pour simuler la BDDR sans deux machines, on cree deux utilisateurs Oracle :

- `glpi_cergy`
- `glpi_pau`

Chaque utilisateur represente une instance logique.

Depuis `SYS` :

```sql
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

## 11. Installer le schema dans chaque site simule

Connexion Cergy :

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

Connexion Pau :

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

## 12. Creer les DB Links pour simuler la BDDR

Depuis `glpi_cergy`, creer le lien vers `glpi_pau`.

Pour la simulation sur la meme machine, ne pas utiliser seulement `USING 'XE'` si aucun alias TNS n'est configure. Utiliser plutot le descripteur complet vers le listener local.

```sql
CONNECT glpi_cergy/glpi_cergy

DROP DATABASE LINK DBL_PAU;

CREATE DATABASE LINK DBL_PAU
    CONNECT TO glpi_pau IDENTIFIED BY "glpi_pau"
    USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XE)))';
```

Depuis `glpi_pau`, creer le lien vers `glpi_cergy` :

```sql
CONNECT glpi_pau/glpi_pau

DROP DATABASE LINK DBL_CERGY;

CREATE DATABASE LINK DBL_CERGY
    CONNECT TO glpi_cergy IDENTIFIED BY "glpi_cergy"
    USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XE)))';
```

Si Oracle renvoie `ORA-02024: database link not found` sur le `DROP DATABASE LINK`, ce n'est pas grave : cela veut juste dire que le lien n'existait pas encore. Continue avec le `CREATE DATABASE LINK`.

Si le test renvoie `ORA-12170: TNS:Connect timeout occurred`, recreer les liens avec le service `xepdb1` :

```sql
USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=xepdb1)))'
```

Tester les liens :

```sql
CONNECT glpi_cergy/glpi_cergy
SELECT COUNT(*) FROM assets@DBL_PAU;

CONNECT glpi_pau/glpi_pau
SELECT COUNT(*) FROM assets@DBL_CERGY;
```

Si ces deux requetes retournent un nombre, la simulation BDDR fonctionne.

## 13. Creer les vues globales BDDR

Le script `07_bddr.sql` est prevu pour le cas "Cergy vers Pau" avec `DBL_PAU`.

Depuis `glpi_cergy` :

```sql
CONNECT glpi_cergy/glpi_cergy

DROP DATABASE LINK DBL_PAU;

DEFINE BDDR_REMOTE_USER = glpi_pau
DEFINE BDDR_REMOTE_PASSWORD = glpi_pau
DEFINE BDDR_REMOTE_SERVICE = (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XE)))

@sql/07_bddr.sql
```

Si `DROP DATABASE LINK DBL_PAU` renvoie `ORA-02024`, ce n'est pas grave : le lien n'existait pas encore.

Si le `CREATE DATABASE LINK DBL_PAU` existe deja, Oracle peut dire :

```text
ORA-02011: duplicate database link name
```

Dans ce cas, il faut vraiment supprimer et recreer le lien, surtout si l'ancien lien pointe vers le mauvais utilisateur :

```sql
DROP DATABASE LINK DBL_PAU;
```

Puis relance `07_bddr.sql`.

## 14. Montrer les vues globales BDDR

Depuis `glpi_cergy` :

```sql
SELECT source_instance, site, COUNT(*) AS nb_assets
FROM V_ASSETS_GLOBAL
GROUP BY source_instance, site
ORDER BY source_instance, site;
```

Puis :

```sql
SELECT source_instance, COUNT(*) AS nb_tickets
FROM V_TICKETS_GLOBAL
GROUP BY source_instance
ORDER BY source_instance;
```

Phrase a dire :

> Ici, `CERGY` lit ses donnees locales et les donnees de `PAU` via un DB Link. La vue globale masque la repartition physique.

## 15. Simuler un transfert inter-sites

Depuis `glpi_cergy`, choisir un materiel Cergy et un site Pau distant/local selon la simulation.

Voir un materiel Cergy :

```sql
SELECT a.id, a.name, a.site_id, s.site_code
FROM assets a
JOIN sites s ON a.site_id = s.id
WHERE s.site_code = 'CERGY'
  AND ROWNUM = 1;
```

Voir un identifiant de site Pau :

```sql
SELECT id, name, site_code
FROM sites
WHERE site_code = 'PAU';
```

Appeler le transfert sans mettre d'ID en dur :

```sql
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

Ne pas utiliser `p_asset_id => 1` ou `p_new_site_id => 2` : apres plusieurs generations, les identifiants Oracle changent.

Phrase a dire :

> Le transfert copie le materiel et ses dependances operationnelles vers l'instance cible : ports, IP et tickets. Ensuite, il supprime la version locale.

## 16. Si la BDDR ne marche pas

Verifier le DB Link :

```sql
SELECT * FROM user_db_links;
```

Tester la connexion distante :

```sql
SELECT COUNT(*) FROM assets@DBL_PAU;
```

Erreurs courantes :

| Erreur | Cause probable | Solution |
|---|---|---|
| `ORA-12154` | Alias TNS inconnu | Utiliser le descripteur complet `HOST=127.0.0.1`, `PORT=1521`, `SERVICE_NAME=XE` |
| `ORA-12170` | Listener/service inaccessible ou mauvais `USING` | Refaire le DB link avec le descripteur complet, puis essayer `SERVICE_NAME=xepdb1` |
| `ORA-01017` | Mauvais mot de passe distant | Refaire le DB link avec le bon password |
| `ORA-02011` | DB link deja existant | `DROP DATABASE LINK DBL_PAU` puis recreer |
| `ORA-02024` | DB link absent lors du `DROP` | Ignorer et continuer avec le `CREATE DATABASE LINK` |
| `ORA-00942` | Table distante absente | Installer le schema dans l'utilisateur distant |
| `ORA-02291` | FK distante manquante | Verifier que les sites/users/referentiels existent aussi cote distant |

## 17. Plan de demonstration conseille

Ordre recommande devant le professeur :

1. Montrer rapidement le MCD/diagramme dans `docs/diagrams`.
2. Expliquer que `assets` simplifie l'inventaire GLPI.
3. Lancer quelques requetes sur les vues locales.
4. Montrer la creation d'un ticket.
5. Montrer les statistiques par site.
6. Montrer le DB Link avec `SELECT COUNT(*) FROM assets@DBL_PAU`.
7. Montrer `V_ASSETS_GLOBAL`.
8. Expliquer le transfert inter-sites.
9. Finir par la verification `user_objects WHERE status <> 'VALID'`.

La demonstration doit rester courte : le but est de prouver que le modele est coherent, que les scripts tournent, et que la BDDR est comprise.
