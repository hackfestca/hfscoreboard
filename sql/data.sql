/*
Set default schema
*/
SET search_path TO scoreboard;

/*
    Delete existing data
*/
SELECT emptyTables();

/* 
    Create flag status
*/
SELECT addFlagStatus(1::smallint,'Enabled','The flag is functionnal');
SELECT addFlagStatus(2::smallint,'Erronous','The flag is corrupted or fucked up');
SELECT addFlagStatus(3::smallint,'Disabled','The flag is removed by admins');

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
SELECT addTransactionType(4, 'Item sold', 'Money received by selling an item on the black market');
SELECT addTransactionType(5, 'Money Laundering', 'Money received by laundering money with a CTF admin');

/*
    Set game start
*/
-- INSERT INTO settings(gameStartTs,gameEndTs) VALUES('2015-05-30 18:30'::timestamp,'2015-05-31 02:00'::timestamp);
INSERT INTO settings(gameStartTs,gameEndTs) VALUES('2015-05-30 18:30'::timestamp,'2015-05-31 02:00'::timestamp);

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
    Add random flags
*/
/*
SELECT addRandomFlag('Test 1.1', 3, '172.28.72.4', 'web', 1::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag.txt', 'wget http://dathost/test');
SELECT addRandomFlag('Test 1.2', 3, '172.28.72.4', 'web', 1::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag.txt', 'wget http://dathost/test');
SELECT addRandomFlag('Test 1.3', 3, '172.28.72.4', 'web', 1::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag.txt', 'wget http://dathost/test');
SELECT addRandomFlag('Test 2', 5, '172.28.72.4', 'expl', 2::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag2.txt', 'wget http://dathost/test');
SELECT addRandomFlag('Test 3', 7, '172.28.72.4', 'expl', 3::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag3.txt', 'wget http://dathost/test');
*/

--SELECT addKingFlagFromName('Test 1.1', random_32(), 1::smallint);
-- Testing erronous and disabled flags
--SELECT addKingFlagFromName('Test 2', random_32(), 1::smallint);
--SELECT addKingFlagFromName('Test 3', random_32(), 1::smallint);
-- Testing invalid flag
--SELECT addKingFlagFromName('Flag 4', random_32(), 1);

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

