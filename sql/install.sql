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
DROP ROLE IF EXISTS hfbmupdater;
DROP ROLE IF EXISTS hfrpi;
DROP ROLE IF EXISTS admin;
DROP ROLE IF EXISTS player;
DROP ROLE IF EXISTS web;
DROP ROLE IF EXISTS flagupdater;
DROP ROLE IF EXISTS owner;

/*
    DB Creation (owner role + schema + extension + db)
*/
CREATE ROLE owner LOGIN INHERIT;
CREATE DATABASE scoreboard WITH OWNER owner ENCODING 'UTF-8' TEMPLATE template0;
\c scoreboard;

CREATE SCHEMA IF NOT EXISTS scoreboard AUTHORIZATION owner;
CREATE SCHEMA IF NOT EXISTS pgcrypto AUTHORIZATION owner;
CREATE SCHEMA IF NOT EXISTS tablefunc AUTHORIZATION owner;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA pgcrypto;
CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA tablefunc;
GRANT CONNECT ON DATABASE scoreboard TO owner;

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
CREATE ROLE hfbmupdater NOINHERIT;  -- Black market access
CREATE ROLE hfrpi NOINHERIT;        -- Rpi access (Model)

CREATE ROLE player LOGIN INHERIT PASSWORD 'player';
CREATE ROLE web LOGIN INHERIT PASSWORD 'web';
CREATE ROLE flagupdater LOGIN INHERIT PASSWORD 'flagUpdateri()*(*&?&?*$%';
CREATE ROLE rpi LOGIN INHERIT PASSWORD 'wggYUV5f9wEgBsPbCk1ToifhkLYRVwHk';

GRANT hfadmins to owner;
GRANT hfplayers to player;
GRANT hfscore to web;
GRANT hfflagupdater to flagupdater;
GRANT hfbmupdater to flagupdater;
GRANT hfrpi to rpi;

-- Create yourself a role here. Replace admin by something else on both lines.
CREATE ROLE admin LOGIN INHERIT PASSWORD 'zWMmhIpSQlcFlNOu8rfpr';
GRANT hfadmins to admin;
