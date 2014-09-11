/* 
    Some notes:
        - The server's user should not have update or delete access for security reasons
        - The flagUpdater's user should not have update or delete access for security reasons
        - The boxMonitorer's user should not have delete access for security reasons (update is needed to update status attribute of flag table.

    Some pre-requisites
        - pkg_add postgresql-contrib-9.3.2 (for pgcrypto)

    Before the game start
        - DELETE getRandomFlag() function!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
*/

/* 

    DB roles creation, schema creation, database creation, pgcrypto import, privileges setup

    su - _postgresql
    psql -U postgres
*/


/*
    Some drop
*/
\c postgres
DROP SCHEMA IF EXISTS scoreboard;
DROP SCHEMA IF EXISTS pgcrypto;
DROP EXTENSION IF EXISTS pgcrypto;
DROP DATABASE IF EXISTS scoreboard;

DROP ROLE IF EXISTS hfadmins;
DROP ROLE IF EXISTS hfplayers;
DROP ROLE IF EXISTS hfscore;
DROP ROLE IF EXISTS hfflagupdater;
DROP ROLE IF EXISTS hfowner;
DROP ROLE IF EXISTS martin;
DROP ROLE IF EXISTS player;
DROP ROLE IF EXISTS scoreboard;
DROP ROLE IF EXISTS flagupdater;
DROP ROLE IF EXISTS hfowner;

/*
    DB Creation (owner role + schema + extension + db)
*/
CREATE ROLE hfowner LOGIN INHERIT;
CREATE DATABASE scoreboard WITH OWNER hfowner ENCODING 'UTF-8' TEMPLATE template0;
\c scoreboard;

CREATE SCHEMA IF NOT EXISTS scoreboard AUTHORIZATION hfowner;
CREATE SCHEMA IF NOT EXISTS pgcrypto AUTHORIZATION hfowner;
CREATE SCHEMA IF NOT EXISTS tablefunc AUTHORIZATION hfowner;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA pgcrypto;
CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA tablefunc;
GRANT CONNECT ON DATABASE scoreboard TO hfowner;
--GRANT ALL PRIVILEGES ON SCHEMA scoreboard TO hfowner;

/*
    Modify default privileges
*/ 
ALTER DEFAULT PRIVILEGES IN SCHEMA scoreboard REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA scoreboard REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA scoreboard REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC;

/*
    Access roles
*/
CREATE ROLE hfadmins NOINHERIT;     -- Admins of the KotH
CREATE ROLE hfplayers NOINHERIT;    -- Players of the KotH
CREATE ROLE hfscore NOINHERIT;      -- Scoreboard access
CREATE ROLE hfflagupdater NOINHERIT;-- FlagUpdater access

CREATE ROLE martin LOGIN INHERIT PASSWORD 'h9N)kv1*H!3(|<eASR1^]Iwql;fsDIDc6h.?o\,IS[v?4:~}J0';
CREATE ROLE player LOGIN INHERIT PASSWORD 'player';
CREATE ROLE scoreboard LOGIN INHERIT PASSWORD 'scoreboard';
CREATE ROLE flagupdater LOGIN INHERIT PASSWORD 'flagUpdater';

GRANT hfadmins to martin;
GRANT hfadmins to hfowner;
GRANT hfplayers to player;
GRANT hfscore to scoreboard;
GRANT hfflagupdater to flagupdater;


-- Database populating optimisation
-- http://www.postgresql.org/docs/9.3/static/populate.html



