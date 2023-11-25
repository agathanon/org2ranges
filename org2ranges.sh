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

asn2ranges() {
	local cache_file="/tmp/.bgp_tools_table_cache"
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
	local cache_file="/tmp/.bgp_tools_asn_cache"
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

    ranges_file="ranges.txt"

    # Delete ranges_file if it already exists
    if [[ -f "$ranges_file" ]]; then
        rm "$ranges_file"
    fi

    while IFS= read -r line; do
        as_number=$(echo "$line" | grep -oP '\bAS\d+\b' | sed 's/^AS//')

        if [[ -n $as_number ]]; then
            asn2ranges "$as_number" >> "$ranges_file"
        fi
    done < "$temp_file"

    grep -v ":" "$ranges_file" > ipv4.txt
    grep ":" "$ranges_file" > ipv6.txt

    echo "[+] Created ranges.txt, ipv4.txt, and ipv6.txt!"

    num_v4=$(wc -l ipv4.txt | awk '{print $1}')
    num_v6=$(wc -l ipv6.txt | awk '{print $1}')
    echo "[+] IPv4 range count: $num_v4"
    echo "[+] IPv6 range count: $num_v6"
    echo "[*] Happy hunting!"

    rm "$temp_file"
else
    echo "[!] No ASNs found."
fi

