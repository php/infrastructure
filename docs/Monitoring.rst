==========
Monitoring
==========

The php.net properties are monitored through `OhDear <https://ohdear.app>`_.

A public status page is available at https://status.php.net or
https://ohdear.app/status-page/php-infrastructure-status-page

Explanation
-----------

For each property this monitors uptime, SSL certificate Health, and whether
there are broken links or mixed content.

For each *server* there is an additional Application Health Check.
This works by OhDear contacting an HTTP end point on each server, backed
by the `OhDear Healt Check <https://github.com/derickr/ohdear-system-health>`_
tool.

This listens on port 8991, and monitors diskspace usage, memory usage, and 
the 5 minute load average. The configuration is located in the `ohdear-health.yml
<../roles/install_ohdear_check/templates/ohdear-health.yaml>`_ file.

Installation
------------

To install (or update) the OhDear monitor, run the following playbook::

	ansible-playbook --diff installOhDear.yml

This does pull in a compiled binary from
https://derickrethans.nl/files/dump/ohdear-system-health, but this should
be changed to pull in a compiled binary through CI on GitHub.

