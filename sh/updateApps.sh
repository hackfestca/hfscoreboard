#!/bin/bash
scoreboard0='172.28.71.13'
scoreboard1='172.28.70.22'
scoreboard2='172.28.70.23'
git archive --format=tar origin/master | gzip -9c | ssh root@$scoreboard0 "tar -C /var/www/scoreboard -xzvf -"
#git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard1 "tar -C /var/www/scoreboard -xzvf -"
#git archive --format=tar origin/master | gzip -9c | ssh sb@$scoreboard2 "tar -C /var/www/scoreboard -xzvf -"
