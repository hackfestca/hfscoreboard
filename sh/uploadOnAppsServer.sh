#!/bin/bash
scoreboardDev='scoreboard-dev.hf'
scoreboard1='sb-app01.hf'
scoreboard2='sb-app02.hf'
scoreboard3='sb-web01.hf'
scoreboard4='sb-web02.hf'

# dev
echo Uploading on $scoreboardDev
git archive --format=tar origin/master | gzip -9c | ssh root@$scoreboardDev "tar -C /var/www/scoreboard -xzvf -" > /dev/null
ssh root@$scoreboardDev "rm -r /var/www/htdocs/static/* /var/www/htdocs/public/*"
scp -rq static/* root@$scoreboardDev:/var/www/htdocs/static/
scp -rq public/* root@$scoreboardDev:/var/www/htdocs/public/

# apps
echo Uploading on $scoreboard1
git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard1 "tar -C /var/www/scoreboard -xzvf -" > /dev/null
echo Uploading on $scoreboard2
git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard2 "tar -C /var/www/scoreboard -xzvf -" > /dev/null

# web
echo Uploading on $scoreboard3
ssh sb@$scoreboard3 "rm -r /var/www/htdocs/static/* /var/www/htdocs/public/*"
scp -rq static/* sb@$scoreboard3:/var/www/htdocs/static/
scp -rq public/* sb@$scoreboard3:/var/www/htdocs/public/
echo Uploading on $scoreboard4
ssh sb@$scoreboard4 "rm -r /var/www/htdocs/static/* /var/www/htdocs/public/*"
scp -rq static/* sb@$scoreboard4:/var/www/htdocs/static/
scp -rq public/* sb@$scoreboard4:/var/www/htdocs/public/
