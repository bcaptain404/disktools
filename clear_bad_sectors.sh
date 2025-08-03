#!/bin/bash

baddrive="$1"
badsect=1
while true; do
  echo Testing from LBA $badsect
  smartctl -t select,${badsect}-max ${baddrive} 2>&1 >> /dev/null

  echo "Waiting for test to stop (each dot is 5 sec)"
  while [ "$(smartctl -l selective ${baddrive} | awk '/^ *1/{print substr($4,1,9)}')" != "Completed" ]; do
    echo -n .
    sleep 5
  done
  echo

  badsect=$(smartctl -l selective ${baddrive} | awk '/# 1  Selective offline   Completed: read failure/ {print $10}')
  [ $badsect = "-" ] && exit 0

  echo Attempting to fix sector $badsect on $baddrive
  hdparm --repair-sector ${badsect} --yes-i-know-what-i-am-doing $baddrive
  echo Continuning test
done

