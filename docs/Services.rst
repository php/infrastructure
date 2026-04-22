Properties and Services
=======================

Each property (www.php.net, `bugs.php.net`_, `downloads.php.net`_,
`wiki.php.net`_, etc. ) is implemented as an Ansible role located in the
`roles/properties`_ directory.

They are grouped into Services. Each Service runs on a virtual Server at
Digital Ocean.

Beyond the php.net Services, there are also two jump hosts, to provide SSH
access to each server, and an rsync service to distribute code. You cannot SSH
into a server directly. See the `<ServerAccess.rst>`_ document on how to get access to
servers.

Our inventory is at ``inventory/php/hosts``, where you can see on which Digital
Ocean server each Service runs.

Overview
--------

Web site properties are grouped together by type into a Service, with the following
rules in mind:

- Each property that we host, but don't develop, gets its own server, such as
  the `analytics.php.net`_ and `wiki.php.net`_ properties.
- All properties that don't require a database are on the same server.
- All properties that do require a database are on the same server.
- The museum property is on its own server.
- The rsync property is on its own server.

All servers run Apache 2, except for `museum.php.net`, which runs on Nginx
(for now).

Each service is managed by its own dedicated playbook, which first runs
``pre_tasks`` to install software and other common tasks, and then includes a
role for each property associated with that service.

The flow of the roles follows a consistent structure across all services.

The main file is ``tasks/main.yml`` which:

- sets up the property configuration (apache configuration, etc).
- includes ``tasks/deploy.yml``, to create directories, databases, and
  sets up cronjobs
- configures backup and restore tasks when required

Directory Structure
-------------------

For each property, configuration files and scripts are stored in the
``templates`` directory.

Property-specific variables can be found in ``vars/main.yml``.

Handlers for reloading and restarting Apache, MariaDB, Nginx are located in
``handlers/main.yml``.


Backups
-------

Backups are stored per-property in a DigitalOcean bucket. The contents are
backed up with `restic <https://restic.readthedocs.io/en/stable/index.html>`_.

The ``backup_property`` role must have the ``property`` variable that matches
each property name. 

You can then set ``backup_paths`` to define an array containing all the paths
to backup, and the ``backup_dbs`` variable to define all the databases that
needs to be backed up.

The last 7 days, 4 weeks, and 6 months of backups are kept.

Backup tasks run as a cronjob.


Restore
-------

**Restore has not been implemented or tested yet**

The restore process follows a similar structure to backup, providing a
reliable way to recover data. When restoring, content is fetched from the
backup folders on the DigitalOcean Bucket and returned to the appropriate
locations.

The restore tasks are skipped by default, and will only run if you specify
``--extra-vars "restore_data=true"``.


Rsync Service
-------------

All Properties have their code distributed from GitHub, through the rsync
server, to each Server. The rsync server is only 
accessible by each of the service hosts, our old www host, our lists hosts
which is not part of this infrastructure project yet, and a third-party
provider that provide rsync repositories for the wider world.

This service keeps repositories up-to-date by performing a git checkout via a cron job.

The update process is automated to ensure the latest version of the code is always available.

On the Rsync.php.net Server, there are several locations for scripts and data:

- ``/local/systems``: The location of the scripts responsible for updating
  repositories and the rsync daemon config file.
- ``/local/this-box/rsync/mirrors``: The directory where the repositories are
  stored and updated. The rsync server serves content from this directory
- ``/local/this-box/rsync/repositories``: Contains a Git clone of ``web-php``,
  which needs additional work before it can be placed in the ``../mirrors``
  directory, and the ``phd`` repository that is used for building
  documentation.


Content workflow
~~~~~~~~~~~~~~~~

A `cronjob <roles/properties/rsync/templates/update-everything>`_ runs every
10 minutes (except for 23:00-23:59 UTC). It runs two other scripts:

- `update-mirrors <roles/properties/rsync/templates/update-mirrors>`_, which
  is responsible for keeping the Git checkouts of each repository up to date.
- `update-phpweb-backend
  <roles/properties/rsync/templates/update-php-backend`>_, which runs scripts:

  - ``update-backend`` (from the `php/php-main-web` repository) runs to fetch
	additional information that is used for the websites. After this is done,
	the data is synched to the ``/local/this-box/rsync/mirrors`` directory.
  - ``update-user-notes`` (from the ``php/php-main.web`` repository) to fetch
	all manual users notes, and synchs them to the ``mirrors`` directory.

Other Services
--------------

Still need to be documented.

