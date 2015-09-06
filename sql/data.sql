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
       VALUES('2015-05-30 18:30'::timestamp,'2015-05-31 02:00'::timestamp,1000::money);

/* 
    Create event severity
*/
SELECT addEventSeverity(0,'Emergency','emerg','System is unusable');
SELECT addEventSeverity(1,'Alert','alert','Should be corrected immediately');
SELECT addEventSeverity(2,'Critical','crit','Critical conditions');
SELECT addEventSeverity(3,'Error','err','Error conditions');
SELECT addEventSeverity(4,'Warning','warning','May indicate that an error will occur if action is not taken.');
SELECT addEventSeverity(5,'Notice','notice','Events that are unusual, but not error conditions.');
SELECT addEventSeverity(6,'Informational','info','Normal operational messages that require no action.');
SELECT addEventSeverity(7,'Debug','debug','Information useful to developers for debugging the application.');

/* 
    Create flag status
*/
SELECT addFlagStatus(1,'Enabled','The flag is functionnal');
SELECT addFlagStatus(2,'Erronous','The flag is corrupted or fucked up');
SELECT addFlagStatus(3,'Disabled','The flag is removed by admins');

/*
    Add hosts
*/
SELECT addHost('scoreboard.hf', 'OpenBSD5.5 x64', 'Scoreboard');
SELECT addHost('dd-wrt', 'Some router', 'bla');

/*
    Add categories
*/
SELECT addFlagCategory('web', 'Web', 'Elastics Search & PHP');
SELECT addFlagCategory('re', 'Reverse Engineering', 'Reverse Engineering challenges such as VMs and binaries analysis');
SELECT addFlagCategory('for', 'Forensics', 'Chroot, Data and Virus Analysis');
SELECT addFlagCategory('expl', 'Pwning', 'Exploitation challenges from linux to windows. ');
SELECT addFlagCategory('misc', 'Misconfiguration', 'Misconfiguration challenges');
SELECT addFlagCategory('net', 'Networking', 'Firewall rule bypass');
SELECT addFlagCategory('bug', 'Bug Bounty', 'Bug Bounty Policy. Flags given for teams who raise security issues in the infrastructure. These are one timers.',True);
SELECT addFlagCategory('tca', 'Turmelle, Choquette ', 'Some company to hack');
SELECT addFlagCategory('electro', 'Electronics', 'CustomCorp electronics challenge near admins table. You may need <a href="/public/arduino-chal.c">this</a>');
SELECT addFlagCategory('sc', 'Sigmen Corp.', 'Sigmen corp. hacking challenge');
SELECT addFlagCategory('adfs', 'ADFS', 'ADFS federation challenges');

/*
    Add authors
*/
SELECT addAuthor('Martin Dube', 'mdube');
SELECT addAuthor('Jessy Campos', '_eko');
SELECT addAuthor('Cedrick Chaput', 'cechaput');
SELECT addAuthor('Stephane Sigmen', 's1g5');
SELECT addAuthor('Francois Barrette', 'fbarrette');
SELECT addAuthor('Jean-Sebastien Grenon', 'jsg');
SELECT addAuthor('HF Crew', 'HFCrew');

/* 
    Create flag type
*/
SELECT addFlagType(1,'Standard');
SELECT addFlagType(2,'Decremental');
SELECT addFlagType(3,'Group Flag');
SELECT addFlagType(4,'Unique');
SELECT addFlagType(5,'Trap');
SELECT addFlagType(6,'Cash');
SELECT addFlagType(7,'Hybrid');

/*
    Add a starting news
*/
SELECT addNews('Welcome to iHack CTF 2015 !', NOW()::timestamp);

/*
    Add transaction types
*/
SELECT addTransactionType(1, 'Start Wallet', 'Money received at the begining of the CTF');
SELECT addTransactionType(2, 'Cash Flag', 'Money received by submiting a cash or hybrid flag');
SELECT addTransactionType(3, 'Item bought', 'Money sent by buying an item on the black market');
SELECT addTransactionType(4, 'Money Laundering', 'Money received by laundering money with a CTF admin');
SELECT addTransactionType(5, 'Loto HF', 'Money won at loto HF');

/*
    Create the bank which act as the wallet #1
*/
SELECT initBank(500000::money);

/*
    fake teams for tests
*/
SELECT addTeam('Team HF Crew', '172.16.66.0/24');
SELECT addTeam('Team Dube', '192.168.1.0/24');
SELECT addTeam('Team HF DMZ', '192.168.6.0/24');
SELECT addTeam('Team VPN', '192.168.9.0/24');
SELECT addTeam('Team VPN 2', '192.168.10.0/24');
SELECT addTeam('Team VPN Pie', '192.168.13.0/24');
--SELECT addTeam('Team Eko', '127.0.0.1/8');

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
SELECT addBMItemStatus(6,'Ready to publish','This status will tell the bmUpdater to publish the item on the scoreboard front-end.');

SELECT addBMItem('Military base leak','admin',6,1,800::money,NULL,Null,'A leak was found regarding the military base. It looks like some way to discover new hosts', 'exploit!'::bytea);
SELECT addBMItem('Casino 0-day','admin',6,1,1600::money,NULL,Null,'Wana rape the casino? Buy this shit.', 'exploit!'::bytea);
SELECT addBMItem('Hydroelectric dam helper','admin',6,1,2100::money,NULL,Null,'Something', 'exploit!'::bytea);
SELECT addBMItem('Pipeline 0-day','admin',6,1,3700::money,NULL,Null,'pop that chèvre', 'exploit!'::bytea);
SELECT addBMItem('Phoenix corp takeover logs','admin',6,1,5000::money,NULL,Null,'Mouhaha', 'exploit!'::bytea);

/*
    Insert random data (for scoreboard development)
*/
--SELECT insertRandomData();


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
SELECT launderMoneyFromTeamId(1,2000::money);
SELECT launderMoneyFromTeamId(2,2000::money);
SELECT launderMoneyFromTeamId(3,2000::money);

-- Buy an admin item
--SELECT buyBMItemFromIp(1,'172.16.66.123');

-- Sell an item
SELECT sellBMItemFromIp('My item',1500::money,1,'this is an epic item. Buy it now!','The secret is: haha owned','192.168.1.11');

-- Attempt to buy an un-reviewed item (tested:work)
--SELECT buyBMItemFromIp(6,'172.16.66.155');

-- Review an admin item (should fail): Remove from game (tested:work)
--SELECT reviewBMItem(3,4,4,'this is a good item');

-- Review the item: Remove from game
SELECT reviewBMItem(6,4,0,'this is a malicious item. nice try');

-- Attempt to buy the item removed from the game (tested:work)
--SELECT buyBMItemFromIp(6,'172.16.66.159'); 

-- Review the item: Approve
SELECT reviewBMItem(6,6,5,'this is a good item');

-- Attempt to buy the approuved item (tested:work)
--SELECT buyBMItemFromIp(6,'172.16.66.250'); 


--SELECT addFlag('Test Flag 2014-10-25', 'KOTH-TESTTEST', 100::smallint, '172.28.72.4', 'misc', 
--                1::smallint, Null, Null, True, '', '',
--                'echo $FLAG > /home/hf/flag-koth.txt && chown root:hf /home/hf/flag-koth.txt && chmod 640 /home/hf/flag-koth.txt', 
--                'wget http://dathost/test');


/*
    Testing invalid status
*/
--SELECT addFlag('Flag 1', random_32(), 1, 'dathost', 'ssh root@$HOST "echo $FLAG > /root/flag.txt"', 'wget http://dathost/test', 4);
-- Testing invalid pts
--SELECT addFlag('Flag 1', random_32(), 11, 'dathost', 'ssh root@$HOST "echo $FLAG > /root/flag.txt"', 'wget http://dathost/test');

/*
    Add test flags
*/
/*
SELECT addFlag('Test 4.1', 'prepuce', 1::smallint, '172.28.72.4', 'rev', 1::smallint, Null, Null, True, '', '',
                'echo $FLAG > /root/flag4.1.txt', 'wget http://dathost/test');
SELECT addFlag('Test 4.2', 'agres', 2::smallint, '172.28.72.4', 'rev', 1::smallint, Null, Null, True, '', '',
                'echo $FLAG > /root/flag4.2.txt', 'wget http://dathost/test');
SELECT addFlag('Test 4.3', 'noob', 3::smallint, '172.28.72.4', 'rev', 1::smallint, Null, Null, True, '', '',
                'echo $FLAG > /root/flag4.3.txt', 'wget http://dathost/test');
SELECT addFlag('Test 4.4', ':|!+"/_"!$)("/%*%$?&', 3::smallint, '172.28.72.4', 'rev', 1::smallint, Null, Null, True, '', ''
                'echo $FLAG > /root/flag4.3.txt', 'wget http://dathost/test');
*/

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

