/*
    Notes about tables: Some informations are hardcoded such as game duration and minimum/maximum flag points value. Users should parse this file and look at constraints before setting up a CTF.
*/

/*
    Set default schema
*/
SET search_path TO scoreboard;

/*
    Some cleanup
*/
DROP TABLE IF EXISTS settings CASCADE;
DROP TABLE IF EXISTS status_history CASCADE;
DROP TABLE IF EXISTS submit_history CASCADE;
DROP TABLE IF EXISTS news CASCADE;
DROP TABLE IF EXISTS team_kingFlag CASCADE;
DROP TABLE IF EXISTS team_flag CASCADE;
DROP TABLE IF EXISTS kingFlag CASCADE;
DROP TABLE IF EXISTS flag CASCADE;
DROP TABLE IF EXISTS flagAuthor CASCADE;
DROP TABLE IF EXISTS category CASCADE;
DROP TABLE IF EXISTS host CASCADE;
DROP TABLE IF EXISTS status CASCADE;
DROP TABLE IF EXISTS team CASCADE;

/*
    Represent a team. A team can submit flags.
*/
CREATE TABLE team(
    id serial primary key,
    name varchar(50) not null unique,
    net inet not null unique,
    ts timestamp not null default current_timestamp,
    constraint valid_team_name check (name != '')
    );

/*
    Represent a flag status. A flag could be disabled if the box is broken or too corrupted
*/
CREATE TABLE status(
    id serial primary key,
    code integer not null unique,
    name varchar(20) not null,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_status_code check (code > 0),
    constraint valid_status_name check (name != '')
    );

/*
    Represent a flag location. A single flag can be on a single host but a host can have multiple flags.
*/
CREATE TABLE host(
    id serial primary key,
    name varchar(20) not null unique,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_host_name check (name != '')
    );

/*
    Represent a flag category such as web, binary, exploits, etc. 
*/
CREATE TABLE category(
    id serial primary key,
    name varchar(10) not null unique,
    displayName varchar(20) not null unique,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_host_name check (name != ''),
    constraint valid_host_dname check (displayName != '')
    );

/*
    Represent an organiser responsible for this flag. Useful to determine who can give help about the flag
*/
CREATE TABLE flagAuthor(
    id serial primary key,
    name varchar(50) not null unique,
    nick varchar(20) not null unique,
    ts timestamp not null default current_timestamp,
    constraint u_flagAuthor_constraint UNIQUE (name,nick)
    );

/* 
    Represent a flag. A flag is generated once, before the game start. Flags can be found on classical challenges. 
*/
CREATE TABLE flag(
    id serial primary key,
    name varchar(50) not null,
    value varchar(32) not null unique,
    pts integer not null,
    host integer not null references host(id),
    category integer not null references category(id),
    statusCode integer not null references status(id),
    displayInterval interval default null,
    author integer default null references flagAuthor(id),
    description text default null,
    hint text default null,
    isKing boolean not null default False,  -- For king flags only
    updateCmd varchar(255) default null,    -- For king flags only
    monitorCmd varchar(255) default null,   -- For king flags only
    ts timestamp not null default current_timestamp,
    constraint valid_flag_name check (name != ''),
    constraint valid_flag_value check (value != ''),
    constraint valid_flag_pts check (pts >= 1 and pts <= 10),
    constraint valid_flag_displayTs check (displayInterval < '16 hours'::interval)
    );

/*
    Represent a flag instance (called king flag). A king flag is generated every X minutes during the game. A king flag can be found on king-of-the-hill challenges. King flags are generated from flags having isKing attribute to True.
*/
CREATE TABLE kingFlag(
    id serial primary key,
    flagId integer not null references flag(id),
    value char(32) not null unique,
    pts integer not null,
    ts timestamp not null default current_timestamp,
    constraint valid_kingFlag_value check (value != ''),
    constraint valid_kingFlag_pts check (pts >= 1 and pts <= 10)
    );

/*
    Represent a team's successfuly submitted flags.
*/
CREATE TABLE team_flag(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    flagId integer not null references flag(id) on delete cascade,
    ts timestamp not null default current_timestamp,
    constraint u_flag_constraint UNIQUE (teamId,flagId)
    );
/*
    Represent a team's successfuly submitted flag instances.
*/
CREATE TABLE team_kingFlag(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    kingFlagId integer not null references kingFlag(id) on delete cascade,
    ts timestamp not null default current_timestamp,
    constraint u_kingFlag_constraint UNIQUE (teamId,kingFlagId)
    );

/*
    Represent a news that can be printed on the scoreboard
*/
CREATE TABLE news(
    id serial primary key,
    title varchar(100) not null,
    displayTs timestamp not null default current_timestamp,
    ts timestamp not null default current_timestamp,
    constraint valid_title_name check (title != '')
    );

CREATE TABLE submit_history(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    playerIp inet not null,
    value varchar(32) not null,
    ts timestamp not null default current_timestamp
    );

CREATE TABLE status_history(
    id serial primary key,
    flagId integer not null references flag(id) on delete cascade, 
    status integer not null references status(id) on delete cascade,
    ts timestamp not null default current_timestamp
    );
 
CREATE TABLE settings(
    id serial primary key,
    gameStartTs timestamp not null,
    ts timestamp not null default current_timestamp
    ); 
