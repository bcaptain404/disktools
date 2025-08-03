#!/bin/bash

#DEPENDENCY fdisk

if [[ "$#" != "1" ]] ; then
	echo "usage: $0 DISK_IMAGE"
	exit 1
fi

SAVEIFS=$IFS
IFS=$'\n'
ALL_DEVS=($(losetup -a | grep "$1"))
IFS=$SAVEIFS   # Restore IFS

if (( ${#ALL_DEVS[@]} > 1 )) ; then
  echo "more than one device found:" >&2
  for DEVICE in "${ALL_DEVS[@]}" ; do
    echo "$DEVICE" >&2
  done
  exit 1
fi

if (( ${#ALL_DEVS[@]} < 1 )) ; then
	echo "did not find image: $1" >&2
	exit 1
fi

LINE="${ALL_DEVS[0]}"
DEV=$(echo "${ALL_DEVS[0]}" | cut -d':' -f1 )
IMG=$(echo "${ALL_DEVS[0]}" | cut -d' ' -f3 | sed 's/^(\(.*\))$/\1/g' )

echo "## found: $DEV at $IMG" >&2

#DEVS=($(losetup -j /recover/nowtower.dd | cut -f1 -d' ' | sed 's/:$//g'))

DISK_TYPE=$(fdisk -l "$IMG" 2>/dev/null | grep 'Disklabel\ type:' | cut -f3 -d' ')

RET=0
UNMOUNTED=0
for MOUNT in ${DEV}* ; do
	# bash filename expansion doesn't work if files don't exist, so we use the loop device that we know exists
	if [[ "$MOUNT" == "${DEV}" ]] ; then
		continue;
	fi
	echo "## unmounting: [$DISK_TYPE] $MOUNT"
	if (( $? != 0 )) ; then
		((RET++))
	else
		((UNMOUNTED++))
	fi
done

if (( $UNMOUNTED > 0 )) ; then
	echo "unmounted $UNMOUNTED partitions" >&2
fi

if (( $RET > 0 )) ; then
	echo "failed to unmount $RET partitions" >&2
	exit
fi	

echo "## unlooping: [$DISK_TYPE] $DEV"
losetup -D "$DEV"


