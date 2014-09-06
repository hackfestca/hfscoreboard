/*
    Set default schema
*/
SET search_path TO mon2k14;

/*
    Delete existing data
*/
SELECT emptyTables();

/* 
    Adding some records
*/
SELECT addTeam('Team Dube', '192.168.1.0/24');
SELECT addTeam('Team fuckedup', '192.168.6.0/24');
SELECT addTeam('Team VPN', '192.168.9.0/24');
SELECT addTeam('Team VPN 2', '192.168.10.0/24');
SELECT addTeam('Team Eko', '127.0.0.1/8');

SELECT addStatus(1::smallint,'Enabled','The flag is functionnal');
SELECT addStatus(2::smallint,'Erronous','The flag is corrupted or fucked up');
SELECT addStatus(3::smallint,'Disabled','The flag is removed by admins');

SELECT addHost('poc01.hf', 'Test box for scoreboard development');
SELECT addHost('poc02.hf', 'Test box for scoreboard development (does not exist)');
SELECT addHost('poc03.hf', 'Test box for scoreboard development (does not exist)');
SELECT addHost('poc04.hf', 'Test box for scoreboard development (does not exist)');
SELECT addHost('poc05.hf', 'Test box for scoreboard development (does not exist)');
SELECT addHost('poc06.hf', 'Test box for scoreboard development (does not exist)');
SELECT addHost('poc07.hf', 'Test box for scoreboard development (does not exist)');
SELECT addHost('poc08.hf', 'Test box for scoreboard development (does not exist)');
SELECT addHost('poc09.hf', 'Test box for scoreboard development (does not exist)');
SELECT addHost('poc10.hf', 'Test box for scoreboard development (does not exist)');

SELECT addCategory('web', 'Web challenges', 'Description des web chals');
SELECT addCategory('bin', 'Binary challenges', 'Description des bin chals');
SELECT addCategory('expl', 'Exploit challenges', 'Description des exploits chals');
SELECT addCategory('win', 'Windows challenges', 'Description des windows chals');
SELECT addCategory('for', 'Forensics challenges', 'Description des forensics chals');
SELECT addCategory('tri', 'Trivia challenges', 'Description des trivia chals');
SELECT addCategory('rev', 'Reverse challenges', 'Description des reverse chals');

SELECT addAuthor('Martin Dube', 'mdube');
SELECT addAuthor('Jessy Campos', '_eko');
SELECT addAuthor('Cedrick Chaput', 'cechaput');

SELECT addRandomFlag('Test 1.1', 3::smallint, 'poc01.hf', 'web', 1::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag.txt', 'wget http://dathost/test');
SELECT addRandomFlag('Test 1.2', 3::smallint, 'poc01.hf', 'web', 1::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag.txt', 'wget http://dathost/test');
SELECT addRandomFlag('Test 1.3', 3::smallint, 'poc01.hf', 'web', 1::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag.txt', 'wget http://dathost/test');
SELECT addRandomFlag('Test 2', 5::smallint, 'poc01.hf', 'bin', 2::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag2.txt', 'wget http://dathost/test');
SELECT addRandomFlag('Test 3', 7::smallint, 'poc01.hf', 'expl', 3::smallint, Null, Null, True, '', '',
                     'echo $FLAG > /root/flag3.txt', 'wget http://dathost/test');
-- Testing invalid status
--SELECT addFlag('Flag 1', random_32(), 1, 'dathost', 'ssh root@$HOST "echo $FLAG > /root/flag.txt"', 'wget http://dathost/test', 4);
-- Testing invalid pts
--SELECT addFlag('Flag 1', random_32(), 11, 'dathost', 'ssh root@$HOST "echo $FLAG > /root/flag.txt"', 'wget http://dathost/test');

SELECT addFlag('Test 4.1', 'prepuce', 1::smallint, 'poc01.hf', 'rev', 1::smallint, Null, Null, True, '', ''
                'echo $FLAG > /root/flag4.1.txt', 'wget http://dathost/test');
SELECT addFlag('Test 4.2', 'agres', 2::smallint, 'poc01.hf', 'rev', 1::smallint, Null, Null, True, '', ''
                'echo $FLAG > /root/flag4.2.txt', 'wget http://dathost/test');
SELECT addFlag('Test 4.3', 'noob', 3::smallint, 'poc01.hf', 'rev', 1::smallint, Null, Null, True, '', ''
                'echo $FLAG > /root/flag4.3.txt', 'wget http://dathost/test');
--SELECT addFlag('Test 4.4', ':|!+"/_"!$)("/%*%$?&', 3::smallint, 'poc01.hf', 'rev', 1::smallint, Null, Null, True, '', ''
--                'echo $FLAG > /root/flag4.3.txt', 'wget http://dathost/test');

SELECT addKingFlagFromName('Test 1.1', random_32(), 1::smallint);
-- Testing erronous and disabled flags
--SELECT addKingFlagFromName('Test 2', random_32(), 1::smallint);
--SELECT addKingFlagFromName('Test 3', random_32(), 1::smallint);
-- Testing invalid flag
--SELECT addKingFlagFromName('Flag 4', random_32(), 1);

SELECT submitFlagFromIp('192.168.1.100', getFlagValueFromName('Test 1.1'));
SELECT submitFlagFromIp('192.168.1.101', getFlagValueFromName('Test 1.2'));
SELECT submitFlagFromIp('192.168.1.102', getFlagValueFromName('Test 1.3'));
-- Testing erronous and disabled flags
--SELECT submitFlagFromIp('192.168.1.100', getFlagValueFromName('Test 2'));
--SELECT submitFlagFromIp('192.168.1.100', getFlagValueFromName('Test 3'));
--SELECT submitFlagFromIp('192.168.9.100', getFlagValueFromName('Test 2'));
-- Testing invalid ip
--SELECT submitFlagFromIp('172.29.14.254', getFlagValueFromName('Flag 3'));
-- Testing already submited flag
--SELECT submitFlagFromIp('172.29.11.101', getFlagValueFromName('Flag 1'));

SELECT addNews('This is a random news', NOW()::timestamp);
SELECT addNews('This is another random news', NOW()::timestamp);
SELECT addNews('Ho yeah! A random news', NOW()::timestamp);
SELECT addNews('Really... another god damn news', NOW()::timestamp);
SELECT addNews('Fuck this news', NOW()::timestamp);
SELECT addNews('This news should never be printed', '2015-01-01 01:01'::timestamp);

SELECT insertRandomData();

/* 
    Settings
*/
INSERT INTO settings(gameStartTs) VALUES('2013-11-07 10:00'::timestamp);
