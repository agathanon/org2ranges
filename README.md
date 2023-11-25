# org2ranges
Collect IP ranges with a [bgp.tools](https://bgp.tools) search query.

Searches [bgp.tools](https://bgp.tools) for organizations IP ranges and creates three files:
- `ranges.txt`: Contains all IP ranges belonging to the ASNs.
- `ipv4.txt`: All IPv4 ranges for `zmap` or other IPv4-only tools.
- `ipv6.txt`: All IPv6 ranges that can be scanned separately if needed.

As the organization search is loose, you will be asked to edit the input list before `asn2ranges` is called.

## Shoutouts
- Greetz to acidvegas for `asn2ranges` and `asn2search` bash functions.

## Troubleshooting
You may have to edit the User-Agent if you have trouble getting the lists from [bgp.tools](https://bgp.tools).