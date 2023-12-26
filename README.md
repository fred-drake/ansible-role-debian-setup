Ansible Role: Debian Setup
=========

This proceses all tasks that are common to every system that is in the Debian family of distrubutions.

Requirements
------------

The following collections are required:
  - ansible.posix
  - community.general

This role also requires root access.

Role Variables
--------------

`ansible_user` defines the user that is to be used on the machine.
```yaml
ansible_user: ubuntu
```
---
`authorized_keys_url` defines the URL that stores all public keys that will be allowed for passwordless login.  Setting to a blank value will skip this process.
```yaml
authorized_keys_url: 'https://github.com/fred-drake.keys'
```
---
`allow_passwordless_sudo` defines if the user will be set up to become root without having to enter their password.
```yaml
allow_passwordless_sudo: true
```
---
`host` sets the hostname for the machine.  If not set or empty, the
hostname will not be set.
```yaml
host: "{{ inventory_hostname }}"
```
---
`timezone` sets the timezone for the machine, as defined by [the list of timezones from the tz database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).  If not set or empty, the hostname will not be set.
```yaml
timezone: America/New_York
```
---
`host_specific_apt_sources` contains the literal content that would be added as custom sources for `apt`.  If not set or empty, no sources will be added.
```yaml
host_specific_apt_sources: ""
```
---
`host_specific_mounts` is a list of objects containing information for any mounts you wish to add.  Each object has the following properties:
 - `src`: The source for the mount
 - `path`: The path for the mount
 - `fstype`: The filesystem type for the mount

 These follow the same fields found in [the posix mount module](https://docs.ansible.com/ansible/latest/collections/ansible/posix/mount_module.html).
 ```yaml
 host_specific_mounts: []
 ```
 ---
 `host_specific_firewall_ports` is a list of objects containing information for any firewall ports you wish to manipulate.  Each object has the following properties:
 - `port`: The port to open
 - `permanent`: Whether the port should be opened permanently
 - `zone`: The zone to open the port in

 These follow the same fields found in [the posix firewalld module](https://docs.ansible.com/ansible/latest/collections/ansible/posix/firewalld_module.html).
 ```yaml
 host_specific_firewall_ports: []
 ```

Dependencies
------------

There are no role dependencies.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

```yaml
- hosts: servers
  roles:
      - fred_drake.debian_setup
```
License
-------

MIT

