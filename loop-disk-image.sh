#!/bin/bash
#DEPENDENCY fdisk

function GO( ) {

	if (( $# < 1 )) ; then
		echo "usage: $0 DISK_IMAGE {opts}"
		exit 1
	fi

	#IMG="$1"
	#shift 1
	#DISK_TYPE=$(fdisk -l "$IMG" 2>/dev/null | grep 'Disklabel\ type:' | cut -f3 -d' ')
	#DEV=$(losetup -f -L --show -P "$@""$IMG")
	#sleep 0.5 # give kernel time to make partition devices

	#if [[ "$?" == "0" ]] ; then
		#echo "## $DEV: [$DISK_TYPE] $IMG"
		#for file in "$DEV"p* ; do
			#echo "## $file"
		#done
	#fi

	local LDEV
	LDEV="$(losetup -f -L --show -P "$@")"
	if (( $? != 0 )) ; then
		exit 1
	fi

	for file in "$LDEV" "$LDEV"p* ; do
		echo "## $file"
	done

}

GO "$@"


