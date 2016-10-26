#!/bin/bash
#scoreboardDev='sb-db01.hf'
app01='sb-app01.hf'
web01='sb-web01.hf'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#ssh-add ~/.ssh/id_ed25519_hf2k16

# dev
#echo Uploading on $scoreboardDev
#git archive --format=tar origin/master | gzip -9c | ssh root@$scoreboardDev "tar -C /var/www/scoreboard -xzvf -" > /dev/null
#ssh root@$scoreboardDev "rm -r /var/www/htdocs/static/* /var/www/htdocs/public/*"
#scp -rq static/* root@$scoreboardDev:/var/www/htdocs/static/
#scp -rq public/* root@$scoreboardDev:/var/www/htdocs/public/

## apps
echo [$app01] Uploading
git archive --format=tar origin/master | gzip -9c | ssh root@$app01 "tar -C /home/sb/scoreboard -xzvf -" > /dev/null
echo [$app01] Applying security
ssh root@$app01 "chown -R sb:sb /home/sb/scoreboard"
echo [$app01] Restarting Apps
ssh root@$app01 "supervisorctl restart all"
#echo Uploading on app02$
#git archive --format=tar origin/master | gzip -9c | ssh sb@$app02 "tar -C /var/www/scoreboard -xzvf -" > /dev/null
#
## web
echo [$web01] Deleting old files
ssh root@$web01 "rm -r /var/www/htdocs/static/* /var/www/htdocs/public/* /var/www/htdocs/blackmarket/*"
echo [$web01] Uploading
scp -rq $DIR'/../static/'* root@$web01:/var/www/htdocs/static/
scp -rq $DIR'/../public/'* root@$web01:/var/www/htdocs/public/
echo [$web01] Applying security
ssh root@$web01 "chown -R root:sb /var/www/htdocs/{public,static,blackmarket}"
ssh root@$web01 "find /var/www/htdocs/{public,static,blackmarket} -type d -exec chmod 775 {} \;"
ssh root@$web01 "find /var/www/htdocs/{public,static,blackmarket} -type f -exec chmod 664 {} \;"
#echo Uploading on $scoreboard4
#ssh root@$scoreboard4 "rm -r /var/www/htdocs/static/* /var/www/htdocs/public/*"
#scp -rq static/* root@$scoreboard4:/var/www/htdocs/static/
#scp -rq public/* root@$scoreboard4:/var/www/htdocs/public/
#ssh root@$scoreboard4 "chown -R root:sb /var/www/htdocs/{public,static,blackmarket}"
#ssh root@$scoreboard4 "find /var/www/htdocs/{public,static,blackmarket} -type d -exec chmod 775 {} \;"
#ssh root@$scoreboard4 "find /var/www/htdocs/{public,static,blackmarket} -type f -exec chmod 664 {} \;"
