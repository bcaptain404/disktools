#!/bin/bash
#dependency:smartctl
#dependency:bc
source /cbin/util/util.sh || exit 1

TOTAL_LOG=""
function LOG() {
	TOTAL_LOG="$(printf "${TOTAL_LOG}\n${*}")"
	echo "$*"
}

function Go() {
	local LOG_FILE="$(basename $1).$(date +%Y%m%d-%H%M%S-%N).smart"
	local DEV="$1"

	echo "## Log file is: $LOG_FILE"

	function ECHO() {
		echo "$*" | tee -a "$LOG_FILE"
	}

	local INFO="$( smartctl -i "$DEV" )"
	ECHO "## $DEV: INFO"
	ECHO "$INFO"

	ECHO "$INFO" | grep "Available - device has SMART capability" 1>/dev/null
	local AVAILABLE=$?
	if (( $AVAILABLE != 0 )) ; then
		LOG "## $DEV: SMART not available. Exiting."
		exit 1
	fi

	ECHO "$INFO" | grep "SMART support is: Enabled" 1>/dev/null
	local ENABLED=$?

	#ECHO "$INFO" | grep "SMART support is: Disabled" ? 1/dev/null
	#local DISABLED=$?

	if (( $ENABLED == 0 )) ; then
		LOG "## $DEV: SMART is already Enabled."
	else
		echo "## $DEV: Enable Smart?"
		PromptToContinue || {
			LOG "## $DEV: User chose not to enable SMART. Nothing left to do. Exiting."
			exit 0
		}

		LOG "## $DEV: Enabling SMART..."
		INFO="$(sudo smartctl -s "$DEV")"
		ECHO "$INFO" | tail | grep "SMART Enabled." 1>/dev/null
		ENABLED=$?
	fi

	if (( $ENABLED != 0 )) ; then
		LOG "## $DEV: SMART could not be enabled. Exiting."
		exit 2
	fi

	LOG "## $DEV: SMART is now Enabled."

	ECHO "$INFO" | grep "No self-tests have been logged" 1>/dev/null
	if (( $? == 0 )) ; then
		LOG "## $DEV: Test has never been run"
	fi

	LOG "## $DEV: getting first stat..."
	local FIRST_STAT="$(smartctl -a "$DEV")"
	LOG "## $DEV: SMART Info:"
	ECHO "$FIRST_STAT"

	function CHECK_CUR_TEST() {
		ECHO "$FIRST_STAT" | grep "Self_test_in_progress" 1>/dev/null
		if (( $? == 0 )) ; then
			LOG "## $DEV: Smart test is already in progress. Monitoring, then will Exit."
			MONITOR
			exit 1
		fi
	}

	function CHECK_SECTORS() {
		LOG "## $DEV: Checking sectors..."

		local POOP="$( smartctl -a "$DEV" | egrep -i '(Reallocated|Current_Pending)_Sector' | sed 's/^.*\s\([0-9][0-9]*\)[ ]*$/\1/g' | tr -d '\n' )"

		if [[ "$POOP" == "" ]] ; then
			LOG "## $DEV: There was a problem with this script. Exiting."
			exit 3
		fi

		if (( $POOP > 0 )) ; then
			LOG "## $DEV: DISK HAS BAD SECTORS. Back up everything. Exiting."
			exit 4
		fi

		LOG "## $DEV: Sectors report zero problems."
	}

	function CHECK_RESULT() {
		#local OUTPUT="$(smartctl -a "$DEV" | grep -A 1000 Test_Description)"
		sudo smartctl -a "$DEV" | grep -A 1000 Test_Description | grep -C1000 error -i
	}

	function PRINT_ELAPSED() {
		let Elapsed="$(date +%s)"-"$1"

		let s=$Elapsed%60
		let Elapsed=$Elapsed/60
		let m=$Elapsed%60
		let Elapsed=$Elapsed/60
		let h=$Elapsed%24
		let Elapsed=$Elapsed/24
		let d=$Elapsed
		echo $d days, $h:$m:$s
	}

	function MONITOR() {	
		local TIME_STARTED="$(date +%Y-%m-%d-%H:%M:%S.%N)"
		local STARTED="$(date +%s)"
		
		ECHO ""
		local QUERY_INTERVAL=11
		local NEXT_QUERY=$QUERY_INTERVAL
		local P_LEFT=""
		while true ; do
			local elapsed="$(PRINT_ELAPSED "$STARTED")"
			printf "\rElapsed: %s; %sNext Query in: %s" "$elapsed" "${P_LEFT}" "$NEXT_QUERY..."
			if (( NEXT_QUERY < 1 )) ; then
				printf " Querying..."
				local ISDONE
				ISDONE="$(smartctl -a "$DEV" | egrep 'Self_test_in_progress.*[%] left\]')"
				NEXT_QUERY=$QUERY_INTERVAL
				if [[ "$ISDONE" == "" ]] ; then
					ECHO ""
					ECHO "## smart check is no longer in_progress"
					break
				fi
				P_LEFT="$(echo "$ISDONE" | sed 's/.*\[\([0-9][0-9][%] left\)\].*/\1/g'); "
			else
				printf "            "
				let NEXT_QUERY=NEXT_QUERY-1
			fi
			sleep 1
		done
		ECHO ""
		ECHO "## smartctl finished"
	}

	function RUN_TEST() {
		LOG "## $DEV: Running test: $*"
		smartctl "$@"
		local PID=$!
		LOG "## $DEV: smartctl PID: $PID"
		LOG "## $DEV: time started: $TIME_STARTED"
		MONITOR
	}

	CHECK_SECTORS
	CHECK_CUR_TEST

	echo "## Run Short Test?"
	PromptToContinue ; if (( $? != 0 )) ; then
		LOG "## $DEV: User chose to skip Short Test"
	else
		LOG "## $DEV: Running Short Test: $TIME_STARTED"
		RUN_TEST -t short "$DEV"
	fi
	
	echo "## Run Long Test?"
	PromptToContinue ; if (( $? != 0 )) ; then
		LOG "## $DEV: User chose to skip Short Test"
	else
		LOG "## $DEV: Running Short Test: $TIME_STARTED"
		RUN_TEST -t long "$DEV"
	fi
	
	echo "## Run Conveyance Test?"
	PromptToContinue ; if (( $? != 0 )) ; then
		LOG "## $DEV: User chose to skip Short Test"
	else
		LOG "## $DEV: Running Short Test: $TIME_STARTED"
		RUN_TEST -t conveyance "$DEV"
	fi

	function PrintLogSummary() {	
		echo "## Printing Log Summary..."
		local LINE
		echo "$TOTAL_LOG" | while read LINE ; do
			echo "## LOG: $LINE"
		done
	}

	PrintLogSummary
}

if (( $# != 1 )) ; then
	echo "Usage: %s [device]"
	exit 1
fi
Go "$@"

