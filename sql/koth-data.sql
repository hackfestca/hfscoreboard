/*
Set default schema
*/
SET search_path TO scoreboard;

/*
    Delete existing data
*/
SELECT emptyTables();

/* 
    Real scoreboard data
*/
SELECT addStatus(1::smallint,'Enabled','The flag is functionnal');
SELECT addStatus(2::smallint,'Erronous','The flag is corrupted or fucked up');
SELECT addStatus(3::smallint,'Disabled','The flag is removed by admins');

SELECT addHost('172.28.71.10', 'OpenBSD5.5 x64', 'Scoreboard (scoreboard.hf)');
SELECT addHost('172.28.72.4', 'Debian 7 x32', 'Test box for scoreboard development (misc01.ctf.hf)');
SELECT addHost('172.28.72.5', 'Debian 7 x64', 'Chroot Challenges by _eko (chroot02.ctf.hf)');
SELECT addHost('172.28.72.6', 'Debian 7 x64', 'Misc Challenges by Mart (misc02.ctf.hf)');
SELECT addHost('172.28.72.7', 'Debian 7 x64', 'Exploit Challenges by _eko (expl01.ctf.hf)');
SELECT addHost('172.28.72.10', 'OpenBSD5.5 x64', 'Chroot & PHP Challenges by Mart (chroot01.ctf.hf)');
SELECT addHost('172.28.72.11', 'Debian 7 x64', 'Data mining Challenges by vn & Pat (dm01.ctf.hf)');
SELECT addHost('172.28.72.12', 'OpenBSD5.5 x64', 'Prog Challenges by _eko (prog01.ctf.hf)');
SELECT addHost('172.28.72.100', 'Ubuntu 14.04LTS', 'Ubuntu Forensics by Ced (wakinsun.ctf.hf)');
SELECT addHost('172.28.72.101', 'Windows 2012', 'Windows 2012 Challenges by Ced (windfeu.ctf.hf)');
SELECT addHost('172.28.72.110', 'CentOS 6 x64', 'Nose Bleeding Track by FLR (nosebleeding.ctf.hf)');
SELECT addHost('172.28.72.120', 'CentOS 6 x32', 'Monopoly Jail Escape Track by Martin L. (mono01.ctf.hf)');
SELECT addHost('172.28.72.121', 'CentOS 6 x32', 'VOIP Challenges by Martin L. (voip01.ctf.hf)');

SELECT addCategory('web', 'Web', 'Elastics Search & PHP');
SELECT addCategory('re', 'Reverse Engineering', 'Reverse Engineering challenges such as VMs, ..., ...');
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
SELECT addAuthor('Stephane Sigmen', 'sigmens');
SELECT addAuthor('HF Crew', 'HFCrew');

SELECT addNews('Welcome to Hackfest CTF 2014', NOW()::timestamp);

INSERT INTO settings(gameStartTs) VALUES('2013-11-07 10:00'::timestamp);

/*
    fake teams for tests
*/
SELECT addTeam('Team Dube', '192.168.1.0/24');
SELECT addTeam('Team HF DMZ', '192.168.6.0/24');
SELECT addTeam('Team VPN', '192.168.9.0/24');
SELECT addTeam('Team VPN 2', '192.168.10.0/24');
SELECT addTeam('Team VPN Pie', '192.168.13.0/24');
SELECT addTeam('Team HF Crew', '172.16.66.0/24');
SELECT addTeam('Team Eko', '127.0.0.1/8');
SELECT addTeam('Team Eko1', '1.1.1.1/32');
SELECT addTeam('Team Eko2', '1.1.1.2/32');
SELECT addTeam('Team Eko3', '1.1.1.3/32');
SELECT addTeam('Team Eko4', '1.1.1.4/32');
SELECT addTeam('Team Eko5', '1.1.1.5/32');
SELECT addTeam('Team Eko6', '1.1.1.6/32');
SELECT addTeam('Team Eko7', '1.1.1.7/32');
SELECT addTeam('Team Eko8', '1.1.1.8/32');

/*
    Insert random data (for scoreboard development)
*/
--SELECT insertRandomData();


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

