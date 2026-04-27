#!/bin/bash
{# setting variables to simplify conditions #}
{% set needs_access_from_cdn = (inventory_hostname in groups['service']) %}
{% set needs_trusted_ip_list = (inventory_hostname in groups['service'] and inventory_hostname != 'service0') %}

# Firewall for {{ inventory_hostname }}

{% if needs_access_from_cdn %}
function safe_download() {
    URL=$1
    DEST=$2

    TEMP_NAME=/tmp/temporary-curl-download`xxd -l16 -ps /dev/urandom`

    curl -s -f $URL > $TEMP_NAME
    if [ $? -eq 0 ]; then
        # - request worked, move to permanent location
        mv $TEMP_NAME $DEST
    fi
}
{% endif %}

{% if needs_trusted_ip_list %}
TEMP_REMOTE_PROXY_LIST_FILENAME=/tmp/temporary-remote-proxy-list`xxd -l16 -ps /dev/urandom`
echo "# This list contains IP addresses for the CDN end points" > $TEMP_REMOTE_PROXY_LIST_FILENAME
{% endif %}

ufw --force reset

# Allow access to services only through the public ip of the jumphosts
{% for jumphost in groups['jumphost'] %}
ufw allow from {{ hostvars[jumphost].ansible_facts['default_ipv4'].address }} to any app SSH
{% endfor %}

# Block port 80 access, as we're TLS only
ufw deny WWW

{% if needs_access_from_cdn %}
# Allow access to port 443 from Myra hosts
{%   if needs_trusted_ip_list %}
{%   endif %}
{%   for host in myra_hosts %}
ufw allow from {{ host }} to any app "WWW Secure"
{%   endfor %}
{%   if needs_trusted_ip_list %}
echo "# Myra Nodes:" >> $TEMP_REMOTE_PROXY_LIST_FILENAME
{%     for host in myra_hosts %}
echo "{{ host }}" >> $TEMP_REMOTE_PROXY_LIST_FILENAME
{%     endfor %}
{%   endif %}

# Allow access to port 443 from Bunny hosts
{%   if needs_trusted_ip_list %}
echo "# Bunny Nodes (IPv4):" >> $TEMP_REMOTE_PROXY_LIST_FILENAME
{%   endif %}
safe_download https://bunnycdn.com/api/system/edgeserverlist /local/systems/bunny-edgeserverlist.json
for ip in `cat /local/systems/bunny-edgeserverlist.json | jq -a '.[]' | sed 's/"//g'`; do
    ufw allow from $ip to any app "WWW Secure"
{%   if needs_trusted_ip_list %}
    echo $ip >> $TEMP_REMOTE_PROXY_LIST_FILENAME
{%   endif %}
done

{%   if needs_trusted_ip_list %}
echo "# Bunny Nodes (IPv6):" >> $TEMP_REMOTE_PROXY_LIST_FILENAME
{%   endif %}
safe_download https://bunnycdn.com/api/system/edgeserverlist/IPv6 /local/systems/bunny-edgeserverlist-ipv6.json
for ip in `cat /local/systems/bunny-edgeserverlist-ipv6.json | jq -a '.[]' | sed 's/"//g'`; do
    ufw allow from $ip to any app "WWW Secure"
{%   if needs_trusted_ip_list %}
    echo $ip >> $TEMP_REMOTE_PROXY_LIST_FILENAME
{%   endif %}
done

# Allow access to port 443 from test hosts
{%   for host in test_hosts %}
ufw allow from {{ host }} to any app "WWW Secure"
{%   endfor %}
{% endif %}

{% if inventory_hostname in groups['static'] %}
# Allow access on 'static' to port 443 from PECL host(s)
{%   for host in pecl_hosts %}
ufw allow from {{ host }} to any app "WWW Secure"
{%   endfor %}
{% endif %}

{% if inventory_hostname in groups['dynamic'] %}
# Allow access TCP port 53 from EasyDNS transfer machine
{%   for host in easy_dns_hosts %}
ufw allow proto tcp from {{ host }} to any app DNS
{%   endfor %}

# Allow access TCP port 443 from servers that need to post to main
{%   for host in access_to_main_hosts %}
ufw allow from {{ host }} to any app "WWW Secure"
{%   endfor %}
{% endif %}

{% if inventory_hostname in groups['dynamic'] %}
# GITHUB hooks access
safe_download https://api.github.com/meta /local/systems/github-hooks.json
for ip in `cat /local/systems/github-hooks.json | jq -a '.hooks[]' | sed 's/"//g'`; do
    ufw allow from $IP to any app "WWW Secure"
done
{% endif %}

{% if inventory_hostname in groups['rsync'] %}
# Allow access to rsync from all services
{%   for service_host in groups['service'] %}
ufw allow proto tcp from {{ hostvars[service_host].ansible_facts[hostvars[service_host].private_interface | default("eth1")].ipv4.address }} to any port 873
{%   endfor %}

# Allow rsync from approved hosts
{%   for host in rsync_hosts %}
ufw allow proto tcp from {{ host }} to any port 873
{%   endfor %}
{% endif %}

# Allow health check to port 8991
ufw allow 8991/tcp

# Block port 443 from everywhere else
ufw deny "WWW Secure"

# Enable UFW and deny incoming requests
ufw default deny
ufw enable

{% if needs_trusted_ip_list %}
# Copy new RemoteIP list to Apache Configuration Directory
mv $TEMP_REMOTE_PROXY_LIST_FILENAME "{{ remote_ip_trusted_proxy_list }}"
# And reload Apache
systemctl reload apache2
{% endif %}
