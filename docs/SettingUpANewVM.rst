Setting Up a new VM
===================

Droplet Creation
----------------

Datacenter region: Amsterdam 3
OS: Debian (13 x64)
Droplet: Basic (Shared CPU)
CPU Options: Regular (SSD)
Plan: From table able

SSH Keys: Derick (PHP Servers) (but we need a new generic one: https://github.com/php/infrastructure/issues/21)

Networking: Enable IPv6
Quantity: 1
Droplet name: ``service{x}-ams.internal.php.net``

Project: PHP Ansible Infra
Tags: service

Add New Droplet to Inventory
----------------------------

In ``inventory/php.net.zone``, add::

	service{x}-ams.internal IN A {Public IPv4}
	{property}.internal     IN CNAME service{x}-ams.internal.php.net.

In ``inventory/php/hosts``, add under the right group::

	service{x} ansible_host=service{x}-ams.internal.php.net

Update DNS
----------

Run first to check if it is all OK::

	ansible-playbook -C --diff updateDns.yml

Then run to apply new DNS rules::

	ansible-playbook --diff updateDns.yml

Wait until they resolves through::

	dig service{x}-ams.internal.php.net @dns1.easydns.com
	dig {property}.internal.php.net @dns1.easydns.com

Configure Machine for Access
----------------------------

This can only be run *once*.

1. Turn off the SSH Jump Host Proxy for the new host, but keep the right key, in ``~/.ssh/config``::

   Host service{x}-ams.internal.php.net
       ProxyCommand None
	   IdentityFile /home/derick/.ssh/phpservers-ed25519

2. Comment out the ``[ssh_connection]`` section in ``ansible.cfg``

3. Run the intitialiser, filtering for the right property only. First as trial::

	ansible-playbook -C --diff initializeService.yml --limit service{x} --extra-vars "@etc/admins.yml"

   Then for real::
	
	ansible-playbook --diff initializeService.yml --limit service{x} --extra-vars "@etc/admins.yml"

4. Re-enable the  ``[ssh_connection]`` section in ``ansible.cfg``

5. Comment out the SSH Jump Host Proxy disablement for the new host in ``~/.ssh/config``.

6. Install the firewall, but make sure you've connected to both jump hosts by running::

	./bin/auth-jump0
	./bin/auth-jump1

   Then run::

	ansible-playbook --diff applyFirewall.yml --limit service{x} 

   This can not be run in test mode, as it needs to install ``ufw`` in the first step.

Getting the Property on the VM
------------------------------

Run (again, you can't run this in test mode, due to playbook file requirements)::

	ansible-playbook --diff initService{type-of-service}.yml --limit service{x}
