#!/bin/bash
scoreboardDev='scoreboard-dev.hf'
scoreboard1='sb-app01.hf'
scoreboard2='sb-app02.hf'
scoreboard3='sb-web01.hf'
scoreboard4='sb-web02.hf'
echo Uploading on $scoreboardDev
git archive --format=tar origin/master | gzip -9c | ssh root@$scoreboardDev "tar -C /var/www/scoreboard -xzvf -" > /dev/null
echo Uploading on $scoreboard1
git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard1 "tar -C /var/www/scoreboard -xzvf -" > /dev/null
echo Uploading on $scoreboard2
git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard2 "tar -C /var/www/scoreboard -xzvf -" > /dev/null
echo Uploading on $scoreboard3
git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard3 "tar -C /var/www/scoreboard -xzvf -" > /dev/null
echo Uploading on $scoreboard4
git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard4 "tar -C /var/www/scoreboard -xzvf -" > /dev/null
