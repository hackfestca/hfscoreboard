#!/bin/bash
inFile=sh/ihack2015.flagNames.txt
outFile=sh/ihack2015.flagProgress.txt
cd ..
echo "" > $outFile
while read flagName; do echo $flagName >> $outFile && ./admin.py stat --flagProgress --flagName $flagName >> $outFile; done < $inFile
