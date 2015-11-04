#!/bin/bash

P='../'

$P./player.py score

$P./player.py submit Hs17K6LakjDeTeLlwoQ5gVGP
$P./player.py submit d21c4c7507d792b50e356ec348adaff0
$P./player.py submit shitfuck

$P./player.py bm --list
$P./player.py bm --list-categories
$P./player.py bm --list-status

$P./player.py bm --info 2
$P./player.py bm --get 2
$P./player.py bm --buy 2

# MUST NOT BE RUN DURING CONTEST
$P./admin.py team --launder '57|10000'
$P./player.py bm --buy 2
$P./player.py bm --get 2
$P./player.py bm --info 2

# Test sell
$P./player.py bm --sell 'TestItem|This is a test item. Do not buy it.|./cronjob.txt|7500|2' # ok
$P./player.py bm --sell 'TestItem2|This is a test item. Do not buy it.|./gendoc.sh|7500'    # ok
$P./player.py bm --sell 'TestItem|This is a test item. Do not buy it.|./gendoc.sh|7500'     # Already exist
$P./player.py bm --sell 'TestItemTooBig|This is a test item. Do not buy it.|/home/martin/Pictures/2015-07-18-163432_874x830_scrot.png|7500'    # File too big
$P./player.py bm --info 2
$P./admin.py bm --allow '13|4|Wow this is a nice item'
$P./admin.py bm --deny '14|0|This is bullshit'

# Test from kali
# ./admin.py team --launder '56|10000'
# wait 1 minute
# ./player.py bm --buy 14
# ./player.py bm --buy 13

$P./player.py catProg
$P./player.py flagProg
$P./player.py news
$P./player.py info
$P./player.py secrets
