#!/bin/bash
outFile=sh/ihack2015.teamProgress.txt
nbOfTeams=21
cd ..
echo "" > $outFile
for id in `seq 1 $nbOfTeams`; do echo Team id: $id >> $outFile && ./admin.py stat --teamProgress --id $id >> $outFile; done
