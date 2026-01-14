#!/bin/bash
# Title:       examine_channel
# Description: Examine a set channel with time optional, resets to all channels on open.
# Author:      Septumus
# Version:     1.0

PINEAPPLE_EXAMINE_RESET
LOG ""
LOG "Pager has now been set to scan all channels."
LOG ""
LOG "Do you want to examine a certain channel or exit to examine all channels?"
LOG ""
LOG green "Green (A) - SET CHANNEL"
LOG ""
LOG red "Other Buttons - EXIT"
LOG ""
LOG ""

button=$(WAIT_FOR_INPUT)

case ${button} in
     "A")
        channel=$(NUMBER_PICKER "Channel to examine: " 7)
        PROMPT "Cancel time entry to keep your channel selection until you reset it. You can do this by running examine_channel again."
	seconds=$(NUMBER_PICKER "Seconds to monitor: " 7)
        LOG "CHANGING TO CHANNEL $channel..."
        LOG ""
        LOG ""
	PINEAPPLE_EXAMINE_CHANNEL $channel $seconds
	    if [[ -z "$seconds" ]]; then
			LOG "Now watching only channel $channel until reset."
	    else
	        LOG "Now watching only channel $channel for $seconds seconds."
	    fi
        LOG ""
        LOG ""        
        ;;
    *) 
        LOG "User chose to exit."
        LOG ""
		LOG ""
        ;;
esac
