#!/bin/bash

#NOTE: apparently fdisk can wipe disks like this. with the --wipe option/

if [[ "$#" != 1 ]] ; then
	echo "Usage: $0 [/dev/sdX] # QUICK WIPE A DISK"
	exit 1
fi

#TODO: unmount
#TODO: unloop etc

echo "## Wiping $1"
BS=1000
COUNT=1
DISK="$1"
DISK_BYTES=$(fdisk -l "$DISK" | head -n 1 | sed 's/,/\n/g' | grep bytes | tr -d [a-z\ ])
START_POS=$(($DISK_BYTES-($BS*$COUNT)))
END_POS=$((START_POS+$BS*$COUNT))
echo "$DISK_BYTES  $DISK"
echo "$BS  block size"
echo "$COUNT  block count to write"
echo "$((START_POS))  start pos"
echo "$((END_POS))  end pos"

echo ""
echo "wipefs -a $DISK ; sync $DISK"
echo "CMD: dd if=/dev/zero of=$DISK bs=$BS count=$COUNT status=progress conv=sync,noerror ; sync $DISK"
echo "CMD: dd if=/dev/zero of=$DISK bs=$BS count=$COUNT skip=$START_POS status=progress conv=sync,noerror ; sync $DISK"
echo ""
echo "WILL WIPE DISK: $DISK"
echo ""
echo "waiting 5 seconds..."
sleep 5

sync "$DISK"
wipefs -a "$DISK"
sync "$DISK"
dd if=/dev/zero of=$DISK bs=$BS count=$COUNT status=progress conv=sync,noerror
sync "$DISK"
dd if=/dev/zero of=$DISK bs=$BS count=$COUNT skip=$START_POS status=progress conv=sync,noerror
sync "$DISK"
echo "Syncinc $DISK"
sync "$DISK"


