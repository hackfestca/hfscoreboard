/*
    Some drop in case you want to re-install
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
DROP ROLE IF EXISTS admin;
DROP ROLE IF EXISTS player;
DROP ROLE IF EXISTS web;
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

CREATE ROLE player LOGIN INHERIT PASSWORD 'player';
CREATE ROLE web LOGIN INHERIT PASSWORD 'web';
CREATE ROLE flagupdater LOGIN INHERIT PASSWORD 'flagUpdater';

GRANT hfadmins to hfowner;
GRANT hfplayers to player;
GRANT hfscore to web;
GRANT hfflagupdater to flagupdater;

-- Create yourself a role here. Replace admin by something else on both lines.
CREATE ROLE admin LOGIN INHERIT PASSWORD '<CHANGE_ME>';
GRANT hfadmins to admin;
