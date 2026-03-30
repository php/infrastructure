Access Control
==============

**This documentation is not yet up to date**

Add a new user
--------------

To add a new user, an admin or a release-manager, you use the related playbooks.


Prerequisites
~~~~~~~~~~~~~

- You need the `.google_authenticator` file somewhere on your local machine
- You have to put the ssh key to `roles/add_ssh_key/templates/ssh_keys/username`.

The playbooks take the required parameters `username` and `path_to_google_auth`:

> [!NOTE]
> The name of the ssh_key file has to be the same as the username.

It creates a linux user and copies the `.google_authenticator` file and the `authorized_keys` to the user's homedir.


Add an admin user
~~~~~~~~~~~~~~~~~

```shell
ansible-playbook addAdminUser.yml --extra-vars "username=rocko path_to_google_auth=absolute/path/to/.google_authenticator"
```

This playbook creates a new user on jumphosts and all services.
User group is `sudo`. It puts the `.google_authenticator` file to the jumphost and the ssh-key to everywhere.


Add a release-manager user
~~~~~~~~~~~~~~~~~~~~~~~~~~

A release manager has only access to the downloads machine.

```shell
ansible-playbook addReleaseManagerUser.yml --extra-vars "username=tacocat path_to_google_auth=absolute/path/to/.google_authenticator"
```

This playbook creates a new user on jumphosts and the downloads service.
User group is `release-manager`. It puts the `.google_authenticator` file to the jumphost and the ssh-key to the downloads service.


Delete a user
~~~~~~~~~~~~~

To delete a user you can run the `deleteUser` playbook.

> [!NOTE]
> You have to add the `username` of the user you want to delete, this is mandatory.

You can also add the name of the host from where you want to delete the user e.g. `jumphost`, `museum`.
If no host is provided it will be deleted from `all` by default.

```shell
ansible-playbook deleteUser.yml --extra-vars "username=USERNAME host=HOSTNAME"
```
