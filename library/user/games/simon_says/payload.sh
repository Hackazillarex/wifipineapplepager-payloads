#!/bin/bash
# Title: Simon Says
# Description: Memory game with lights and sounds!
# Author: RocketGod - https://betaskynet.com
# Crew: The Pirates' Plunder - https://discord.gg/thepirates

INPUT=/dev/input/event0
LOOT_DIR="/root/loot/simon_says"
HIGH_SCORE_FILE="$LOOT_DIR/high_score"

declare -a PATTERN
SCORE=0
HIGH_SCORE=0

# === LED CONTROL ===

led_pattern() {
    local json="$1"
    . /lib/hak5/commands.sh
    HAK5_API_POST "system/led" "$json" >/dev/null 2>&1
}

# All LEDs off
led_off() {
    led_pattern '{"color":"custom","raw_pattern":[{"onms":100,"offms":0,"next":false,"rgb":{"1":[false,false,false],"2":[false,false,false],"3":[false,false,false],"4":[false,false,false]}}]}'
}

# Individual direction lights (button positions: 1=left, 2=up, 3=right, 4=down)
led_up() {
    led_pattern '{"color":"custom","raw_pattern":[{"onms":5000,"offms":0,"next":false,"rgb":{"1":[false,false,false],"2":[true,false,false],"3":[false,false,false],"4":[false,false,false]}}]}'
}

led_down() {
    led_pattern '{"color":"custom","raw_pattern":[{"onms":5000,"offms":0,"next":false,"rgb":{"1":[false,false,false],"2":[false,false,false],"3":[false,false,false],"4":[false,false,true]}}]}'
}

led_left() {
    led_pattern '{"color":"custom","raw_pattern":[{"onms":5000,"offms":0,"next":false,"rgb":{"1":[false,true,false],"2":[false,false,false],"3":[false,false,false],"4":[false,false,false]}}]}'
}

led_right() {
    led_pattern '{"color":"custom","raw_pattern":[{"onms":5000,"offms":0,"next":false,"rgb":{"1":[false,false,false],"2":[false,false,false],"3":[true,true,false],"4":[false,false,false]}}]}'
}

# All red for game over
led_all_red() {
    led_pattern '{"color":"custom","raw_pattern":[{"onms":5000,"offms":0,"next":false,"rgb":{"1":[true,false,false],"2":[true,false,false],"3":[true,false,false],"4":[true,false,false]}}]}'
}

# All white for win
led_all_white() {
    led_pattern '{"color":"custom","raw_pattern":[{"onms":5000,"offms":0,"next":false,"rgb":{"1":[true,true,true],"2":[true,true,true],"3":[true,true,true],"4":[true,true,true]}}]}'
}

# === SOUNDS (RTTTL format) ===

play_up()    { RINGTONE "U:d=16,o=6,b=200:c" & }
play_down()  { RINGTONE "D:d=16,o=5,b=200:g" & }
play_left()  { RINGTONE "L:d=16,o=5,b=200:e" & }
play_right() { RINGTONE "R:d=16,o=6,b=200:e" & }
play_wrong() { RINGTONE "error" & }
play_win()   { RINGTONE "bonus" & }
play_start() { RINGTONE "getkey" & }
play_levelup() { RINGTONE "xp" & }

# === INPUT ===

flush_input() {
    dd if=$INPUT of=/dev/null bs=16 count=100 iflag=nonblock 2>/dev/null
}

read_button() {
    while true; do
        local data=$(dd if=$INPUT bs=16 count=1 2>/dev/null | hexdump -e '16/1 "%02x "')
        [ -z "$data" ] && continue
        
        local type=$(echo "$data" | cut -d' ' -f9-10)
        local value=$(echo "$data" | cut -d' ' -f13)
        
        if [ "$type" = "01 00" ] && [ "$value" = "01" ]; then
            local keycode=$(echo "$data" | cut -d' ' -f11-12)
            case "$keycode" in
                "67 00") echo "UP"; return ;;
                "6c 00") echo "DOWN"; return ;;
                "69 00") echo "LEFT"; return ;;
                "6a 00") echo "RIGHT"; return ;;
                "31 01"|"30 01") echo "CENTER"; return ;;
            esac
        fi
    done
}

# === GAME FUNCTIONS ===

flash_direction() {
    local dir=$1
    local ms=${2:-350}
    
    case "$dir" in
        UP)    led_up;    play_up ;;
        DOWN)  led_down;  play_down ;;
        LEFT)  led_left;  play_left ;;
        RIGHT) led_right; play_right ;;
    esac
    
    sleep $(echo "scale=3; $ms / 1000" | bc)
    led_off
    sleep 0.1
}

add_to_pattern() {
    local dirs=("UP" "DOWN" "LEFT" "RIGHT")
    PATTERN+=("${dirs[$((RANDOM % 4))]}")
}

show_pattern() {
    sleep 0.6
    
    # Speed increases with score
    local speed=400
    [ $SCORE -gt 4 ] && speed=320
    [ $SCORE -gt 8 ] && speed=260
    [ $SCORE -gt 12 ] && speed=200
    [ $SCORE -gt 16 ] && speed=150
    
    for dir in "${PATTERN[@]}"; do
        flash_direction "$dir" $speed
    done
}

get_player_input() {
    for expected in "${PATTERN[@]}"; do
        flush_input
        local btn=$(read_button)
        
        [ "$btn" = "CENTER" ] && return 2
        
        # Light + sound for player's press
        case "$btn" in
            UP)    led_up;    play_up ;;
            DOWN)  led_down;  play_down ;;
            LEFT)  led_left;  play_left ;;
            RIGHT) led_right; play_right ;;
        esac
        sleep 0.15
        led_off
        
        [ "$btn" != "$expected" ] && return 1
    done
    return 0
}

startup_spin() {
    local d=0.08
    led_up; sleep $d
    led_right; sleep $d
    led_down; sleep $d
    led_left; sleep $d
    led_up; sleep $d
    led_right; sleep $d
    led_down; sleep $d
    led_left; sleep $d
    led_off
}

game_over_flash() {
    play_wrong
    sleep 0.1
    for i in 1 2 3; do
        led_all_red
        sleep 0.12
        led_off
        sleep 0.08
    done
}

# === MAIN ===

mkdir -p "$LOOT_DIR"
[ -f "$HIGH_SCORE_FILE" ] && HIGH_SCORE=$(cat "$HIGH_SCORE_FILE" 2>/dev/null)
[[ ! "$HIGH_SCORE" =~ ^[0-9]+$ ]] && HIGH_SCORE=0

PATTERN=()
SCORE=0

play_start
startup_spin
sleep 0.3

while true; do
    add_to_pattern
    SCORE=${#PATTERN[@]}
    
    # Level up sound at milestones
    case $SCORE in
        5|10|15|20) play_levelup; sleep 0.3 ;;
    esac
    
    show_pattern
    flush_input
    
    get_player_input
    result=$?
    
    if [ $result -eq 2 ]; then
        # Quit
        led_off
        SCORE=$((SCORE - 1))
        [ $SCORE -gt $HIGH_SCORE ] && echo "$SCORE" > "$HIGH_SCORE_FILE"
        ALERT "Score: $SCORE"
        exit 0
        
    elif [ $result -eq 1 ]; then
        # Wrong!
        game_over_flash
        SCORE=$((SCORE - 1))
        
        if [ $SCORE -gt $HIGH_SCORE ]; then
            echo "$SCORE" > "$HIGH_SCORE_FILE"
            HIGH_SCORE=$SCORE
            ALERT "NEW HIGH SCORE: $SCORE!"
        else
            ALERT "Score: $SCORE (Best: $HIGH_SCORE)"
        fi
        
        # Wait for replay or exit
        sleep 0.5
        flush_input
        btn=$(read_button)
        [ "$btn" = "CENTER" ] && { led_off; exit 0; }
        
        # Reset for new game
        PATTERN=()
        play_start
        startup_spin
        
    else
        # Correct! Quick flash and continue
        play_win
        led_all_white
        sleep 0.15
        led_off
        sleep 0.2
    fi
done