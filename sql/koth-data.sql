/*
Set default schema
*/
SET search_path TO scoreboard;

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
SELECT addTeam('Porku Pie', '192.168.13.0/24');
SELECT addTeam('Team Eko', '127.0.0.1/8');

SELECT addStatus(1::smallint,'Enabled','The flag is functionnal');
SELECT addStatus(2::smallint,'Erronous','The flag is corrupted or fucked up');
SELECT addStatus(3::smallint,'Disabled','The flag is removed by admins');

SELECT addHost('172.28.72.4', 'Test box for scoreboard development (misc01.ctf.hf)');
SELECT addHost('172.28.72.5', 'Chroot Challenges by _eko - Debian 7 x64 - chroot02.ctf.hf');
SELECT addHost('172.28.72.6', 'Misc Challenges by Mart - Debian 7 x64 - misc02.ctf.hf');
SELECT addHost('172.28.72.10', 'Chroot & PHP Challenges by Mart - OpenBSD 5.5 x64 - chroot01.ctf.hf');
SELECT addHost('172.28.72.11', 'Data mining Challenges by vn & Pat - Openbsd 5.5 x64 - dm01.ctf.hf');
SELECT addHost('172.28.72.12', 'Prog Challenges by _eko - OpenBSD5.5 x64 - prog01.ctf.hf)');
SELECT addHost('172.28.72.100', 'Ubuntu Forensics by Ced - Ubuntu 14.04LTS - wakinsun.ctf.hf');
SELECT addHost('172.28.72.101', 'Windows 2012 Challenges by Ced - Windows 2012 - windfeu.ctf.hf');
SELECT addHost('172.28.72.110', 'Nose Bleeding Track by FLR - CentOS 6 x64 - nosebleeding.ctf.hf');

SELECT addCategory('web', 'Web', 'Elastics Search & PHP');
SELECT addCategory('rev', 'Reverse Engineering', 'Reverse Engineering challenges such as VMs, ..., ...');
SELECT addCategory('for', 'Forensics', 'Ubuntu, Windows 2012 and Virus Analysis');
SELECT addCategory('expl', 'Pwning', 'Exploitation challenges from linux to windows. Chroot escape & abuse');
SELECT addCategory('prog', 'Programming', 'Programming challenges');
SELECT addCategory('data', 'Data Mining', 'Data mining challenges');
SELECT addCategory('misc', 'Miscellaneous', 'penis related && ascii port && firewall rule bypass');
SELECT addCategory('tri', 'Trivia', 'Chuck Norris stuff');
SELECT addCategory('net', 'Networking', 'VOIP Challenges');

SELECT addAuthor('Martin Dube', 'mdube');
SELECT addAuthor('Jessy Campos', '_eko');
SELECT addAuthor('Cedrick Chaput', 'cechaput');
SELECT addAuthor('Pierre-Yves Tremblay', 'hidden');
SELECT addAuthor('Franck Desert', 'hiddenman');
SELECT addAuthor('Francois Lajeunesse-Robert', 'FLR');
SELECT addAuthor('Martin Lemay', 'Do.Z10');
SELECT addAuthor('Vincent & Patrick', 'vn & pat');
SELECT addAuthor('Stephane Sigmens', 'sigmens');

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
-- Testing invalid status
--SELECT addFlag('Flag 1', random_32(), 1, 'dathost', 'ssh root@$HOST "echo $FLAG > /root/flag.txt"', 'wget http://dathost/test', 4);
-- Testing invalid pts
--SELECT addFlag('Flag 1', random_32(), 11, 'dathost', 'ssh root@$HOST "echo $FLAG > /root/flag.txt"', 'wget http://dathost/test');

--SELECT addFlag('Test 4.1', 'prepuce', 1::smallint, '172.28.72.4', 'rev', 1::smallint, Null, Null, True, '', '',
--                'echo $FLAG > /root/flag4.1.txt', 'wget http://dathost/test');
--SELECT addFlag('Test 4.2', 'agres', 2::smallint, '172.28.72.4', 'rev', 1::smallint, Null, Null, True, '', '',
--                'echo $FLAG > /root/flag4.2.txt', 'wget http://dathost/test');
--SELECT addFlag('Test 4.3', 'noob', 3::smallint, '172.28.72.4', 'rev', 1::smallint, Null, Null, True, '', '',
--                'echo $FLAG > /root/flag4.3.txt', 'wget http://dathost/test');
--SELECT addFlag('Test 4.4', ':|!+"/_"!$)("/%*%$?&', 3::smallint, '172.28.72.4', 'rev', 1::smallint, Null, Null, True, '', ''
--                'echo $FLAG > /root/flag4.3.txt', 'wget http://dathost/test');

--SELECT addKingFlagFromName('Test 1.1', random_32(), 1::smallint);
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

/*
    Mart Stuff
*/

/*
    FLR Stuff
*/

SELECT addFlag('nose01', 'FLAG-OIPL9CKSV2DH9X1SAQGQ', 1, '172.28.72.110', 'web',
                    1, Null, 'Francois Lajeunesse-Robert', False, '', '', '', '');
SELECT addFlag('nose02', 'FLAG-7G27Y966ACQO9MSUGICP', 2, '172.28.72.110', 'web',
                    1, Null, 'Francois Lajeunesse-Robert', False, '', '', '', '');
SELECT addFlag('nose03', 'FLAG-7AYV63FG19UCCD8ACBAO', 3, '172.28.72.110', 'web',
                    1, Null, 'Francois Lajeunesse-Robert', False, '', '', '', '');
SELECT addFlag('nose04', 'KOTH-NOSEBLEEDING', 5, '172.28.72.110', 'web',
                    1, Null, 'Francois Lajeunesse-Robert', True, '', '', 
                    'echo $FLAG > /opt/cs/frontend/config/flag.txt && chown root:csservice /opt/cs/frontend/config/flag.txt', '');

