### Metal iperf appliance cloud-init file ####

This cloud-init userdata file will turn a [Equinix Metal](http://metal.equinix.com/) instance provisioned with `Alma 8` into a psuedo [iperf3](https://iperf.fr/) appliance.

The instructions in the cloud-init file will:

* Update all packages including system packages and reboot once initially if neeeded
* Install the EPEL package repository (for the package `fail2ban`)
* Install several packages, namely `iperf3` and `fail2ban`.
* Create firewalls rules that start with `deny all`, then open holes for `ssh`, and the iperf3 ports `5101`, `5202`, `5303` and `5404`. These will be the only ports exposed to the outside.
* Start 4x iperf3 instances inside of `screen` sessions, on ports `5101`, `5202`, `5303` and `5404`
  * These `iperf3` instances will listen on both the [public and private](https://metal.equinix.com/developers/docs/networking/) Metal interfaces.
* Configure `fail2ban` with basic SSH protection that will:
  * Ban an IP after 5 failed attempts within 10 minutes
  * That ban will stay in place for 10 minutes
  * Only watch "public" or "internet" side traffic, and will ignore or whitelist localhost and 10.0.0.0/8 (Metal management) networks
* Create a user `sftpuser` and a group `sftp_users`
* Configure OpenSSH to:
  * Allow Password based authentication (normally disabled on Metal instances by default)
  * Chroot SFTP traffic to a specific, generic directory
  * Only match users in the `sftp_users` group
* Leverage `rc.local` to restart both `ufw` and the `iperf3` servers after reboot
* Update packages including system packages every night
* Restart OpenSSH every night in order to pickup any package updates, as it is the main vector into the instance.
* Watch the `iperf3` servers every 5 minutes via cron and a lightweight script that looks for a stall'ed server (when a client disapppears during a timed test) and restarts that server.


#### Configuration ####

A user of the cloud-init file should first look at the `passwd` line of the file in the `users` section. Modifications like adding / removing additional `iperf3` servers should be self explanitory by searching for the `5101` port numbers.


In the event that an `iperf3` server becomes unvailable (crash, lockup etc), an end iperf3 client user can simply pick on of the other available ports / servers. If all `iperf3` servers become unavailable, the a reboot of the instance should return the instance to expected functionality.

