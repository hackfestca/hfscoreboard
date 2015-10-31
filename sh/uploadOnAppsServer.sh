#!/bin/bash
scoreboardDev='scoreboard-dev.hf'
scoreboard1='sb-app01.hf'
scoreboard2='sb-app02.hf'
scoreboard3='sb-web01.hf'
scoreboard4='sb-web02.hf'

# dev
echo Uploading on $scoreboardDev
git archive --format=tar origin/master | gzip -9c | ssh root@$scoreboardDev "tar -C /var/www/scoreboard -xzvf -" > /dev/null
scp -r static sb@$scoreboardDev:/var/www/htdocs/

# apps
echo Uploading on $scoreboard1
git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard1 "tar -C /var/www/scoreboard -xzvf -" > /dev/null
echo Uploading on $scoreboard2
git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard2 "tar -C /var/www/scoreboard -xzvf -" > /dev/null

# web
echo Uploading on $scoreboard3
scp -r static sb@$scoreboard3:/var/www/htdocs/
echo Uploading on $scoreboard4
scp -r static sb@$scoreboard4:/var/www/htdocs/
