#!/bin/bash

# Firewall for {{ inventory_hostname }}

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

ufw --force reset

# Allow access to services only through the public ip of the jumphosts
{% for jumphost in groups['jumphost'] %}
ufw allow from {{ hostvars[jumphost].ansible_facts['default_ipv4'].address }} to any app SSH
{% endfor %}

# Block port 80 access, as we're TLS only
ufw deny WWW

{% if inventory_hostname in groups['service'] %}
# Allow access to port 443 from Myra hosts
{% for host in myra_hosts %}
ufw allow from {{ host }} to any app "WWW Secure"
{% endfor %}

# Allow access to port 443 from Bunny hosts
safe_download https://bunnycdn.com/api/system/edgeserverlist /local/systems/bunny-edgeserverlist.json
for ip in `cat /local/systems/bunny-edgeserverlist.json | jq -a '.[]' | sed 's/"//g'`; do
    ufw allow from $ip to any app "WWW Secure"
done

safe_download https://bunnycdn.com/api/system/edgeserverlist/IPv6 /local/systems/bunny-edgeserverlist-ipv6.json
for ip in `cat /local/systems/bunny-edgeserverlist-ipv6.json | jq -a '.[]' | sed 's/"//g'`; do
    ufw allow from $ip to any app "WWW Secure"
done

# Allow access to port 443 from test hosts
{% for host in test_hosts %}
ufw allow from {{ host }} to any app "WWW Secure"
{% endfor %}
{% endif %}

{% if inventory_hostname in groups['static'] %}
# Allow access on 'static' to port 443 from PECL host(s)
{% for host in pecl_hosts %}
ufw allow from {{ host }} to any app "WWW Secure"
{% endfor %}
{% endif %}

{% if inventory_hostname in groups['dynamic'] %}
# Allow access TCP port 53 from EasyDNS transfer machine
{% for host in easy_dns_hosts %}
ufw allow proto tcp from {{ host }} to any app DNS
{% endfor %}

# Allow access TCP port 443 from servers that need to post to main
{% for host in access_to_main_hosts %}
ufw allow from {{ host }} to any app "WWW Secure"
{% endfor %}
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
{% for service_host in groups['service'] %}
ufw allow proto tcp from {{ hostvars[service_host].ansible_facts['eth1'].ipv4.address }} to any port 873
{% endfor %}

# Allow rsync from approved hosts
{% for host in rsync_hosts %}
ufw allow proto tcp from {{ host }} to any port 873
{% endfor %}
{% endif %}

# Allow health check to port 8991
ufw allow 8991/tcp

# Block port 443 from everywhere else
ufw deny "WWW Secure"

# Enable UFW and deny incoming requests
ufw default deny
ufw enable
