#!/bin/bash
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

CONFIG_PATH="./config"
SKINNER_CONFIG_FILE="$CONFIG_PATH/skinnerconfig.json"

mkdir -p "$CONFIG_PATH"
if [ ! -f "$SKINNER_CONFIG_FILE" ]; then
    echo "{}" > "$SKINNER_CONFIG_FILE"
fi

url_decode() {
    local encoded="$1"
    printf '%b' "${encoded//%/\\x}" | sed 's/+/ /g'
}

check_authentication() {
    local token="$1"
    local serverid="$2"
    local cookie_name="AUTH_$serverid"
    local cookie_value="$token"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" -b "$cookie_name=$cookie_value" http://localhost:1471/api/api_ping)

    if [ "$status" -eq 200 ]; then
        return 0
    else
        echo '{"status":"unauthorized"}'
        exit 0
    fi
}

get_system_info() {

    local disk_info
    disk_info=$(df -h | grep '^/dev/' | awk '{printf "%s %s %s %s, ", $1, $2, $3, $4}' | sed 's/, $//')
    
    local mem_info
    mem_info=$(free -h | grep "Mem:" | awk '{print "Total: "$2", Used: "$3", Free: "$4}')
    
    local cpu_load
    cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^ //')

    echo "{"
    echo "  \"status\": \"ok\","
    echo "  \"data\": {"
    echo "    \"disk\": \"$disk_info\","
    echo "    \"memory\": \"$mem_info\","
    echo "    \"cpu_load\": \"$cpu_load\""
    echo "  }"
    echo "}"
}

run_command() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        echo '{"status":"no_command"}'
        return
    fi
    local output
    output=$(eval "$cmd" 2>&1)
    echo "{\"status\":\"done\",\"output\":\"$(echo "$output" | sed 's/"/\\"/g' | tr -d '\n')\"}"
}

list_config() {
    if [ ! -s "$SKINNER_CONFIG_FILE" ]; then
        echo '{"status":"empty_config","config":{}}'
    else
        echo -n "{\"status\":\"ok\",\"config\":"
        cat "$SKINNER_CONFIG_FILE"
        echo -n "}"
    fi
}

set_config() {
    local body
    body=$(cat)
    if [ -z "$body" ]; then
        echo '{"status":"empty_body"}'
        return
    fi
    echo "$body" > "$SKINNER_CONFIG_FILE"
    echo '{"status":"ok","message":"config_updated"}'
}

for param in $(echo "$QUERY_STRING" | tr '&' ' '); do
    key=$(echo "$param" | cut -d= -f1)
    value=$(echo "$param" | cut -d= -f2-)
    value=$(url_decode "$value")
    case "$key" in
        token) TOKEN="$value" ;;
        serverid) SERVERID="$value" ;;
        action) ACTION="$value" ;;
        data) DATA="$value" ;;
    esac
done

AUTH_ACTIONS=("command" "setconfig" "systeminfo")
UNAUTH_ACTIONS=("listconfig")

if [[ " ${AUTH_ACTIONS[*]} " =~ " $ACTION " ]]; then
    if [ -z "$TOKEN" ] || [ -z "$SERVERID" ]; then
        echo '{"status":"missing_auth"}'
        exit 0
    fi
    check_authentication "$TOKEN" "$SERVERID"
fi

case "$ACTION" in
    command)
        run_command "$DATA"
        ;;
    listconfig)
        list_config
        ;;
    setconfig)
        set_config
        ;;
    systeminfo)
        get_system_info
        ;;
    *)
        echo '{"status":"unknown_action"}'
        ;;
esac