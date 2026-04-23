Local Development Setup
=======================

This guide walks through setting up a local development environment for the
php.net infrastructure.

Prerequisites
-------------

- A host with 8 Debian 12 machines (2 jumphosts, 1 rsync, 5 services)
    - Expected starting point is a base Debian 12 with SSH server installed.
- An SSH key pair configured on each system's `root` user.

Machine Layout
---------

Create 8 machines with static IPs on the same network. The default
mapping used in this guide:

========== ================ ================
VM Name    Role             IP Address
========== ================ ================
jump-ams-1 jumphost         192.168.42.50
jump-sfo-1 jumphost         192.168.42.51
rsync0-ams rsync            192.168.42.52
service0   museum           192.168.42.53
service2   static sites     192.168.42.55
service3   dynamic sites    192.168.42.56
service4   analytics        192.168.42.57
service5   wiki             192.168.42.58
========== ================ ================

Ensure all VMs have root SSH access enabled before starting. You must be able
to ``ssh root@<ip>`` from your machine to each Debian machine.

Step 1: Install Ansible
-----------------------

You can use [virtualenv](https://virtualenv.pypa.io/en/latest/) or
[direnv](https://direnv.net/) to create a Python environment.

To use ``direnv`` with a Python virtual environment. Create a ``.envrc``
file in the project root (this should not be added to Git):

    layout python /path/to/python3
    export ANSIBLE_CONFIG=local.ansible.cfg

Run ``direnv allow``, then install Ansible::

    pip install ansible

Step 2: Create the Local Inventory
----------------------------------

Create ``inventory/local/`` with the following structure::

    inventory/local/
    ├── group_vars/
    │   ├── all.yml      # Secrets (see Step 3)
    │   ├── service.yml  # Copy from inventory/php/group_vars/service.yml
    │   └── rsync.yml    # Copy from inventory/php/group_vars/rsync.yml
    └── hosts

The ``inventory/local`` directory is ignored by Git so anything you enter
here will not be committed.

**inventory/local/hosts**::

    [all:vars]
    ansible_user=<your-username>

    [jumphost]
    jumphost0 ansible_host=192.168.42.50
    jumphost1 ansible_host=192.168.42.51

    [rsync]
    rsync0 ansible_host=192.168.42.52

    [service:children]
    museum
    wiki
    static
    dynamic
    analytics

    [museum]
    service0 ansible_host=192.168.42.53

    [wiki]
    service5 ansible_host=192.168.42.58

    [static]
    service2 ansible_host=192.168.42.55

    [dynamic]
    service3 ansible_host=192.168.42.56

    [analytics]
    service4 ansible_host=192.168.42.57

**Network interface fix:** Your machines may not use ``eth1``.
In your local copies of ``service.yml`` and ``rsync.yml``, replace all
references to ``eth1`` with what ``ip addr`` shows on your machines.

Step 3: Storage and Configure Secrets
--------------------------

**S3-compatible storage for backups:** The backup/restore roles require an
S3-compatible storage backend. For local development, run
`Garage <https://garagehq.deuxfleurs.fr/>`_ or similar.

Without S3-compatible you will not be full able to provision the bugs, main, and
pecl properties. These properties could be updated in an effort to allow all
tasks to be completed if there is no storage specified.

Create ``inventory/local/group_vars/all.yml`` with values for all secrets used
by the playbooks.::

    # S3-compatible storage (backup/restore)
    DO_access_key: "<your-key-id>"
    DO_secret_key: "<your-secret-key>"
    DO_bucket_url: "http://<storage-host-ip>:<storage-host-port>"
    DO_bucket_name: "<your-bucket>"

    # Restic backup password
    restic_password: "<any-password>"

    # OhDear health check
    ohdear_secret: "CHANGE_ME"

    # bugs.php.net
    bugs_password: "CHANGE_ME"
    bugs_password_salt: "CHANGE_ME"
    bugs_auth_token: "CHANGE_ME"

    # main.php.net
    main_db_password: "CHANGE_ME"
    github_secret: "CHANGE_ME"
    github_client_id: "CHANGE_ME"
    github_client_secret: "CHANGE_ME"
    bugs_magic_cookie: "CHANGE_ME"

    # pecl.php.net
    pecl_password: "CHANGE_ME"

    # wiki.php.net
    wiki_token: "CHANGE_ME"

    # downloads.php.net
    auth_token: "CHANGE_ME"

    # people.php.net
    main_user_token: "CHANGE_ME"

    # analytics.php.net
    matomo_salt: "CHANGE_ME"

    # rsync / phpweb backend
    main_user_notes_token: "CHANGE_ME"
    flickr_api_token: "CHANGE_ME"

For local development, ``CHANGE_ME`` placeholders are fine for most secrets —
the services will start but some features (GitHub OAuth, bug tracker auth,
etc.) won't work without real values.

Step 4: Create the Local Ansible Config
----------------------------------------

Create the ``local.ansible.cfg`` in the project root::

    [defaults]
    gathering = smart
    fact_caching = jsonfile
    fact_caching_connection = .ansible-facts-cache
    inventory = inventory/local
    vault_password_file = ~/.ansible/stf-php-ansible-local.secret

    ; ask_vault_pass = true

    # Comment out the ssh_connection before you run the initialize.yml playbook.
    # This must be added back in afterwards.
    [ssh_connection]
    ssh_common_args = -F etc/ssh_config_local
    control_path = ~/.ssh/cp-socket-%%C

The ``.envrc`` sets ``ANSIBLE_CONFIG=local.ansible.cfg`` so this config is
used instead of the production ``ansible.cfg``.

Step 5: Create Your Admins File
-------------------------------

Edit ``etc/admins.yml`` with your details::

    admins:
      - name: <your-username>
        GA_file: /Users/<you>/.google_authenticator
        pubkeys:
          - ssh-ed25519 AAAA... you@example.com

**SSH key:** If you don't have one, generate with ``ssh-keygen -t ed25519``.

**Google Authenticator file:** Install and generate::

    # Debian
    sudo apt install libpam-google-authenticator
    # macOS + homebrew
    brew install google-authenticator-libpam
    google-authenticator -t -d -f -r 3 -R 30 -w 3

Scan the QR code with your authenticator app (Google Authenticator, Authy,
1Password, etc.) or enter the codes. Save the emergency scratch codes in a
safe location.

Step 6: Create the Local SSH Config
------------------------------------

Create ``etc/ssh_config_local``::

    Host 192.168.42.50 192.168.42.51
        User           <your-username>
        ProxyCommand   none
        ForwardAgent   yes
        ControlMaster  auto
        ControlPersist 5d
        ControlPath    ~/.ssh/cp-socket-%C

    Host 192.168.42.*
        User           <your-username>
        ProxyJump 192.168.42.50

This routes SSH to jump hosts directly and proxies all other connections
through the first jump host.

Also add to your ``~/.ssh/config``::

    Host 192.168.42.50 192.168.42.51
        ForwardAgent yes

Step 7: Run initialize.yml
---------------------------

This is the first playbook. It sets up firewalls, creates your user, installs
Google Authenticator on jump hosts, and disables root login.

**Important:** Comment out the ``[ssh_connection]`` section in
``local.ansible.cfg`` before running this playbook. You need direct root SSH
access for initialization::

    # [ssh_connection]
    # ssh_common_args = -F etc/ssh_config_local
    # control_path = ~/.ssh/cp-socket-%%C

Run::

    ansible-playbook initialize.yml --extra-vars "@etc/admins.yml"

After it completes, **uncomment** the ``[ssh_connection]`` section again.

.. warning::

   Once ``initialize.yml`` runs, UFW is enabled and SSH is only allowed from
   the jump host IPs. If you get locked out, access the VM console in Proxmox
   and run ``ufw disable``.

Step 8: Establish the SSH Tunnel
--------------------------------

Before running any further playbooks, establish a persistent SSH connection
to the jump host. This handles the Google Authenticator prompt once::

    ssh -fNF etc/ssh_config_local <your-username>@192.168.42.50

Enter your verification code when prompted. The connection stays in the
background and subsequent SSH connections reuse it.

To tear down the tunnel::

    ssh -O exit -F etc/ssh_config_local 192.168.42.50

Step 9: Run the Service Playbooks
----------------------------------

With the SSH tunnel established, run the playbooks in order:

1. ``ansible-playbook installCommonSoftware.yml``
2. ``ansible-playbook initServiceRsync.yml``
3. ``ansible-playbook initServiceMuseum.yml``
4. ``ansible-playbook initServiceWiki.yml``
5. ``ansible-playbook initServiceStaticSites.yml``
6. ``ansible-playbook initServiceDynamicSites.yml``
7. ``ansible-playbook initServiceAnalytics.yml``

.. note::

   Run ``initServiceRsync.yml`` early — other services (wiki, etc.) depend on
   rsyncing content from the rsync server.

   The rsync role expects ``/mnt/volume_ams3_01`` to exist (a DigitalOcean
   block volume). For local machines, create it manually::

       ssh -F etc/ssh_config_local <your-username>@192.168.42.52 "sudo mkdir -p /mnt/volume_ams3_01"

   The rsync server clones and mirrors all php.net repositories. Allocate at
   least 60GB of disk for the rsync VM — a fully provisioned rsync server
   uses approximately 46GB.

Step 10: Verify
---------------

Once all playbooks have completed, every service should be running:

========== ========================= =================================
Host       Playbook                  Services
========== ========================= =================================
jumphost0  initialize.yml            SSH + Google Authenticator
jumphost1  initialize.yml            SSH + Google Authenticator
rsync0     initServiceRsync.yml      rsync daemon, git mirrors
service0   initServiceMuseum.yml     nginx + museum.php.net
service2   initServiceStaticSites.yml Apache + www, doc, downloads, gtk, people, qa, shared, talks, windows
service3   initServiceDynamicSites.yml Apache + MariaDB + main, bugs, pecl
service4   initServiceAnalytics.yml  Apache + MariaDB + analytics (Matomo)
service5   initServiceWiki.yml       Apache + wiki.php.net (DokuWiki)
========== ========================= =================================

All playbooks are idempotent — you can safely re-run them at any time.

Known Issues and Fixes
----------------------

**Apt cache corruption:** If ``apt update`` fails with "Splitting up
InRelease into data and signature failed", clear the cache on the affected
VM::

    ssh -F etc/ssh_config_local <your-username>@<ip> "sudo rm -rf /var/lib/apt/lists/* && sudo apt update"

**Missing secrets:** If a playbook fails with ``'variable_name' is undefined``,
add the variable to ``inventory/local/group_vars/all.yml`` with a
``CHANGE_ME`` value and re-run the playbook. The complete list of secrets is
in Step 3 above.

**Exim4 not installed:** The ``smtp_smarthost`` role assumes Exim4 is
pre-installed (production servers include it in the base image). We added an
``apt install exim4`` task to ``roles/smtp_smarthost/tasks/main.yml`` so it
installs automatically on fresh VMs.

**PECL public_html directory:** The ``properties/pecl`` role creates symlinks
into ``public_html/`` before the directory exists (it would normally be
populated by rsync). We added a task to
``roles/properties/pecl/tasks/deploy.yml`` to create the directory first.

**Network interface:** Production servers use ``eth1`` for the private
network. Check your VMs with::

    ssh -F etc/ssh_config_local <your-username>@192.168.42.52 "ip -4 addr show | grep inet"

Update your local ``service.yml`` and ``rsync.yml`` accordingly.

**Rsync volume mount:** The rsync role expects ``/mnt/volume_ams3_01``
(a DigitalOcean block volume). For local VMs, create it before running the
rsync playbook::

    ssh -F etc/ssh_config_local <your-username>@192.168.42.52 "sudo mkdir -p /mnt/volume_ams3_01"

**UFW lockout:** After ``initialize.yml`` runs, SSH to service/rsync hosts is
restricted to jump host IPs only. If you get locked out, use the Proxmox VM
console or SSH from the Proxmox host to run ``ufw disable``.
