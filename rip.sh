#!/bin/bash
#rip-F2D.sh

#DEPENDENCY gddrescue
#DEPENDENCY fdisk

source /cbin/util/util.sh || exit 1

function go() {
  local SKIP_END="0"
  local SZ="-s"
  local CUST_SZ="-z"
  local QCOW="-q"
  local AMT=""
  local UTIL="ddrescue"
  local NOPROGRESS="-p"
  
  local SHOW_PROGRESS="1"
  
  if [[ "$#" < "2" ]] ; then
    echo "usage: rip SRC DST"
    echo ""
    echo "  Will rip a disk or disk image, to another disk or disk image."
    echo "  Uses gddrescue to accomplish this, and always uses a map file."
    echo "  The type of SRC and DST will be determined to be a block device"
    echo "  or a file, and appropriate read/write settings for gddrescue"
    echo "  will be automatically determined."
    echo ""
    echo "Ripping will not start until the user confirms by pressing Y"
    echo ""
    echo "Options:"
    echo ""
    echo " $SZ    Don't copy past end of SRC's partitions"
    echo " $CUST_SZ x  copy this amount only"
    echo " $QCOW  convert to qcow2 image instead of raw"
    echo " $PRORESS  dont calculate progress of non-file devices when possible"
    echo ""
    echo "  rip /dev/sda /tmp/rip.dd      # ddrescue --idirect /dev/sda /tmp/rip.dd /tmp/rip.map --force"
    echo "  rip /dev/sda /tmp/rip.dd --map=/tmp/other.map  # ddrescue --idirect /dev/sda /tmp/rip.dd /tmp/other.map --force"
    echo "  rip /dev/sda /dev/sdb --map=/tmp/rip.map  # ddrescue --idirect /dev/sda --odirect /dev/sdb /tmp/rip.map --force"
    echo "  rip /tmp/rip.dd /dev/sdb --map=/tmp/rip.map  # ddrescue /tmp/rip.dd --odirect /dev/sdb /tmp/rip.map --force"
    echo ""
    exit 1
  fi
  
  local ARGS=()
  local FR
  local TO
  local i; for (( i=1; i<=$#; ++i )) ; do
    local arg="${!i}"
    if [[ "${arg:0:5}" == "--map" ]] ; then
      local len=${#arg}
      SPECIFIED_MAP="${arg:6:$len}"
    elif [[ "$arg" == "$CUST_SZ" ]] ; then
      let i=$i+1
      AMT="--size=${!i}"
    elif [[ "$arg" == "$QCOW" ]] ; then
      UTIL='qemu-img'
    elif [[ "$arg" == "$NOPROGRESS" ]] ; then
      SHOW_PROGRESS="0"
    elif [[ "$arg" == "$SZ" ]] ; then
      SKIP_END="$arg"
    elif [[ "$FR" == "" ]] ; then
	FR="$arg"
    elif [[ "$TO" == "" ]] ; then
	TO="$arg"
    else
      ARGS+=("$arg")
    fi
  done
  
  local FR_DIR="`dirname "$FR"`"
  local TO_DIR="`dirname "$TO"`"
  local TO_NAME="`basename "$TO"`"
  local FR_NAME="`basename "$FR"`"
  
  local FR_TYPE=""
  local FR_OPTS=""
  local TO_TYPE=""
  local TO_OPTS=""
  local MAP_OPTS=""
  
  if [ -b "$FR" ] ; then
    FR_NEW="existing"
    FR_OPTS="--idirect"
    FR_TYPE="device"
  elif [ -f "$FR" ] ; then
    FR_NEW="existing"
    FR_TYPE="file"
  elif [ ! -e "$FR" ] ; then
    FR_NEW="new"
    FR_TYPE="file"
    Die "Source does not exist: $FR"
  else
    Die "Could not determine source file type: $FR"
  fi
  
  local MAP=""
  local TO_NEW=""
  if [ -b "$TO" ] ; then
    TO_NEW="existing"
    TO_OPTS="--odirect"
    TO_TYPE="device"
    [ -f "$FR" ] && MAP="./$(basename "${FR%.*}")-to-$(basename "${TO%.*}").map"
  elif [ -f "$TO" ] ; then
    TO_NEW="existing"
    TO_TYPE="file"
    MAP="$(basename "${TO}")"
    MAP="${MAP%.dd}.map"
  elif [ ! -e "$TO" ] ; then
    TO_NEW="new"
    MAP="$(basename "${TO}")"
    MAP="${MAP%.dd}.map"
    TO_TYPE="file"
  else
    Die "Could not determine target file type: $TO"
  fi
  
  [[ "$MAP" == "" ]] && MAP="./$(basename "${FR%.*}")-to-$(basename "${TO%.*}").map"
  
  if [[ "$SPECIFIED_MAP" != "" ]] ; then
    MAP="$SPECIFIED_MAP"
  fi
  
  local MAP_NEW=""
  local MAP_MSG=""
  if [ -e "$MAP" ] ; then
    MAP_OPTS="-I"
    MAP_MSG=" with EXISTING map "
    MAP_NEW="existing"
  else
    MAP_MSG=" with NEW map "
    MAP_NEW="new"
  fi
  
  if [[ "$MAP" == "" ]] ; then
    Die "No map file specified or could be auto generated"
  fi
  
  if [ -e "$TO" ] ; then
    if [[ "$TO_TYPE" != "device" ]] && [ ! -e "$MAP" ] ; then
      Die "Target exists but has no map..."
    fi
  elif [ -e "$MAP" ] ; then
    Die "Target doesn't exists but a map exists for it already..."
  fi
  
  if [ -e "$MAP" ] && IsSameFile "$MAP" "$TO" ; then
    Die "Cannot continue, files have same inode."
  fi
  
  if [ -e "$TO" ] && IsSameFile "$FR" "$TO" ; then
    Die "Cannot continue, files have same inode."
  fi
  
  local FR_DISK_TYPE=$(fdisk -l "$FR" 2>/dev/null | grep 'Disklabel\ type:' | cut -f3 -d' ')
 
  if [[ "$SKIP_END" == "$SZ" ]] ; then
    FR_DISK_TYPE=$(fdisk -l "$FR" | grep '^Disklabel type: ' | sed 's/^Disklabel type: \(.*\)/\1/g')
    if [[ "$FR_DISK_TYPE" == "gpt" ]] ; then
      echo "($S): This feature has not yet been implemented for GPT disks"
      exit 1
      # https://www.ntfs.com/guid-part-table.htm
    fi
  
    local SEC=$(fdisk -l /dev/loop5 | grep '^Sector size ' | sed 's/[^:]*: \([0-9]*\).*/\1/g')
    local END=$(fdisk -l /dev/loop5 | grep '^/dev/loop5' | tail -n 1 | sed 's/\s\s*/\t/g' | cut -f 3)
  
    echo "# Sector Size: $SEC"
    echo "# Partitions End: $END"
  
    local GPT_SIZE=0
    local GPT_END=0
    local GPT_SIZE=0
  
    if [[ "$FR_DISK_TYPE" == "gpt" ]] ; then
      local ZERO_SECTION=420
      local GPT_SIZE=$( echo "92+($SEC*ZERO_SECTION)" | bc )
      local GPT_END=$( echo "${END}+${GPT_SIZE}" | bc )
  
      echo "# GPT Size: $GPT_SIZE"
      echo "# GPT End: $GPT_END"
    fi
  
    local BYTES=$(echo "${SEC}*${END}+${GPT_SIZE}" | bc)
  
    echo "# Total Bytes: $BYTES"
    FR_OPTS="${FR_OPTS} -s ${BYTES}"
  fi
 
  {
    echo "" $'\t' "STATUS" $'\t' "TYPE" $'\t' "PRT" $'\t' "LOC" 
    echo "From:" $'\t' "${FR_NEW}" $'\t' "${FR_TYPE}" $'\t' "${FR_DISK_TYPE}" $'\t' "$FR"
    echo "  To:" $'\t' "${TO_NEW}" $'\t' "${TO_TYPE}" $'\t' "-" $'\t' "$TO"
    echo " Map:" $'\t' "${MAP_NEW}" $'\t' "-" $'\t' "-" $'\t' "$MAP"
  } | column -t -s$'\t'

  if [[ "$UTIL" == "ddrescue" ]] ; then
    touch "$MAP" || Die "Cannot continue: cannot open mapfile for writing"
    echo " CMD: " \
    $UTIL $FR_OPTS "$FR" $TO_OPTS "$TO" $MAP_OPTS "$MAP" $AMT "${ARGS[@]}" --force
    PromptToContinue || exit 1
    time \
    $UTIL $FR_OPTS "$FR" $TO_OPTS "$TO" $MAP_OPTS "$MAP" $AMT "${ARGS[@]}" --force
  else
    local FR_SIZE=0
    if [[ "$SHOW_PROGRESS" == "1" ]] ; then
      if [[ "$FR_TYPE" == "device" ]] ; then
        FR_SIZE="$(blockdev --getsize64 "$FR")"
      else
        FR_SIZE="$(du -sb "$FR" | cut -f1)"
      fi
    fi
    echo " CMD: " \
    qemu-img convert -f raw -O qcow2 "$FR" "${TO%.*}.qcow2" "${ARGS[@]}"
    PromptToContinue || exit 1
    time
    qemu-img convert -f raw -O qcow2 "$FR" "${TO%.*}.qcow2" "${ARGS[@]}" &
    PID="$!"

    while ps | grep "$PID" ; do
      if [[ "$FR_TYPE" != "device" ]] ; then
        FR_SIZE="$(du -sb "$FR" | cut -f1)"
      elif [[ "$NOPROGRESS" == "1" ]] ; then
        FR_SIZE="$(blockdev --getsize64 "$FR")"
      else
        FR_SIZE="[uncalculated]"
      fi

      if [[ "$TO_TYPE" != "device" ]] ; then
        TO_SIZE="$(du -sb "$TO" | cut -f1)"
      elif [[ "$NOPROGRESS" == "1" ]] ; then
        TO_SIZE="$(blockdev --getsize64 "$TO")"
      else
        TO_SIZE="[uncalculated]"
      fi

      printf "%s" "## Status: [$FR_TYPE] FR: $FR_SIZE "
      printf "%s" " [$TO_TYPE] TO: $TO_SIZE "
      printf "\b"

      sleep 1
    done
    wait
  fi

  sync "$TO"
 }

go "$@"
 
