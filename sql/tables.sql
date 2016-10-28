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
DROP TABLE IF EXISTS gateKey;
DROP TABLE IF EXISTS settings CASCADE;
DROP TABLE IF EXISTS flagStatus_history CASCADE;
DROP TABLE IF EXISTS submit_history CASCADE;
DROP TABLE IF EXISTS news CASCADE;
DROP TABLE IF EXISTS team_kingFlag CASCADE;
DROP TABLE IF EXISTS team_flag CASCADE;
DROP TABLE IF EXISTS kingFlag CASCADE;
DROP TABLE IF EXISTS flag CASCADE;
DROP TABLE IF EXISTS flagAuthor CASCADE;
DROP TABLE IF EXISTS flagCategory CASCADE;
DROP TABLE IF EXISTS host CASCADE;
DROP TABLE IF EXISTS flagStatus CASCADE;
DROP TABLE IF EXISTS flagType CASCADE;
DROP TABLE IF EXISTS flagTypeExt CASCADE;
DROP TABLE IF EXISTS player CASCADE;
DROP TABLE IF EXISTS teamSecrets CASCADE;
DROP TABLE IF EXISTS team CASCADE;
DROP TABLE IF EXISTS teamLocation CASCADE;
DROP TABLE IF EXISTS bmItemStatus_history CASCADE;
DROP TABLE IF EXISTS eventFacility CASCADE;
DROP TABLE IF EXISTS eventSeverity CASCADE;
DROP TABLE IF EXISTS event CASCADE;
DROP TABLE IF EXISTS team_bmItem CASCADE;
DROP TABLE IF EXISTS bmItem CASCADE;
DROP TABLE IF EXISTS bmItemCategory CASCADE;
DROP TABLE IF EXISTS bmItemStatus CASCADE;
DROP TABLE IF EXISTS bmItemReview CASCADE;
DROP TABLE IF EXISTS transaction CASCADE;
DROP TABLE IF EXISTS transactionType CASCADE;
DROP TABLE IF EXISTS wallet CASCADE;


/*
    Represent an entity wallet, mostly used for teams. 
*/
CREATE TABLE wallet(
    id serial primary key,
    publicId varchar(64) not null unique,
    name varchar(50) not null,
    description text,
    amount NUMERIC(10,2) not null,
    ts timestamp not null default current_timestamp,
    constraint valid_wallet_name check (name != ''),
    constraint valid_wallet_amount check (amount >= 0)
    );

/*
    Represent a team location. As of iHack 2016, available locations were 
    Quebec and Sherbrooke
*/
CREATE TABLE teamLocation(
    id serial primary key,
    name varchar(100) not null
    );

/*
    Represent a team. A team can submit flags.
*/
CREATE TABLE team(
    id serial primary key,
    num integer not null unique,
    name varchar(40) not null unique,
    net inet null unique,
    pwd varchar(64) null,
    loc integer null references teamLocation(id),
    wallet integer not null references wallet(id),
    hide boolean not null default false,
    ts timestamp not null default current_timestamp,
    constraint valid_team_name check (name != '')
    );

/*
    Represent a team settings (variables). Useful to give unique information on a per-team basis.
*/
CREATE TABLE teamSecrets(
    id serial primary key,
    teamId integer not null references team(id),
    name varchar(100) not null,
    value varchar(100) not null,
    ts timestamp not null default current_timestamp,
    constraint valid_teamSecrets_name check (name != ''),
    constraint valid_teamSecrets_value check (value != '')
    );

/*
    Represent a player. Mostly used to map a nickname to an IP.
*/
CREATE TABLE player(
    id serial primary key,
    teamId integer not null references team(id),
    nick varchar(50) not null,
    ip inet not null unique,
    ts timestamp not null default current_timestamp,
    constraint valid_player_nick check (nick != ''),
    constraint u_player_constraint unique (nick,ip)
    );

/*
    Represent a flag status. A flag could be disabled if the box is broken or too corrupted
*/
CREATE TABLE flagStatus(
    id serial primary key,
    code integer not null unique,
    name varchar(20) not null,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_status_code check (code > 0 and code < 100),
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
CREATE TABLE flagCategory(
    id serial primary key,
    name varchar(10) not null unique,
    displayName varchar(30) not null unique,
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
    Represent a flag type. These are documented in sql/data.sql.
*/
CREATE TABLE flagType(
    id serial primary key,
    code integer not null unique,
    name varchar(50) not null unique,
    ts timestamp not null default current_timestamp,
    constraint valid_flagType_code check (code > 0 and code < 100),
    constraint valid_flagType_name check (name != '')
    );

/*
    Represent a flag type extension. These are generated by admins for maximum flexibility.
*/
CREATE TABLE flagTypeExt(
    id serial primary key,
    name varchar(50) not null unique,
    typeId integer not null references flagType(id),
    pts integer default null,
    ptsLimit integer default null,    
    ptsStep integer default null,    
    trapCmd text default null,                              -- For trap flags only
    updateCmd text default null,                            -- For king flags only
    teamNum integer not null references registration(num),  -- For exclusive flags only
    flagIds integer[] default null,                         -- For bonus and group bonus only to store bonus flags
    ts timestamp not null default current_timestamp,
    constraint valid_flagTypeExt_name check (name != ''),
    constraint valid_flagTypeExt_pts check (pts >= -1000 and pts <= 1000),
    constraint valid_flagTypeExt_ptsLimit check (ptsLimit > 0),
    constraint valid_flagTypeExt_ptsStep check (ptsStep <> 0)
    );

/* 
    Represent a flag. A flag is generated once, before the game start. Flags can be found on classical challenges. 
*/
CREATE TABLE flag(
    id serial primary key,
    name varchar(50) not null unique,
    value varchar(64) not null unique,
    pts integer not null,
    cash NUMERIC(10,2) not null,
    host integer not null references host(id),
    category integer not null references flagCategory(id),
    statusCode integer not null references flagStatus(code),
    author integer default null references flagAuthor(id),
    type integer not null references flagType(code),
    typeExt integer references flagTypeExt(id),     -- Attribute for complexe flags
    arg1 text default null,                         -- Arguments for complexe flags
    arg2 text default null,                         -- Arguments for complexe flags
    arg3 text default null,                         -- Arguments for complexe flags
    arg4 text default null,                         -- Arguments for complexe flags
    displayInterval interval default null,
    description text default null,
    news text default null,
    ts timestamp not null default current_timestamp,
    constraint valid_flag_name check (name != ''),
    constraint valid_flag_value check (value != ''),
    constraint valid_flag_pts check (pts >= -1000 and pts <= 1000),
    constraint valid_flag_cash check (cash >= 0),
    constraint valid_flag_displayTs check (displayInterval > '0 hours'::interval)
    );

/*
    Represent a flag instance (called king flag). A king flag is generated every X minutes during the game. A king flag can be found on king-of-the-hill challenges. King flags are generated from flags with type = 2.
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

    Since 2015 edition, flag pts are stored here for more possibilities.
*/
CREATE TABLE team_flag(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    flagId integer not null references flag(id) on delete cascade,
    pts integer not null,
    playerIp inet not null,
    ts timestamp not null default current_timestamp,
    constraint valid_team_flag_pts check (pts >= -1000 and pts <= 1000),
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
CREATE TABLE flagStatus_history(
    id serial primary key,
    flagId integer not null references flag(id) on delete cascade, 
    statusCode integer not null references flagStatus(code) on delete cascade,
    ts timestamp not null default current_timestamp
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
    constraint valid_status_code check (code > 0 and code < 100),
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
    amount NUMERIC(10,2) not null,
    type integer not null references transactionType(code) on delete cascade,
    description text,
    ts timestamp not null default current_timestamp
    );

/*
    For sale, For approval, Sold, Removed from game
*/
CREATE TABLE bmItemStatus(
    id serial primary key,
    code integer not null unique,
    name varchar(20) not null,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_bmItemStatus_code check (code > 0 and code < 100),
    constraint valid_bmItemStatus_name check (name != '')
    );

/*
    Possible choices: Game, Player
    Could also be used to separate items in different categories at display
*/
CREATE TABLE bmItemCategory(
    id serial primary key,
    name varchar(10) not null unique,
    displayName varchar(20) not null unique,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_bmItemCategory_name check (name != ''),
    constraint valid_bmItemCategory_displayName check (displayName!= '')
    );

/*
    Table used to document a black market item review. Used only when players sell items.
*/
CREATE TABLE bmItemReview(
    id serial primary key,
    rating integer default 0,
    comments text,
    ts timestamp not null default current_timestamp,
    constraint valid_bmItemReview_rating check (rating >= 0 and rating <= 5)
    );

/*
    Represent a black market item. Any leak, payload, document on the black market shall be in this table.
*/
CREATE TABLE bmItem(
    id serial primary key,
    name varchar(50) not null unique,
    category integer not null references bmItemCategory(id) on delete cascade,
    statusCode integer not null references bmItemStatus(code) on delete cascade,
    review integer default null references bmItemReview(id) on delete cascade,
    ownerWallet integer not null references wallet(id) on delete cascade,
    amount NUMERIC(10,2) not null,
    qty integer default null,
    displayInterval interval default null,
    description text,
    importName varchar(150) not null unique,
    privateId varchar(64) not null unique,  -- Should be secured
    data bytea null,                   -- Should be secured. Should be empty.
    dlLink text default null,               -- Should be secured
    updateCmd text default null,
    ts timestamp not null default current_timestamp,
    constraint valid_bmItem_name check (name != ''),
    constraint valid_bmItem_data check (data != ''),
    constraint valid_bmItem_data_length check (octet_length(data) < 1048576),   -- 1048576 = 1mb
    constraint valid_bmItem_importName check (importName != ''),
    constraint valid_bmItem_amount check (amount > 0),
    constraint valid_bmItem_displayTs check (displayInterval > '0 hours'::interval)
    );

/*
    Represent a team's successfuly bought black market item.
*/
CREATE TABLE team_bmItem(
    id serial primary key,
    teamId integer not null references team(id) on delete cascade,
    bmItemId integer not null references bmItem(id) on delete cascade,
    playerIp inet not null,
    ts timestamp not null default current_timestamp,
    constraint u_bmItem_constraint unique (teamId,bmItemId)
    );

/*
    This table contains all relevant black market status changes
*/
CREATE TABLE bmItemStatus_history(
    id serial primary key,
    bmItemId integer not null references bmItem(id) on delete cascade,
    statusCode integer not null references bmItemStatus(code) on delete cascade,
    ts timestamp not null default current_timestamp
    );

/*
    Represent an event facility (inspired from syslog)
*/
CREATE TABLE eventFacility(
    id serial primary key,
    code integer not null unique,
    name varchar(10) not null unique,
    displayName varchar(20) not null unique,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_eventFacility_code check (code >= 0 and code <= 23),
    constraint valid_eventFacility_name check (name != ''),
    constraint valid_eventFacility_displayName check (displayName != '')
    );

/*
    Represent an event severity (inspired from syslog)
*/
CREATE TABLE eventSeverity(
    id serial primary key,
    code integer not null unique,
    name varchar(10) not null unique,
    displayName varchar(20) not null unique,
    description text,
    ts timestamp not null default current_timestamp,
    constraint valid_eventSeverity_code check (code >= 0 and code <= 7),
    constraint valid_eventSeverity_name check (name != ''),
    constraint valid_eventSeverity_displayName check (displayName != '')
    );

/*
    Represent an event that can be printed on the scoreboard or the log visualizator
    Mostly called by triggers
*/
CREATE TABLE event(
    id serial primary key,
    title text not null,
    facility integer references eventFacility(code) on delete cascade,
    severity integer references eventSeverity(code) on delete cascade,
    ts timestamp not null default current_timestamp,
    constraint valid_title_name check (title != '')
    );

/*
    Represent a news that can be printed on the scoreboard
*/
CREATE TABLE news(
    id serial primary key,
    title text not null unique,
    displayTs timestamp not null default current_timestamp,
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
    teamStartMoney NUMERIC(10,2) not null default 0,
    ts timestamp not null default current_timestamp
    ); 

