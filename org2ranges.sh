#!/bin/bash

# org2ranges.sh
#
# written by agatha with bgp.tools scripts provided by acidvegas
#
# usage: ./org2ranges.sh <search query>
# searches bgp.tools for organizations ip ranges and creates three files:
#   - ranges.txt: contains all ip ranges belonging to the asns
#   - ipv4.txt: all ipv4 ranges for zmap or other ipv4-only tools
#   - ipv6.txt: all ipv6 ranges that can be scanned separately if needed
#
# as the organization search is loose, you will be asked to edit the input
# list before asn2ranges is called.

# Configuration
CACHE_DIR="/tmp/.bgp_tools"
CACHE_UPDATE_INTERVAL=$((24 * 60 * 60)) # 24 hours in seconds
RANGES_FILE="ranges.txt"
IPV4_FILE="ipv4.txt"
IPV6_FILE="ipv6.txt"

print_banner() {
    cat << "EOF"
                  ___
                 |__ \
   ___  _ __ __ _   ) |_ __ __ _ _ __   __ _  ___  ___
  / _ \| '__/ _` | / /| '__/ _` | '_ \ / _` |/ _ \/ __|
 | (_) | | | (_| |/ /_| | | (_| | | | | (_| |  __/\__ \
  \___/|_|  \__, |____|_|  \__,_|_| |_|\__, |\___||___/
             __/ |                      __/ |
            |___/                      |___/

                           writen by agathanonymous

EOF
}

asn2ranges() {
	local cache_file="$CACHE_DIR/.bgp_tools_table_cache"
	local current_time=$(date +%s)
	local update_interval=$((24 * 60 * 60)) # 2 hours in seconds
	if [ -f "$cache_file" ]; then
		local last_update=$(date -r "$cache_file" +%s)
		local time_diff=$(($current_time - $last_update))
		if [ $time_diff -gt $update_interval ]; then
			curl -A 'bgp.tools cli - originally by acidvegas' -s https://bgp.tools/table.txt -o "$cache_file"
		fi
	else
		curl -A 'bgp.tools cli - originally by acidvegas' -s https://bgp.tools/table.txt -o "$cache_file"
	fi
	awk -v asn="$1" '$NF == asn {print $1}' "$cache_file"
}

asn2search() {
	local search_string="$1"
	local cache_file="$CACHE_DIR/.bgp_tools_asn_cache"
	local current_time=$(date +%s)
	local update_interval=$((24 * 60 * 60)) # 24 hours in seconds
	if [ -f "$cache_file" ]; then
		local last_update=$(date -r "$cache_file" +%s)
		local time_diff=$(($current_time - $last_update))
		if [ $time_diff -gt $update_interval ]; then
			curl -v -A 'bgp.tools cli - originally by acidvegas' -s https://bgp.tools/asns.csv -o "$cache_file"
		fi
	else
		curl -A 'bgp.tools cli - originally by acidvegas' -s https://bgp.tools/asns.csv -o "$cache_file"
	fi
	grep -i "$search_string" "$cache_file"
}

# org2ranges main
print_banner

if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR"
fi

if [[ -z "$1" ]]; then
    echo "[!] No organization provided."
    exit 1
fi

search_string="$*"

echo "[*] Searching for \"$search_string\"..."
as_list=$(asn2search "$search_string")

if [[ -n "$as_list" ]]; then
    echo "[+] ASNs found for \"$search_string\". Validate the list before continuing."
    read -rp "[*] Press Enter to continue."

    temp_file=$(mktemp)
    printf "%s\n" "$as_list" > "$temp_file"

    "${EDITOR:-vim}" "$temp_file"

    if ! [[ -s "$temp_file" ]]; then
        echo "[!] Could not find temp_file."
        exit 1
    fi

    num_asns=$(wc -l "$temp_file" | awk '{print $1}')
    echo "[*] Gathering IP ranges for $num_asns ASNs..."

    # Delete RANGES_FILE if it already exists
    if [[ -f "$RANGES_FILE" ]]; then
        rm "$RANGES_FILE"
    fi

    while IFS= read -r line; do
        as_number=$(echo "$line" | grep -oP '\bAS\d+\b' | sed 's/^AS//')

        if [[ -n $as_number ]]; then
            asn2ranges "$as_number" >> "$RANGES_FILE"
        fi
    done < "$temp_file"

    grep -v ":" "$RANGES_FILE" > "$IPV4_FILE"
    grep ":" "$RANGES_FILE" > "$IPV6_FILE"

    echo "[+] Created ranges.txt, ipv4.txt, and ipv6.txt!"

    num_v4=$(wc -l "$IPV4_FILE" | awk '{print $1}')
    num_v6=$(wc -l "$IPV6_FILE" | awk '{print $1}')
    echo "[+] IPv4 range count: $num_v4"
    echo "[+] IPv6 range count: $num_v6"
    echo "[*] Happy hunting!"

    rm "$temp_file"
else
    echo "[!] No ASNs found."
fi

