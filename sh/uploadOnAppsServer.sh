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
ssh root@$scoreboard3 "rm -r /var/www/htdocs/static/* /var/www/htdocs/public/*"
scp -rq static/* root@$scoreboard3:/var/www/htdocs/static/
scp -rq public/* root@$scoreboard3:/var/www/htdocs/public/
ssh root@$scoreboard3 "chown -R root:sb /var/www/htdocs/{public,static,blackmarket}"
ssh root@$scoreboard3 "find /var/www/htdocs/{public,static,blackmarket} -type d -exec chmod 755 {} \;"
ssh root@$scoreboard3 "find /var/www/htdocs/{public,static,blackmarket} -type f -exec chmod 644 {} \;"
echo Uploading on $scoreboard4
ssh root@$scoreboard4 "rm -r /var/www/htdocs/static/* /var/www/htdocs/public/*"
scp -rq static/* root@$scoreboard4:/var/www/htdocs/static/
scp -rq public/* root@$scoreboard4:/var/www/htdocs/public/
ssh root@$scoreboard4 "chown -R root:sb /var/www/htdocs/{public,static,blackmarket}"
ssh root@$scoreboard4 "find /var/www/htdocs/{public,static,blackmarket} -type d -exec chmod 755 {} \;"
ssh root@$scoreboard4 "find /var/www/htdocs/{public,static,blackmarket} -type f -exec chmod 644 {} \;"
