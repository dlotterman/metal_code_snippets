# Using a Metal instances as a bastion instance by tunneling browsers through SOCKs over SSH

A common problem paradigm when deploying with Equinix Metal, particularly for short lived "labs" like environments, is safely but quickly providing isolation between public and private networks while also providing the "control plane" connectivity required to operate the design. Because many Metal designs implicitly put complexity on private network operation, being able to quickly administer across those namespaces is critical.

Fortunately provisioning an Equinix Metal instance provisioned with Linux to operate as a [bastion](https://en.wikipedia.org/wiki/Bastion_host) host is quick and relatively easy, and can leverage / provide access to both Metal resources via the [Layer-3 private network](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#private-ipv4-management-subnets) as well as Metal [Layer-2](https://deploy.equinix.com/developers/docs/metal/layer2-networking/overview/) private networks.

By using a bastion host, we can forward a local browsers conenction through an SSH managed tunnel such that our local browser uses the bastion boxes's network connectivity, allowing us to reach resources that are private and local within Metal networks via the public internet in a *reasonably* secure way.

Using browser forwarding via SOCKs with SSH for transit is a generally very well understood

## Provisioning an Equinix Metal instance intended for use as a bastion instance

General speaking, no special configuration is required for a bastion Linux instance, and the role can be filled by instance that is launched with the defaults with the operators distrotribution of choice. Having said that, some concepts are key:

- [Backend Transfer](https://deploy.equinix.com/developers/docs/metal/networking/backend-transfer/#enabling-and-disabling-backend-transfer) should be enabled to turn the [private layer-3 network](https://deploy.equinix.com/developers/docs/metal/networking/backend-transfer/) network into a globally routed and available control plane
- If a lot of firewall hole punching or static IP configuration is required for a bastion instance, say to whitelist in ACL's or anything else, the operator should consider [launching](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#deploying-without-a-public-ip-address) the instance with a reserved IP or [adding](https://deploy.equinix.com/developers/docs/metal/networking/elastic-ips/#adding-elastic-ip-addresses-to-an-existing-server) an Elastic IP after provisioning.

### Assumed instance configuration

For the purposes of this document, we will assume a bastion instance named `da-bastion01` was launched as a `c3.medium.x86` with *Rocky 8* where all other provision options were left at the defaults. The equivalent Metal CLI definition for this host would be:
- `metal device create --hostname da-bastion01 --plan c3.medium.x86 --metro da --operating-system rocky_8 --project-id $PROJECT_ID`

## Configuring a Metal Linux instance for use as a bastion instance:

The metal instance is assumed to have a Metal assigned networking layout similar to:

| ADDRESS | NETWORK | GATEWAY | TYPE |
| ------- | ------- | ------- | ---- |
| 139.178.85.75 | 139.178.85.74/31 | 139.178.85.74 | Public IPv4 |
| 10.70.214.1 | 10.70.214.0/31 | 10.70.214.0 | Private IPv4 |

Where `139.178.85.75` will be considered to be the publically accesible IP address, or IP address of entry, for the environment.

Note that this document intentionally configures the Linux bastion instance using only stateless IP commands. The reason for this is that should an operator ever loose sanity, they should be able to reboot the instance and take a clean shot at configuring the instances network. In additiona, because the majority of Metal documentation regarding Linux networking is based of the `ip` command and now distroy specific tools, that is re-inforced here as well.

- SSH onto the instance as `root`
- Update and upgrade everything and then install packages
	- `dnf update -y`
	- `dnf -y install dnf-automatic git jq firewalld`
	- If asked if `cloud-init` should have its config file updated, the safest answer is to answer **NO**, which would be to enter `N` at the prompt `cloud.cfg (Y/I/N/O/D/Z) [default=N] ? N`
	- It is possible that an update to the servers `sshd` certificates will need to be re-signed after updating, this may prompt a
- Create a new administrative user (to retire root as common operator user)
	- `useradd adminuser`
	- `usermod -aG wheel adminuser`
	- `rsync -av "/root/.ssh" /home/adminuser/`
	- `chown -R "adminuser:adminuser" /home/adminuser/.ssh`
- Edit the `sshd_config` so that root can no longer be used for SSH authentication (leaving `adminuser` as the correct SSH'able user)
	- `sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config`
	- `sed -i -e '/^#MaxAuthTries/s/^.*$/MaxAuthTries 5/' /etc/ssh/sshd_config`
	- `sed -i -e '/^X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config`
- Configure the bastion host OS's firewall
	- `systemctl enable --now firewalld`
	- `firewall-cmd --permanent --zone=public --set-target=DROP`
	- `firewall-cmd --permanent --zone=public --add-service=ssh`
	- `firewall-cmd --permanent --zone=trusted --add-source=10.0.0.0/8`
	- Optionally, add other private networks to the `trusted` zone in expectation of their usage
		- `firewall-cmd --permanent --zone=trusted --add-source=172.16.0.0/12`
		- `firewall-cmd --permanent --zone=trusted --add-source=192.168.0.0/16`
	- `firewall-cmd --reload`
- Ensure VLAN based networking comes up correctly
	- `echo 8021q >> /etc/modules-load.d/networking.conf`
- Enable Automatic Updates (optional)
	- `sed -i -e '/^apply_updates/s/^.*$/apply_updates = yes/' /etc/dnf/automatic.conf`
	- `systemctl enable --now dnf-automatic.timer`
	- `echo "05 11 * * * root systemctl restart sshd" >> /etc/crontab`
- Reboot
- You can now ssh in as `adminuser` instead of `root`, where `root` should be denied access via SSH but still be allowed via local login and the [Metal OOB/SOS](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/serial-over-ssh/)

## Configuring SSH with SOCKs

From here, the remaining work is in the context of "Tunnel a browser via SSH with SOCKs" type work, which is well understood and documented. The remote host for these guides would be the public IP of our bastion host, in this document represented as `139.178.85.75`.


- Multi-platform
	- [socks5-ssh-howto](https://lowprofiler.com/socks5-ssh-howto)
	- [how-to-setup-ssh-socks-tunnel-for-private-browsing](https://linuxize.com/post/how-to-setup-ssh-socks-tunnel-for-private-browsing/)
- Windows
	- [creating-ssh-proxy-tunnel-putty](https://www.math.ucla.edu/computing/kb/creating-ssh-proxy-tunnel-putty)
	- [how-to-use-putty-as-a-socks-proxy](https://www.pwndefend.com/2022/06/25/how-to-use-putty-as-a-socks-proxy/)
	- [using-firefox-with-a-putty-ssh-tunnel-as-a-socks-proxy](https://www.adamfowlerit.com/2013/01/using-firefox-with-a-putty-ssh-tunnel-as-a-socks-proxy/)
	- [create-socks-proxy](https://www.simplified.guide/putty/create-socks-proxy)
- *nix / OSX
	- [simple-ssh-tunneling-with-foxyproxy](https://www.willchatham.com/security/simple-ssh-tunneling-with-foxyproxy/)

### Author's setup

I personally use [Kitty](http://www.9bis.net/kitty/index.html#!index.md) and [Kitty Session Manager](https://www.noobunbox.net/projects/kitty-session-manager) as my [Putty](https://www.chiark.greenend.org.uk/~sgtatham/putty/) alternative.

Configuring Kitty to forward SOCKs for us via SSH per this scenario would look like:

- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/putty1.PNG)
- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/putty2.PNG)

I then use FoxyProxy ([chrome](https://chrome.google.com/webstore/detail/foxyproxy-standard/gcknhkkoolaabfmlnjonogaaifnjlfnp?hl=en) [firefox](https://addons.mozilla.org/en-US/firefox/addon/foxyproxy-standard/)) to fan traffic to the proxy based on requested hostname:

- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/foxyproxy1.PNG)
- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/foxyproxy2.PNG)

Confirming proxy usage:

- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/proxy.PNG)
