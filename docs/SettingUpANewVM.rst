Setting Up a new VM
===================

This procedure also contains information for upgrading/replacing an existing
service VM.

Droplet Creation
----------------

Navigate to: https://cloud.digitalocean.com/droplets/new?i=fc045a&region=ams3&distroImage=debian-13-x64&distro=debian

Datacenter region: Amsterdam 3
OS: Debian (13 x64)
Droplet: Basic (Shared CPU)
CPU Options: Regular (SSD)
Plan: From table in `<OperationalVMs.rst>`_

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

In ``inventory/php/hosts``, **add** under the right group::

	service{x} ansible_host=service{x}-ams.internal.php.net

If you're replacing a service, you need to remove the old one at a later
stage.

Also update the table in ``OperationalVMs.rst``.

Update DNS
----------

Run first to check if it is all OK::

	ansible-playbook -C --diff updateDns.yml

Then run to apply new DNS rules::

	ansible-playbook --diff updateDns.yml

Wait until they resolves through::

	dig service{x}-ams.internal.php.net @dns1.easydns.com
	dig {property}.internal.php.net @dns1.easydns.com

*Note*: If you're adding a server for the ``dynamic`` group, then it will fail
for the new host as it does not have a DNS entry yet. That's okay, and you
should probably use ``--limit service{originalNr}`` to only update the DNS on
the already existing server.

Configure Machine for Access
----------------------------

This can only be run *once*.

1. Turn off the SSH Jump Host Proxy for the new host, but keep the right key, in ``~/.ssh/config``::

	Host service{x}-ams.internal.php.net
		ProxyCommand None
		User root
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

Update Firewalls Everywhere Else
--------------------------------

Some services need to talk to other services, and for that firewalls have to
be updated at times. Therefore, run::

	ansible-playbook --diff applyFirewall.yml

Getting the Property on the VM
------------------------------

Run (again, you can't run this in test mode, due to playbook file requirements)::

	ansible-playbook --diff initService{type-of-service}.yml --limit service{x}

Install Monitoring Service
--------------------------

Each server needs to have the `OhDear monitoring <Monitoring.rst>`_ set up.
You can install this by running the following playbook::

	ansible-playbook --diff installOhDear.yml --limit service{x}
