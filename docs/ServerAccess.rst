=============
Server Access
=============

Logging into Servers
====================

All access to servers is through Jump hosts. There are two:

- ``jump-ams-1.internal.php.net`` (European Jump Host)
- ``jump-sfo-1.internal.php.net`` (Americas Jump Host)

You need to configure your SSH client to use one of these jump hosts to
connect to any other server that's managed with Ansible.

For this, include the following in your ``~/.ssh/config``::

	Host jump*.internal.php.net
		ProxyJump none
		# IdentityFile /home/derick/.ssh/phpservers-ed25519

	Host *.internal.php.net
		ProxyJump <USERID>@jump-ams-1.internal.php.net
		User <USERID>
		# IdentityFile /home/derick/.ssh/phpservers-ed25519

The jump hosts require 2FA using Google Authenticator (information below).


Creating Google Authenticator Files
===================================

1. Install the `google-authenticator
   <https://github.com/google/google-authenticator-libpam>`_ package on a local
   machine.

   On Debian, install the ``libpam-google-authenticator`` package.

   You can use a docker container to avoid contaminating your real machine,
   but it's probably not necessary.

2. Run the ``google-authenticator`` command.

   You need to select to use time based tokens and rate limiting if asked.
   This will output a QA code that you can use to create a new entry in your
   OTP app (Google Authenticator or Authy work).

Granting Access to Infrastructure
=================================

Release Managers
----------------

Release managers should request access through
https://github.com/php/infrastructure/issues/new?template=request-release-manager-access.yml
to provide information, and have provided a Google Authenticator file by email
to ``systems@php.net``.

Then:

- Make sure you've ran ``./bin/auth-jump0`` and ``./bin/auth-jump1`` to set up
  a control socket to the jump hosts.

- Store the provided SSH key in ``roles/add_ssh_key/templates/ssh_keys`` using
  the provided preferred Unix system user name as file name.

- Run::

  ansible-playbook --diff addReleaseManagerUser.yml \
    --extra-vars "username={preferred system user} path_to_google_auth=absolute/path/to/.google_authenticator"

Mailing List Access
~~~~~~~~~~~~~~~~~~~

Then add the new release manager's email address to the
``release-managers@php.net`` distribution list on ``php-smtp4.php.net``::

    sudo vim /etc/aliases-04release-managers

and add the email addresses to the end of the long line.

Then add the new email address as moderator for ``php-announce@lists.php.net``
list on ``lists.php.net``::

    sudo su - -s/bin/bash nobody

    export USER_TO_ADD=sergey

    echo $USER_TO_ADD@php.net >> /var/spool/mlmmj/php-announce/control/moderators
    /usr/bin/mlmmj-sub -L /var/spool/mlmmj/php-announce -a $USER_TO_ADD@php.net

Removing a User from All Systems
================================

Run::

    ansible-playbook --diff deleteUser.yml --extra-vars "username={preferred system user}"

This also removes the user's home directory.
