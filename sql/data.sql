/*
Set default schema
*/
SET search_path TO scoreboard;

/*
    Delete existing data
*/
SELECT emptyTables();

/*
    Set game start timestamp and other variables
*/
INSERT INTO settings(gameStartTs,gameEndTs,teamStartMoney) 
       VALUES('2017-10-25 00:30'::timestamp,'2017-11-05 02:00'::timestamp,1000);
/*
INSERT INTO settings(gameStartTs,gameEndTs,teamStartMoney) 
       VALUES('2017-10-04 16:30'::timestamp,'2016-11-05 02:00'::timestamp,1000);
*/

-- Add EventFacility
SELECT addEventFacility(0,'global','Global','');
SELECT addEventFacility(1,'flag','Flag Submissions','');
SELECT addEventFacility(2,'news','News','');
SELECT addEventFacility(3,'team','Teams','');
SELECT addEventFacility(4,'bm','Black Market','');
--SELECT addEventFacility(5,'loto','Loto HF','');
SELECT addEventFacility(6,'cash','Cash related','');

/*
    Create event severity
*/
SELECT addEventSeverity(0,'emerg','Emergency','System is unusable');
SELECT addEventSeverity(1,'alert','Alert','Should be corrected immediately');
SELECT addEventSeverity(2,'crit','Critical','Critical conditions');
SELECT addEventSeverity(3,'err','Error','Error conditions');
SELECT addEventSeverity(4,'warning','Warning','May indicate that an error will occur if action is not taken.');
SELECT addEventSeverity(5,'notice','Notice','Events that are unusual, but not error conditions.');
SELECT addEventSeverity(6,'info','Informational','Normal operational messages that require no action.');
SELECT addEventSeverity(7,'debug','Debug','Information useful to developers for debugging the application.');

/* 
    Create flag status
*/
SELECT addFlagStatus(1,'Enabled','The flag is functionnal');
SELECT addFlagStatus(2,'Erronous','The flag is corrupted or fucked up');
SELECT addFlagStatus(3,'Disabled','The flag is removed by admins');

/*
    Add hosts
*/
SELECT addHost('scoreboard.hf', 'LXC Arch Linux x64', 'Scoreboard');


/*
    Add authors
*/
--SELECT addAuthor('Martin Dube', 'mdube');
--SELECT addAuthor('Jessy Campos', '_eko');
--SELECT addAuthor('@mrvaughan', '@mrvaughan');
SELECT addAuthor('Cedrick Chaput', 'chaput');
SELECT addAuthor('Dave Cloutier', 'stackfault');
SELECT addAuthor('Stephane Sigmen', 'sigs');
--SELECT addAuthor('Jean-Sebastien Grenon', 'js');
SELECT addAuthor('François Lajeunesse-Robert', 'flr');
SELECT addAuthor('Franck Desert','phenix');
SELECT addAuthor('Viper', 'viper');
SELECT addAuthor('Guillaume Parent','gp');
SELECT addAuthor('Corb3nik','corb3nik');
SELECT addAuthor('Ramsexy','ramsexy');
SELECT addAuthor('vn','vn');
--SELECT addAuthor('Patrick Mathieu','patoff');
SELECT addAuthor('HF Crew', 'HFCrew');
--SELECT addAuthor('Scoreboard', 'Scoreboard');
--SELECT addAuthor('Lei He', 'lei');
--SELECT addAuthor('Lei and Martin', 'lei&mdube');

/* 
    Create flag type definitions
*/
-- Scope: Global. Purpose: Let a team gain pts or cash.
SELECT addFlagType(1,'Standard');       -- Simple (pts + cash)
-- Scope: Global. Purpose: Let only one team gain pts or cash.
SELECT addFlagType(2,'Unique');         -- Simple (pts + cash)

-- Scope: Global. Purpose: Define a king flag which will be instanciated on a regular basis on hosts.
SELECT addFlagType(11,'King');          -- Complex (pts + updateCmd)
-- Scope: Global. Purpose: Make the flag be less/more valuable the more it is submitted.
SELECT addFlagType(12,'Dynamic');       -- Complex (pts + limit,ptsStep)
-- Scope: Global. Purpose: Give a bonus when a flag is successfully submitted
SELECT addFlagType(13,'Bonus');       -- Complex (pts + bonus,ptsStep)
SELECT addFlagType(14,'Exclusive'); -- New from HF2016

-- Scope: Global. Purpose: Make a group of flags be less/more valuable the more it is submitted.
SELECT addFlagType(21,'Group Dynamic'); -- Complex (pts + limit,step,extName)
-- Scope: Global. Purpose: Give a bonus when all flags on this group was submitted
SELECT addFlagType(22,'Group Bonus'); -- Complex (pts + bonus,ptsStep,extName)

-- Scope: Team. Purpose: Make a group of flags be less/more valuable the more it is submitted, on a per team basis.
SELECT addFlagType(31,'Team Group Dynamic');    -- Complex (pts + limit,step,extName)
-- Scope: Team. Purpose: Grant points only when the entire group is submitted, on a per team basis.
SELECT addFlagType(32,'Team Group Pokemon');  -- Complex (pts)
SELECT addFlagType(33,'Team Group Unique'); -- New from HF2016

-- Scope: Team. Purpose: Trigger a malicious action when submitted
SELECT addFlagType(41,'Trap');          -- Complex (trapCmd)

/*
    Add a starting news
*/
SELECT addNews('Welcome to Hackfest 2017!', NOW()::timestamp);

/*
    Add transaction types
*/
SELECT addTransactionType(1, 'Start Wallet', 'Money received at the begining of the CTF');
SELECT addTransactionType(2, 'Cash Flag', 'Money received by submiting a cash or hybrid flag');
SELECT addTransactionType(3, 'Item bought', 'Money sent by buying an item on the black market');
SELECT addTransactionType(4, 'Money Laundering', 'Money received by laundering money with a CTF admin');
--SELECT addTransactionType(5, 'Loto HF', 'Money won at loto HF');

/*
    Create some "NPC" wallets
*/
SELECT addWallet('HF Bank','Default wallet used for cash flags, money laundering, etc.',20000000, true);
--SELECT addWallet('HF Loto','Default wallet used to manage loto.',0, true);

/*
    Team Locations
*/
--SELECT addTeamLocation('Quebec');
--SELECT addTeamLocation('Ottawa');
--SELECT addTeamLocation('Sherbrooke');
--SELECT addTeamLocation('Montreal');
--SELECT addTeamLocation('Columbia');

/*
    fake teams for tests
*/

SELECT addTeam(100, 'Team HF Crew', '172.28.66.0/24', Null, Null);
SELECT addTeam(101, 'Team HF VPN', '172.22.0.192/27', Null, Null);
SELECT addTeam(102, 'mdube', '172.22.0.0/28', Null, Null);
SELECT addTeam(103, 'mdube_dev', '127.0.0.1/8', Null, Null);
--SELECT addTeam(200, 'Monitoring', '172.28.70.34/31', Null, Null);
--SELECT addTeam('Team Dev', '127.0.0.1/8', Null, Null);
--SELECT addTeam(0, 'hf', Null, 'hf', Null);
--UPDATE team set hide=true WHERE num=0;   -- Hide Monitoring
UPDATE team set hide=true WHERE num=100;   -- Hide Monitoring

/*
    Identify fake names
*/
--SELECT identifyPlayerFromIp('mdube','192.168.1.100');
--SELECT identifyPlayerFromIp('mdube','192.168.1.101');
--SELECT identifyPlayerFromIp('mdube','192.168.1.102');
--SELECT identifyPlayerFromIp('mdube','127.0.0.1');

/*
    Add secrets
*/
--SELECT addTeamSecrets(7,'Test','Blabla secret');

-- Money for team eko
--SELECT launderMoneyFromTeamId(4,3001);

/*
    Black market   
*/
SELECT addBMItemCategory('admin','Admin','This item was created by an admin and can be considered safe.');
SELECT addBMItemCategory('player','Player','This item was uploaded by a player.');

SELECT addBMItemStatus(1,'For Sale','This item is for sale.');
SELECT addBMItemStatus(2,'Sold','This item is sold and is not available anymore (qty = 0).');
SELECT addBMItemStatus(3,'For approval','This item was submitted by a player and needs approval.');
SELECT addBMItemStatus(4,'Refused by admin','This item was put on black market by a player and was refused by an admin.');
SELECT addBMItemStatus(5,'Removed from game','This item was removed during the CTF.');
SELECT addBMItemStatus(6,'To be published','This status will tell the bmUpdater to publish the item on the scoreboard front-end.');
SELECT addBMItemStatus(7,'Approved','This status will tell the bmUpdater to get the item from the scoreboard database (bmItem.data).');

/*
SELECT addBMItem('Military base leak','admin',1,1,800,NULL,Null,'A leak was found regarding the military base. It looks like some way to discover new hosts', 'exploit!'::bytea);
SELECT addBMItem('Casino 0-day','admin',1,1,1600,NULL,Null,'Wana rape the casino? Buy this shit.', 'exploit!'::bytea);
SELECT addBMItem('Hydroelectric dam helper','admin',1,1,2100,NULL,Null,'Something', 'exploit!'::bytea);
SELECT addBMItem('Pipeline 0-day','admin',1,1,3700,NULL,Null,'pop that chèvre', 'exploit!'::bytea);
SELECT addBMItem('Phoenix corp takeover logs','admin',1,1,5000,NULL,Null,'Mouhaha', 'exploit!'::bytea);
*/

/* *****************************************************
*
*
*       Unit Tests
*
*
******************************************************* */

/*
    Testing transactions and black market
*/
-- Team
-- id |            name             |       net       | wallet | hide |             ts             
------+-----------------------------+-----------------+--------+------+----------------------------
--  1 | Team HF Crew                | 172.16.66.0/24  |      2 | f    | 2015-09-03 22:45:58.502987
--  2 | Team Dube                   | 192.168.1.0/24  |      3 | f    | 2015-09-03 22:45:58.502987
--  3 | Team HF DMZ                 | 192.168.6.0/24  |      4 | f    | 2015-09-03 22:45:58.502987

-- Wallet
-- id |     name     |  amount   
------+--------------+-----------
--  2 | Team HF Crew | $1,000.00
--  3 | Team Dube    | $1,000.00
--  4 | Team HF DMZ  | $1,000.00

-- bmItem
-- id |            name            | ownerwallet |  amount   | qty 
------+----------------------------+-------------+-----------+-----
--  1 | Military base leak         |           1 |   $800.00 |    
--  2 | Casino 0-day               |           1 | $1,600.00 |    
--  3 | Hydroelectric dam helper   |           1 | $2,100.00 |    
--  4 | Pipeline 0-day             |           1 | $3,700.00 |    
--  5 | Phoenix corp takeover logs |           1 | $5,000.00 |    


-- Launder money
--SELECT launderMoneyFromTeamId(1,2000);
--SELECT launderMoneyFromTeamId(2,2000);
--SELECT launderMoneyFromTeamId(3,2000);

-- Buy an admin item
--SELECT buyBMItemFromIp(1,'192.168.1.100');

-- Sell an item
--SELECT sellBMItemFromIp('My item',1500,1,'this is an epic item. Buy it now!','The secret is: haha owned','192.168.1.11');
--SELECT sellBMItemFromIp('My item 2',1500,1,'this is an epic item. Buy it now!','The secret is: haha owned','192.168.1.11');

-- Attempt to buy an un-reviewed item (tested:work)
--SELECT buyBMItemFromIp(6,'172.16.66.155');

-- Review an admin item (should fail): Remove from game (tested:work)
--SELECT reviewBMItem(3,4,4,'this is a good item');

-- Review the item: Remove from game
--SELECT reviewBMItem(6,4,0,'this is a malicious item. nice try');

-- Attempt to buy the item removed from the game (tested:work)
--SELECT buyBMItemFromIp(6,'172.16.66.159'); 

-- Review the item: Approve
--SELECT reviewBMItem(6,1,5,'this is a good item');

-- Attempt to buy the approuved item (tested:work)
--SELECT buyBMItemFromIp(6,'172.16.66.250'); 

/*
    Test specific flag types
*/
-- Unique
--SELECT addRandomFlag('Unique Flag', 200, NULL, 'chaltest.ctf.hf', 'electro', 1,
--                NULL, 'Martin Dube', 'Unique', NULL, 'descccccc1');
/*
SELECT submitFlagFromIp('192.168.9.21', getFlagValueFromName('Unique Flag'));
SELECT submitFlagFromIp('192.168.10.21', getFlagValueFromName('Unique Flag'));
*/


--SELECT addFlagTypeExt('Decrement_-1','Dynamic', NULL, 100, -100);
--SELECT addFlagTypeExt('Decrement_-2','Dynamic', NULL, 100, -200);
--SELECT addFlag('Flag 1', 'vvvvvvvvvvvvvv', 300, NULL, 'chaltest.ctf.hf', 'web', 1,
--                NULL, 'Martin Dube', 'Dynamic', 'Decrement_-2', 'descccccc');

/*
SELECT submitFlagFromIp('192.168.9.234', getFlagValueFromName('Flag 1'));
SELECT submitFlagFromIp('192.168.1.123', getFlagValueFromName('Flag 1'));
SELECT submitFlagFromIp('192.168.10.21', getFlagValueFromName('Flag 1'));
SELECT submitFlagFromIp('192.168.13.21', getFlagValueFromName('Flag 1'));
SELECT submitFlagFromIp('127.0.0.1', getFlagValueFromName('Flag 1'));
*/

--SELECT addFlagTypeExt('GroupDecrement_-100','Group Dynamic', NULL, 100, -100);
--SELECT addRandomFlag('Flag 2', 200, NULL, 'chaltest.ctf.hf', 'electro', 1,
--                NULL, 'Martin Dube', 'Group Dynamic', 'GroupDecrement_-100', 'descccccc1');
--SELECT addRandomFlag('Flag 3', 300, NULL, 'chaltest.ctf.hf', 'electro', 1,
--                NULL, 'Martin Dube', 'Group Dynamic', 'GroupDecrement_-100', 'descccccc2');
--SELECT addRandomFlag('Flag 4', 400, NULL, 'chaltest.ctf.hf', 'electro', 1,
--                NULL, 'Martin Dube', 'Group Dynamic', 'GroupDecrement_-100', 'descccccc3');

/*
SELECT submitFlagFromIp('192.168.9.234', getFlagValueFromName('Flag 2'));
SELECT submitFlagFromIp('192.168.1.123', getFlagValueFromName('Flag 3'));
SELECT submitFlagFromIp('192.168.10.21', getFlagValueFromName('Flag 4'));
SELECT submitFlagFromIp('192.168.13.21', getFlagValueFromName('Flag 4'));
SELECT submitFlagFromIp('127.0.0.1', getFlagValueFromName('Flag 4'));
SELECT submitFlagFromIp('192.168.9.234', getFlagValueFromName('Flag 3'));
SELECT submitFlagFromIp('192.168.1.123', getFlagValueFromName('Flag 2'));
SELECT submitFlagFromIp('192.168.1.123', getFlagValueFromName('Flag 4'));
SELECT submitFlagFromIp('192.168.10.21', getFlagValueFromName('Flag 2'));
SELECT submitFlagFromIp('127.0.0.1', getFlagValueFromName('Flag 2'));
SELECT submitFlagFromIp('127.0.0.1', getFlagValueFromName('Flag 3'));
*/

--SELECT addFlagTypeExt('Bonus_Electro_200','Bonus', 200, NULL, -100);
--SELECT addRandomFlag('Flag 5', 100, NULL, 'chaltest.ctf.hf', 'electro', 1,
--                NULL, 'Martin Dube', 'Bonus', 'Bonus_Electro_200', 'w44t');

/*
SELECT submitFlagFromIp('192.168.1.123', getFlagValueFromName('Flag 5'));
SELECT submitFlagFromIp('192.168.9.21', getFlagValueFromName('Flag 5'));
SELECT submitFlagFromIp('192.168.10.21', getFlagValueFromName('Flag 5'));
*/

--SELECT addFlagTypeExt('GroupBonus_Electro_100','Group Bonus', 100, NULL, -50);
--SELECT addRandomFlag('Flag 6', 50, NULL, 'chaltest.ctf.hf', 'electro', 1,
--                NULL, 'Martin Dube', 'Group Bonus', 'GroupBonus_Electro_100', 'w44t');
--SELECT addRandomFlag('Flag 7', 50, NULL, 'chaltest.ctf.hf', 'electro', 1,
--                NULL, 'Martin Dube', 'Group Bonus', 'GroupBonus_Electro_100', 'w00t');

/*
SELECT submitFlagFromIp('192.168.1.123', getFlagValueFromName('Flag 7'));
SELECT submitFlagFromIp('192.168.10.21', getFlagValueFromName('Flag 7'));
SELECT submitFlagFromIp('192.168.1.121', getFlagValueFromName('Flag 6'));
SELECT submitFlagFromIp('192.168.9.21', getFlagValueFromName('Flag 6'));
SELECT submitFlagFromIp('192.168.9.21', getFlagValueFromName('Flag 7'));
*/


--SELECT addFlagTypeExt('Pokemon_350','Team Group Pokemon', 350);
--SELECT addRandomFlag('Flag 8', 0, NULL, 'chaltest.ctf.hf', 're', 1,
--                NULL, 'Martin Dube', 'Team Group Pokemon', 'Pokemon_350', '');
--SELECT addRandomFlag('Flag 9', 0, NULL, 'chaltest.ctf.hf', 're', 1,
--                NULL, 'Martin Dube', 'Team Group Pokemon', 'Pokemon_350', '');

/*
SELECT submitFlagFromIp('192.168.1.123', getFlagValueFromName('Flag 8'));
SELECT submitFlagFromIp('192.168.10.21', getFlagValueFromName('Flag 8'));
SELECT submitFlagFromIp('192.168.1.121', getFlagValueFromName('Flag 9'));
SELECT submitFlagFromIp('192.168.9.21', getFlagValueFromName('Flag 8'));
SELECT submitFlagFromIp('192.168.9.21', getFlagValueFromName('Flag 9'));
*/


/*
    Loto tests
*/
--SELECT buyLotoFromIp(500, '192.168.1.111');
--SELECT buyLotoFromIp(700,'192.168.9.111');
--SELECT buyLotoFromIp(100,'192.168.10.111');

-- SELECT processLotoWinner(10);     -- Should not work
--SELECT processLotoWinner(4);     -- Should work


/*
    Submit tests
*/
--SELECT submitFlagFromIp('192.168.1.100', getFlagValueFromName('Test 1.1'));
--SELECT submitFlagFromIp('192.168.1.101', getFlagValueFromName('Test 1.2'));
--SELECT submitFlagFromIp('192.168.1.102', getFlagValueFromName('Test 1.3'));
-- Testing erronous and disabled flags
--SELECT submitFlagFromIp('192.168.1.100', getFlagValueFromName('Test 2'));
--SELECT submitFlagFromIp('192.168.1.100', getFlagValueFromName('Test 3'));
--SELECT submitFlagFromIp('192.168.9.100', getFlagValueFromName('Test 2'));
-- Testing invalid ip
--SELECT submitFlagFromIp('172.29.14.254', getFlagValueFromName('Flag 3'));
-- Testing already submited flag
--SELECT submitFlagFromIp('172.29.11.101', getFlagValueFromName('Flag 1'));

/*
    News tests
*/
/*
SELECT addNews('This is a random news', NOW()::timestamp);
SELECT addNews('This is another random news', NOW()::timestamp);
SELECT addNews('Ho yeah! A random news', NOW()::timestamp);
SELECT addNews('Really... another god damn news', NOW()::timestamp);
SELECT addNews('Fuck this news', NOW()::timestamp);
SELECT addNews('This news should never be printed', '2015-01-01 01:01'::timestamp);
*/

/*
    Insert random data (for scoreboard development)
*/
--SELECT insertRandomData();
