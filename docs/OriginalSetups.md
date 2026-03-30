# Ansible for PHP with STA project

**This is the original README as part of the STA project. It is not yet been
updated for the current state of this project, and should only be used as a
reasonable reference. This document is going to go away.**

## Proposal

We created this project as a shadow infra for [Ansible](https://docs.ansible.com/ansible/latest/index.html) to automate server infrastructure setup.

Ansible is a configuration management tool that facilitates the task of setting up and maintaining remote servers.
Ansible doesn’t require any special software to be installed on the nodes that will be managed with this tool.
Ansible organizes system administration operations into a hierarchy of playbooks containing roles containing tasks.
A control machine is set up with the Ansible software, which then communicates with the nodes via standard SSH.

[Here are some tips for making the most of Ansible and Ansible playbooks.](https://docs.ansible.com/ansible/2.8/user_guide/playbooks_best_practices.html#best-practices)


## General information

System setup is done in two phases. Phase 1 uses ssh connections backed by SSH keys for the `root` user on each machine. In our case these are provisioned by DigitalOcean on droplet creation. In this phase, admin accounts with their own SSH keys as well as Google Authenticator are set up. In Phase 2, the accounts and 2FA set up in Phase 1 are used to connect to all machines.


## Prerequisite

- Ansible configuration: Before running the initialization script, comment out the `ssh_connection` setting in the ansible.cfg file. This ensures the initialization process is performed using the root user.
- Update jumphost domains: Modify domains in `/bin/auth-jump0-1` and `/etc/ssh_config_jump0-1`.
- Create a vault password: Before starting, you must create a vault password. This password can be anything you choose. Refer to the [Ansible Vault Guide](https://docs.ansible.com/ansible/2.8/user_guide/vault.html). Run the following to change the password. You’ll be prompted to enter the old password and the new password. To get the password prompt, set `ask_vault_pass = true` in `ansible.cfg`. The password for the placeholder secrets in this repo will be shared separately. These are not used in any production systems anywhere.

```sh
ansible-vault rekey inventory/php/group_vars/all.yml
```

- Once the new password is created, add it to the password secret file: `~/.ansible/stf-php-ansible.secret`.
  - If you don't want to add the password as plain text in the file system you can edit `ansible.cfg`.
  - There's also the option to read the secret from a password manager. Let us know if you are interested in that.
- Update Domain Names: Edit the domain names of the services in `inventory/php/group_vars/service.yml`.
- Update the encrypted variables in the vault. You can do so by running `ansible-vault edit inventory/php/group_vars/all.yml`


## Initialize machines

> [!NOTE]
> This won't work when the `ssh_connection` config in `ansible.cfg` is not commented out.
>


### Host key checking

When connecting to a remote server via SSH for the first time, you need to confirm the host key check by typing 'yes'.
So before you run ansible the very first time, you should do this for all machines. In our case it is:

```sh
ssh root@rsync0.ams3.do.php.backend.lol
ssh root@jumphost0.ams3.do.php.backend.lol
ssh root@jumphost1.nyc1.do.php.backend.lol
ssh root@service0.ams3.do.php.backend.lol
ssh root@service1.ams3.do.php.backend.lol
ssh root@service2.ams3.do.php.backend.lol
ssh root@service3.ams3.do.php.backend.lol
```

Alternatively, you can disable manual host key checks by setting `host_key_checking = False` in your [Ansible configuration file](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#host-key-checking), but be aware that this reduces security and should be done with caution.


### Start initializing

To initialize your machines, you need a `yml` file with all admins you want to add.
An admin user has do have a `name`, `GA_file` which is the absolute path to it's `.google_authenticator` file and the public keys are defined at `pubkeys`.

The format looks like this, but there is also an example at `etc/admins.yml`:

```yml
admins:
  - name: rocko
    GA_file: /home/rocko/.google_authenticator
    pubkeys:
      - ssh-rsa abcxyz rocko.artischocko@mail.com
      - ssh-ed25519 abcxyz artischocko@rocko.ie
```

You can add several public keys, but you don't have to.
Once you have set this up, you can run the playbook to initialize _all_ machines.
This means: jumphosts, rsync and the services where the properties live on.

```sh
ansible-playbook initialize.yml --extra-vars "@/path/to/admins.yml"
```

It does the following:
  1. Define all admin users (name, pubkey, Google Authenticator file)
  2. Disable root login
  3. Google Auth set up
  4. Set up firewall rules to only log in via jump host IPs

You can add more or delete admins later as well. All user management tasks are outlined in [Users.md](Users.md).


## Using Ansible

Now the fun begins! 🥳

> [!NOTE]
> Uncomment and re-enable the `ssh_connection` setting in the `ansible.cfg` file. After initialization, root SSH access is disabled on all machines. Since Ansible runs its tasks as a local user, you need to configure the `ssh_connection` setting to ensure proper functionality.

All tasks that are set up in this repository are organised by what Ansible calls a `playbook`.

To run any playbook, we first have to establish an SSH connection to one of the jumphosts:

```shell
bin/auth-jump0
```

This creates an SSH control channel to `jumphost0` that will remain valid for 4 hours. Re-run this when connections start failing after 4 hours. The 4 hour timeout can be adjusted in `etc/ssh_config_jump0` and `etc/ssh_config_jump1` respectively.

There is a corresponding `bin/auth-jump1`.

Then you can run any playbook like this:

```shell
ansible-playbook playbook.yml
```

If you have more than one inventory (say one to try things out with and a live one), you can overwrite the default inventory of `inventory/php` (set in `ansible.cfg`) like so: `ansible-playbook -i inventory/other ...`


## Set up services

> [!IMPORTANT]
> Before you run this, you should modify the domain names at `inventory/php/group_vars/service.yml`
>

If you want to read more about the services, please do so at our [Services readme](Services.md).

To set them up, as its used by the other services, first run:

- rsync: `ansible-playbook initRsync.yml`

> [!IMPORTANT]
> When the above service playbooks are ran for the first time, make sure to add `--extra-vars "first_run=true"` so that the restore tasks are skipped. Details are [here](Services.md#restore-backup).
>

And then run:

- downloads: `ansible-playbook initServiceDownloads.yml`
- museum:    `ansible-playbook initServiceMuseum.yml`
- main:      `ansible-playbook initServiceMain.yml`
- wiki:      `ansible-playbook initServiceWiki.yml`

Now you are ready to go! :tada:

## How to validate things

You can run your playbooks with verbose flags, `-v` or `--verbose`, to see more details about the error and the commands run by Ansible.

Adding multiple `-v` will increase the verbosity, the builtin plugins currently evaluate up to `-vvvvvv`.
A reasonable level to start is `-vvv`, connection debugging might require `-vvvv`.
For example `ansible-playbook examplePlaybook.yml -vvv`.

The debug module can also be used to display variables or messages at specific points in the playbook. For example:
```yml
- name: Debug message
  debug:
    msg: "The value of the variable is {{ variable }}"
```

Documentation on other Ansible debugging modules can be found [here](https://docs.ansible.com/ansible/latest/dev_guide/debugging.html).


## Access control

Access control to the jumphost and service machines is configured using the `initialize.yml` playbook. Each user's SSH keys are added to the machines, along with their respective Google Authenticator files, ensuring secure access management.

Once the machines are initialized, user management tasks are also handled via Ansible, including:

- Adding an admin user
- Adding a release manager user
- Deleting a specified user

Details of the user management tasks are outlined in [Users.md](Users.md).


# Additional tasks


## Using encrypted vars

Ansible Vault encrypts variables and files so you can protect sensitive content such as passwords or keys rather than leaving it visible as plaintext in playbooks or roles.
The encrypted passwords for _all_ hosts are at [inventory/php/group_vars/all.yml](inventory/php/group_vars/all.yml).

To edit the all.yml file do:

```shell
ansible-vault edit inventory/php/group_vars/all.yml
```

You will be prompted for your vault password and your configured `EDITOR` will be opened.

Further details on encryption can be found in [ansible documentation](https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html).


## Changing the Jumphost

By default, jumphost0 is used, to change this, you have to copy your `ansible.cfg` to `local.ansible.cfg` (which is `.gitignored`) and set the shell environment variable `ANSIBLE_CONFIG` to `local.ansible.cfg`. Then you change this line in `local.ansible.cfg`:

```diff
-ssh_common_args = -F etc/ssh_config_jump0
+ssh_common_args = -F etc/ssh_config_jump1
```

And then you initialize the authentication with `bin/auth-jump1` like before.


## Scripts

The [PHP Systems](https://github.com/php/systems) repository hosts a number of scripts to maintain the services. Some of these scripts have been added to the service playbooks. A full list of the scripts and their usage are outlined in the [SystemScripts.md](SystemScripts.md). This can act as a reference for future additions to the Ansible playbooks.


## Myra Integration and Port Configuration

As part of the Myra setup, we are transitioning to using only port 443 with self-signed certificates for services.
This involves blocking access to port 80 and restricting access to port 443 only from Myra hosts.

For the `museum` and `shared`, which are specifically integrated with Myra, this configuration has already been prepared.
The variable `myra_hosts` is added to the `service.yml` file, where you can define the Myra host(s).
In the dedicated roles for these services, you will find commented-out tasks which manage firewall settings.


## Next steps

There are some outstanding tasks that can be done to further improve the project.

* Configure Docker for the `wiki` in Ansible, ensuring the vendor directory is excluded during `rsync`. This needs to be done for the `wiki` service to properly.
* Implement automatic renewal for self-signed SSL certificates.
* Improve user creation by combining SSH key setup and GA file configuration.
* Streamline the restore property functionality to support multiple directories, so that it can be used by `wiki` (refer to the certbot role as example).
