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

SELECT addHost('scoreboard.hf', 'OpenBSD5.5 x64', 'Scoreboard');
SELECT addHost('172.28.72.4', 'Debian 7 x32', 'Test box for scoreboard development (misc01.ctf.hf)');
SELECT addHost('172.28.72.5', 'Debian 7 x64', 'Chroot Challenges by _eko (chroot02.ctf.hf)');
SELECT addHost('172.28.72.6', 'Debian 7 x64', 'Misc Challenges by Mart (misc02.ctf.hf)');
SELECT addHost('172.28.72.7', 'Debian 7 x64', 'Exploit Challenges by _eko (expl01.ctf.hf)');
SELECT addHost('172.28.72.8', 'Debian 7 x64', 'Exploit Challenges by _eko (expl02.ctf.hf)');
SELECT addHost('172.28.72.10', 'OpenBSD5.5 x64', 'Chroot & PHP Challenges by Mart (chroot01.ctf.hf)');
SELECT addHost('172.28.72.11', 'Debian 7 x64', 'Data mining Challenges by vn & Pat (dm01.ctf.hf)');
SELECT addHost('172.28.72.12', 'OpenBSD5.5 x64', 'Prog Challenges by _eko (prog01.ctf.hf)');
SELECT addHost('172.28.72.100', 'Ubuntu 14.04LTS', 'Ubuntu Forensics by Ced (wakinsun.ctf.hf)');
SELECT addHost('172.28.72.101', 'Windows 2012', 'Windows 2012 Challenges by Ced (windfeu.ctf.hf)');
SELECT addHost('172.28.72.103', 'Ubuntu 14.04LTS', 'Ubuntu server by Ced (alogator.ctf.hf)');
SELECT addHost('172.28.72.104', 'Ubuntu 14.04LTS', 'Ubuntu lock screen bypass by Ced (lockubuntu.ctf.hf)');
SELECT addHost('172.28.72.105', 'Windows 2012', 'Windows 2012 Challenges by sigs (w2012adm.ctf.hf)');
SELECT addHost('172.28.72.106', 'Windows 2012', 'Windows 2012 Challenges by sigs (w2012usr.ctf.hf)');
SELECT addHost('172.28.72.107', 'Windows 2012', 'Windows 2012 Challenges by sigs (w2012usr.ctf.hf)');
SELECT addHost('172.28.72.110', 'CentOS 6 x64', 'Nose Bleeding Track by FLR (nosebleeding.ctf.hf)');
SELECT addHost('172.28.72.120', 'CentOS 6 x32', 'Monopoly Jail Escape Track by Martin L. (mono01.ctf.hf)');
SELECT addHost('172.28.72.121', 'CentOS 6 x32', 'VOIP Challenges by Martin L. (voip01.ctf.hf)');
SELECT addHost('172.28.72.130', 'Debian 7 x32', 'Mostly BOF challenges by P-Y. (expl02.ctf.hf)');
SELECT addHost('172.28.72.140', 'ArchARM', 'Exploit Challenges by _eko (rpi.ctf.hf)');

SELECT addCategory('web', 'Web', 'Elastics Search & PHP');
SELECT addCategory('re', 'Reverse Engineering', 'Reverse Engineering challenges such as VMs and binaries analysis');
SELECT addCategory('for', 'Forensics', 'Chroot, Data and Virus Analysis');
SELECT addCategory('expl', 'Pwning', 'Exploitation challenges from linux to windows. ');
SELECT addCategory('prog', 'Programming', 'Programming challenges, All the challenges search the answer in the "result" parameter, in the POST request.');
SELECT addCategory('data', 'Data Mining', 'Data mining challenges');
SELECT addCategory('misc', 'Misconfiguration', 'Misconfiguration challenges');
SELECT addCategory('tri', 'Trivia', 'Chuck Norris Questions');
SELECT addCategory('net', 'Networking', 'VOIP Challenges, firewall rule bypass');
SELECT addCategory('rand', 'Random Shit', 'Processor analysis');
SELECT addCategory('bug', 'Bug Bounty', 'Bug Bounty Policy. Flags given for teams who raise security issues in the infrastructure. These are one timers.',True);
SELECT addCategory('virus', 'Virus Analysis', '<ul>
<li>You will find a Windows 7 VM in the USB key given to your team. This VM was tested with VirtualBox 4.3.18 r96516. You need Oracle VM VirtualBox Extension Pack ot run the VM. <a href=""https://www.virtualbox.org/wiki/Downloads"">Download here</a></li>
<li>You need Your mission: boot the VM and find a way to <b>disable</b> the spreaded virus from running.</li>
<li>You are admin and your password is HFWPhenix. </li>
<li>Use the WPhenixChecker.exe on desktop to verify your cleanup. This binary will pop you up to 5 flags for successful permanent cleanup. </li>
<li>Trying to reverse WPhenixChecker.exe might give you headache. The challenge should be done without reversing this binary.</li>
<li>We strongly suggest you make a copy of the VM before booting it. </li>
</ul>');

SELECT addAuthor('Martin Dube', 'mdube');
SELECT addAuthor('Jessy Campos', '_eko');
SELECT addAuthor('Cedrick Chaput', 'cechaput');
SELECT addAuthor('Pierre-Yves Tremblay', 'hidden');
SELECT addAuthor('Franck Desert', 'hiddenman');
SELECT addAuthor('Francois Lajeunesse-Robert', 'FLR');
SELECT addAuthor('Martin Lemay', 'Do.Z10');
SELECT addAuthor('Vincent & Patrick', 'vn & pat');
SELECT addAuthor('Stephane Sigmen', 's1g5');
SELECT addAuthor('Philippe Godbout', 'psyker156');
SELECT addAuthor('HF Crew', 'HFCrew');

SELECT addNews('Welcome to Hackfest CTF 2014 !', NOW()::timestamp);

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

-- Tests
SELECT addFlag('Test Flag 2014-10-25', 'KOTH-TESTTEST', 100::smallint, '172.28.72.4', 'misc', 
                1::smallint, Null, Null, True, '', '',
                'echo $FLAG > /home/hf/flag-koth.txt && chown root:hf /home/hf/flag-koth.txt && chmod 640 /home/hf/flag-koth.txt', 
                'wget http://dathost/test');


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

