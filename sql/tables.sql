/*
    Notes about tables: Some informations are hardcoded such as game duration and minimum/maximum flag points value. 
    Users should parse this file and look at constraints before setting up a CTF.
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
DROP TABLE IF EXISTS flagType CASCADE;
DROP TABLE IF EXISTS team CASCADE;
DROP TABLE IF EXISTS bmItemStatus_history CASCADE;
DROP TABLE IF EXISTS event CASCADE;
DROP TABLE IF EXISTS team_bmItem CASCADE;
DROP TABLE IF EXISTS bmItem CASCADE;
DROP TABLE IF EXISTS bmItemCategory CASCADE;
DROP TABLE IF EXISTS bmItemStatus CASCADE;
DROP TABLE IF EXISTS transaction CASCADE;
DROP TABLE IF EXISTS transactionType CASCADE;
DROP TABLE IF EXISTS wallet CASCADE;

/*
    Represent a team. A team can submit flags.
*/
CREATE TABLE team(
    id serial primary key,
    name varchar(50) not null unique,
    net inet not null unique,
    hide boolean not null default false,
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
    os varchar(20) not null,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_host_name check (name != ''),
    constraint valid_host_os check (os != '')
    );

/*
    Represent a flag category such as web, binary, exploits, etc. 
*/
CREATE TABLE category(
    id serial primary key,
    name varchar(10) not null unique,
    displayName varchar(20) not null unique,
    description text,
    hidden boolean not null default false,
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
    constraint u_flagAuthor_constraint unique (name,nick)
    );

/*
flagType
   Decremental: min, max, step
   Group flag: groupId, min, max, step (incremental)
   Unique: no special field. One team can submit it
   Negative value flag.
   Trap Flag
   Cash Flag
   Hybrid Flag (Pts + Cash)
*/
CREATE TABLE flagType(
    id serial primary key,
    code integer not null unique,
    name varchar(50) not null unique,
    ts timestamp not null default current_timestamp,
    constraint valid_flagType_name check (name != '')
    );

/* 
    Represent a flag. A flag is generated once, before the game start. Flags can be found on classical challenges. 
*/
CREATE TABLE flag(
    id serial primary key,
    name varchar(50) not null unique,
    value varchar(64) not null unique,
    pts integer not null,
    host integer not null references host(id),
    category integer not null references category(id),
    statusCode integer not null references status(code),
    author integer default null references flagAuthor(id),
    type integer not null references flagType(code),
    displayInterval interval default null,
    description text default null,
    hint text default null,
    isKing boolean not null default False,  -- For king flags only
    updateCmd varchar(255) default null,    -- For king flags only
    monitorCmd varchar(255) default null,   -- For king flags only
    ts timestamp not null default current_timestamp,
    constraint valid_flag_name check (name != ''),
    constraint valid_flag_value check (value != ''),
    constraint valid_flag_pts check (pts >= 1 and pts <= 700),
    constraint valid_flag_displayTs check (displayInterval > '0 hours'::interval)
    );

/*
    Represent a flag instance (called king flag). A king flag is generated every X minutes during the game. A king flag can be found on king-of-the-hill challenges. King flags are generated from flags having isKing attribute to True.
*/
CREATE TABLE kingFlag(
    id serial primary key,
    flagId integer not null references flag(id),
    value char(64) not null unique,
    pts integer not null,
    ts timestamp not null default current_timestamp,
    constraint valid_kingFlag_value check (value != ''),
    constraint valid_kingFlag_pts check (pts >= 1 and pts <= 3)
    );

/*
    Represent a team's successfuly submitted flags.
*/
CREATE TABLE team_flag(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    flagId integer not null references flag(id) on delete cascade,
    playerIp inet not null,
    ts timestamp not null default current_timestamp,
    constraint u_flag_constraint unique (teamId,flagId)
    );

/*
    Represent a team's successfuly submitted flag instances.
*/
CREATE TABLE team_kingFlag(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    kingFlagId integer not null references kingFlag(id) on delete cascade,
    playerIp inet not null,
    ts timestamp not null default current_timestamp,
    constraint u_kingFlag_constraint unique (teamId,kingFlagId)
    );

/*
    This table contains all relevant submit attempts
*/
CREATE TABLE submit_history(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    playerIp inet not null,
    value varchar(64) not null,
    ts timestamp not null default current_timestamp
    );

/*
    This table contains all flag changes (not implemented yet)
*/
CREATE TABLE status_history(
    id serial primary key,
    flagId integer not null references flag(id) on delete cascade, 
    status integer not null references status(id) on delete cascade,
    ts timestamp not null default current_timestamp
    );

/*
    Represent an entity wallet, mostly used for teams. 
*/
CREATE TABLE wallet(
    id serial primary key,
    publicId varchar(64) not null unique,
    name varchar(20) not null,
    description text,
    amount money not null,
    ts timestamp not null default current_timestamp,
    constraint valid_wallet_name check (name != ''),
    constraint valid_wallet_publicId check (amount >= 0::money)
    );

/*
    Represent a transaction type. Mostly used to standardize how money is managed in the financial system.
    Possible values: Start Wallet, Cash Flag, BM item bought, BM item sold, Money Laundering
*/
CREATE TABLE transactionType(
    id serial primary key,
    code integer not null unique,
    name varchar(20) not null,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_status_code check (code > 0),
    constraint valid_status_name check (name != '')
    );
/*

    Represent a team's cash transaction. Used only for logging, not to determine what item was bought 
    or which cash flag was found.
*/
CREATE TABLE transaction(
    id serial primary key,
    srcWalletId integer not null references wallet(id) on delete cascade,
    dstWalletId integer not null references wallet(id) on delete cascade,
    amount money not null,
    type integer not null references transactionType(id) on delete cascade,
    description text,
    ts timestamp not null default current_timestamp
    );

/*
    For sale, For approval, Removed from game, Sold, Hidden
*/
CREATE TABLE bmItemStatus(
    id serial primary key,
    code integer not null unique,
    name varchar(20) not null,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_bmItemStatus_code check (code > 0),
    constraint valid_bmItemStatus_name check (name != '')
    );

/*
    Possible choices: Game, Player
    Could also be used to separate items in different categories at display
*/
CREATE TABLE bmItemCategory(
    id serial primary key,
    name varchar(20) not null,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_bmItemCategory_name check (name != '')
    );

/*
    Represent a black market item. Any leak, payload, document on the black market shall be in this table.
*/
CREATE TABLE bmItem(
    id serial primary key,
    publicId varchar(64) not null unique,
    name varchar(40) not null unique,
    description text,
    status integer not null references bmItemStatus(id) on delete cascade,
    category integer not null references bmItemCategory(id) on delete cascade,
    amount money not null,
    quantity integer default null,
    reviewRating integer default 0,
    reviewComments text,
    ts timestamp not null default current_timestamp,
    constraint valid_bmItem_name check (name != ''),
    constraint valid_bmItem_amount check (amount > 0::money),
    constraint valid_bmItem_rating check (reviewRating >= 0 and reviewRating <= 5)
    );

/*
    Represent a team's successfuly bought black market item.
*/
CREATE TABLE team_bmItem(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    bmItem integer not null references bmItem(id) on delete cascade,
    playerIp inet not null,
    ts timestamp not null default current_timestamp,
    constraint u_bmItem_constraint unique (teamId,bmItem)
    );

/*
    Represent a news that can be printed on the scoreboard
*/
CREATE TABLE news(
    id serial primary key,
    title varchar(150) not null unique,
    displayTs timestamp not null default current_timestamp,
    ts timestamp not null default current_timestamp,
    constraint valid_title_name check (title != '')
    );

/*
    Represent an event that can be printed on the scoreboard or the log visualizator
    Mostly called by triggers
*/
CREATE TABLE event(
    id serial primary key,
    title varchar(150) not null unique,
    ts timestamp not null default current_timestamp,
    constraint valid_title_name check (title != '')
    );

/*
    This table contains scoreboard settings
*/ 
CREATE TABLE settings(
    id serial primary key,
    gameStartTs timestamp not null,
    gameEndTs timestamp not null,
    ts timestamp not null default current_timestamp
    ); 

/*
    This table contains all relevant black market status changes
*/
CREATE TABLE bmItemStatus_history(
    id serial primary key,
    bmItemId integer not null references bmItem(id) on delete cascade,
    status integer not null references bmItemStatus(id) on delete cascade,
    ts timestamp not null default current_timestamp
    );

