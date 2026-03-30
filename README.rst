PHP Infrastructure
==================

This repository contains the Ansible playbooks and associated scripts that
describes the infrastructure of php.net and its associated properties.

There are many of them, and they are described in ``docs/Services.rst``.

The documentation is very much not complete, but work is on the way to improve
on this.

General Network Setup
---------------------

Our services are behind a CDN, with the firewall configured so that you can
not access the HTTP and HTTPS ports of each service directly. You must go
through the CDN.

Server access is restricted through Jump Hosts.

Each property has two DNS entries. The one you would access in a browser, such
as ``www.php.net``, and one with the ``.internal.php.net`` suffix. The latter
can be used for SSH only, as the former is CNAME'd to the CDN.

Some machines in the set up can talk directly to other servers in the
environment. For example, they can all connect to the rsync server to obtain
updates, and other services can connect to ``main.internal.php.net`` APIs.

The firewall(s) on each server also enforce that as few machines can make
connections is required.

The ``applyDNS.yml`` playbook is used to update firewall rules.

Running Ansible
---------------

As you can not directly SSH into a server, that also means that the Ansible
playbooks can not be run before you have established an SSH tunnel to one of
the jump hosts.

The scripts in `bin/`_ use the configuration in the `etc/`_ directory to set up
these tunnels. You will obviously need to have an account on both the jump
hosts and each server.

The ``addAdminUser.yml`` and ``addReleaseManager.yml`` playbooks exist to do
that.

Ansible Vault
~~~~~~~~~~~~~

We use an Ansible vault to store our secret credentials. You will also need
access to that before you can run any of the playbooks.

DNS
---

The DNS configuration is in `inventory/php.net.zone`_. It can be applied to our
third-party DNS provider through the `updateDns.yml`_ playbook.
