# TLDR on how this works

[cloud-init](https://cloudinit.readthedocs.io/en/latest/index.html) is how the cloud bootstraps, it is step 0, and Equinix Metal fully supports it. *cloud-init* allows an operator to provide a cloud provisioned instance with a basic set of instructions about how it should prepare itself as part of it's initial provisioning lifecycle, and can be incredibly powerlful.

This resource works by extending the basic primitives of `cloud-init` with modern Enterprise Linux best practices (`nmcli`, `systemd` etc) and some [quick opinions](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/em_sa_network_schema.md). It is essentially a shell script, that does some stuff so that you don't have to.

## hostname consequence
A couple of internal logic structures are key'ed off the hostname chosen to launch the instance, put another way, the hostname of the `ncb` instance must be in a certain format, and decision are made based on that format.

### Internal IP addressing via end of string

The end of a `ncb` instance should end in a dash delimited number, for example `-2`, or `-03`, or `-003` are all accepted, where internally that will be resolved to a `HOST_IP` of `3`.

For any internal network, that `$HOST_IP` will then be used as the ending integer of any private network. So an instance launched with a hostname of `ncb-da-04` will have an internal `mgmt_a` address of `172.16.100.4` for example. If it had been launched as `ncb-da-05`, it would have an internal IP of `172.16.100.5`

### ncb instances ending in `-1`

Any host that ends in `-1` (so `-01` would be included), will activate a special internal decision: the decision to bridge the ncb hosts internal *libvirt* network into Metal VLAN `4`. Effectively extending the libvirt network's functions (DHCP, NAT, DNS) into the Metal network, allowing devices in Metal VLAN 4 to DHCP off the ncb.

While powerful, this function is also potentially dangerous. Because the network will announce a new default route via DHCP, any device that picks up a lease on that network, while already having a default route, will receive a secondary, likely conflicting default route.


## Package Updates, and Meta and Packages
- On the public internet, an out of date host is a vulnerable host. First thing we have to do is update OS to current.
[Update Instance](https://cloudinit.readthedocs.io/en/latest/reference/examples.html).
```
package_upgrade: true
package_reboot_if_required: true
```
- Quiets some cloud-init ouput on the host
```
datasource:
  Ec2:
    apply_full_imds_network_config: false
    strict_id: false
```

- Install these packages post update, mostly what is needed for Cockpit + VM/Container Hosting
```
packages:
  - iperf3
  - tmux
  - firewalld
  - jq
  - vim
  - nc
  - git
  - dnf-automatic
  - dnf-plugins-core
  - unzip
  - virt-manager
  - libvirt-client
  - virt-install
  - libvirt
  - qemu-kvm
  - qemu-img
  - libguestfs
  - net-tools
  - wget
  - nginx
  - bind-utils
  - cockpit
  - cockpit-machines
  - cockpit-storaged
  - cockpit-podman
  - cockpit-system
  - cockpit-bridge
  - cockpit-pcp
  - cockpit-packagekit
```

## Automatic Updates

We use `cloud-init` to get the OS itself up to date first, but then we also configure the underlying OS to automatically update itself:
```
  - [ sed, -i, -e, '/^apply_updates/s/^.*$/apply_updates = yes/', /etc/dnf/automatic.conf ]
```
```
  - [ systemctl, enable, --now, dnf-automatic.timer ]
```
This crontab has us restarting ssh in case it gets an update that didn't restart it, same for other interactive services.
```
  - path: /etc/crontab
    owner: root:root
    append: true
    content: |
      05 11 * * * root systemctl restart sshd
      10 11 * * * root systemctl restart cockpit.service
      12 11 * * * root systemctl restart cockpit.socket
      15 11 * * * root systemctl restart serial-getty@ttyS1.service
      20 11 * * * root systemctl restart getty@tty1.service
```

Note that the host will update itself, including running services, and it will even update it's kernel. What it wont do as currently configured is reboot the host without an operator telling it to do so.

## Users
By default, Equinix Metal turns up Linux instances with `root` user as the initial ssh exposed user. This is fine for turnup, but not for longlived things on the public internet. Follow best practice to move remote access to `adminuser`, and limit `root` to local (OOB/SOS) login.

We even go so far as to copy the `root` users password (Assigned by Equinix Metal at provision time and exposed via the UI) to the `adminuser` user. Allowing the Operator to login via *Cockpit* with `adminuser` and the root users password, again exposed in the UI for 24 hours after provision.

```
groups:
 - cloud-users
```
```
users:
  - name: adminuser
    primary_group: cloud-users
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [cloud-users, sudo]
    shell: /bin/bash
```

```
  - [ chown, -R, "adminuser:cloud-users", "/home/adminuser/.ssh" ]
  - [ sed, -i, -e, '/^#PermitRootLogin/s/^.*$/PermitRootLogin no/', /etc/ssh/sshd_config ]
  - [ sed, -i, -e, '/^#MaxAuthTries/s/^.*$/MaxAuthTries 5/', /etc/ssh/sshd_config ]
  - [ sed, -i, -e, '/^X11Forwarding/s/^.*$/X11Forwarding no/', /etc/ssh/sshd_config ]
```
```
  - path: "/var/tmp/metal_adminuser_mangle.sh"
    owner: root:root
    append: false
    content: |
      logger "running /var/tmp/metal_adminuser_mangle.sh"
      pwhash=$(sudo getent shadow root | cut -d: -f2)
      sudo usermod -p "$pwhash" adminuser
      chmod 0400 /var/tmp/metal_adminuser_mangle.sh
    permissions: '0644'
```

### User lockout
As part of a "two locks on every door" approach, we use Linux's `authselect` to lockout users, either via SSH, Cockpit or local login (OOB/SOS)
```
  - [ authselect, select, minimal, with-faillock, --force ]
```
```
  - path: "/etc/security/faillock.conf"
    permissions: "0644"
    owner: "root:root"
    append: true
    content: |
      deny=4
      unlock_time=300
      audit
      even_deny_root
      root_unlock_time=60
```
Cockpit by default uses local auth / PAM so this is super easy. Good work Cockpit.


## bootcmd

We use this just to disable kdump. Think of `bootcmd` as like an early Unix's `rc.local`

## runcmd

If `bootcmd` is `rc.local`, `runcmd` is `rc.d/`.

It may be confusing why some stuff is in `runcmd` and why some in scripts below. In general, `runcmd` has much better state supervision than scripts running willy nilly. When in doubt, try to manage your major step changes via `runcmd` even if thats just to shell out as a step.

## Firewall and NFT
We use the firewall to create a very simple *outside vs inside* scheme. Close the door on everything but `ssh`, `http`, and `cockpit` to the Internet, allow all things from the inside that are known.

Please not the firewall can be managed in a limited fashion through Cockpit.

How the linux Firewall interacts with virtualziation can be confusing, especially when later we provision lots of Layer-2 networking. In this model, think of the Linux firewall as being "for me" but "not for thee" when it comes to host vs guests. If there is a "Layer-3" statement, that statement is about the host's layer-3, or "for me", and NOT it's guests "for thee".
```
  - [ systemctl, enable, --now, firewalld ]
  - [ firewall-cmd, --permanent, --zone=public, --set-target=DROP ]
  - [ firewall-cmd, --permanent, --zone=public, --add-service=ssh ]
  - [ firewall-cmd, --permanent, --zone=public, --add-service=http ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-port=81/tcp ]
  - [ firewall-cmd, --permanent, --zone=public, --add-service=cockpit ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=10.0.0.0/8 ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=172.16.100.0/24 ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=192.168.101.0/24 ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=172.16.253.0/24 ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=192.168.252.0/24 ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=172.16.251.0/24 ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=192.168.250.0/24 ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=172.16.249.0/24 ]
  - [ firewall-cmd, --permanent, --zone=trusted, --add-source=192.168.248.0/24 ]
  - [ firewall-cmd, --reload ]
```
We use nftables to set a second (third really) lock on the SSH door.
```
  - [ nft, add, table, ip, SSHWATCH ]
  - [ nft, 'add chain ip SSHWATCH input { type filter hook input priority 0 ; }']
  - [ nft, 'add set ip SSHWATCH denylist { type ipv4_addr ; flags dynamic, timeout ; timeout 5m ; }']
  - [ nft, 'add rule ip SSHWATCH input tcp dport 22 ip protocol tcp ct state new, untracked limit rate over 10/minute add @denylist { ip saddr } log prefix "CLOUD-INIT MANAGED NFT dropping:"']
  - [ nft, 'add rule ip SSHWATCH input ip saddr @denylist drop']
```

## nginx
It is often necessary to host assets (ISOs, VM images etc) on a variety of networks when trying to establish an operational footprint, this is one of those "high toil" tasks this resource aims to solve simply. It deploys NGINX with a server listening on both the public internet, and also one that is only accessible to private Metal networks.

```
  - path: "/var/tmp/metal_nginx_mangle.sh"
    owner: root:root
    append: false
    content: |
      logger "running /var/tmp/metal_nginx_mangle.sh"
      curl -s https://metadata.platformequinix.com/metadata -o /tmp/metadata
      HOST_IP=$(hostname | awk -F "-" '{print$NF}' | sed 's/^0*//')
      PRI_IP=$(jq -r '.network.addresses[] | select((.public==false) and .address_family==4) | .address' /tmp/metadata)
      cp -r /usr/share/nginx/html /usr/share/nginx/private_html
      mkdir /usr/share/nginx/private_html/autoindex
      rm /usr/share/nginx/private_html/index.html
      echo "private network" > /usr/share/nginx/private_html/index.html
      echo "private network" > /usr/share/nginx/private_html/autoindex/index.html
      cat > /etc/nginx/conf.d/metalprivate.conf << EOL
        server {
            listen       $PRI_IP:81;
            listen       localhost:81;
            listen       172.16.100.$HOST_IP:81;
            listen       192.168.101.$HOST_IP:81;
            listen       172.16.253.$HOST_IP:81;
            listen       192.168.252.$HOST_IP:81;
            listen       172.16.251.$HOST_IP:81;
            listen       192.168.250.$HOST_IP:81;
            listen       172.16.249.$HOST_IP:81;
            listen       192.168.248.$HOST_IP:81;
            server_name  _;
            root         /usr/share/nginx/private_html;

            # Load configuration files for the default server block.
            include /etc/nginx/default.d/*.conf;

            error_page 404 /404.html;
            location = /404.html {
            }

            error_page 500 502 503 504 /50x.html;
            location = /50x.html {
            }
            location = /autoindex {
                root /usr/share/nginx/private_html/autoindex
                index index.html;
                autoindex on;
            }
        }
      EOL

      systemctl enable --now nginx
      chmod 0400 /var/tmp/metal_nginx_mangle.sh
    permissions: '0644'
```

## data disk
We often don't want to use the boot disk for everything, for example if we use an m3.large as an `ncb` instance, we likely want to deploy VM's on to it's NVMe disk:

```
  - path: "/var/tmp/metal_disk_mangle.sh"
    owner: root:root
    append: false
    content: |
      logger "running /var/tmp/metal_disk_mangle.sh"
      curl -s https://metadata.platformequinix.com/metadata -o /tmp/metadata
      mkdir /mnt/util
      PLAN=$(jq -r .plan /tmp/metadata)
      DRIVE=$(lsblk --bytes -o name,rota,type,size |  grep -v "zram" | grep -v " 1 " | grep disk | awk '{print$4,$1}' | sort -r -n  | head -1 | awk '{print$2}')
      sgdisk --zap-all /dev/$DRIVE
      mkfs.xfs -f /dev/$DRIVE
      sync
      sleep 2
      sync
      DRIVE_UUID=$(ls -al /dev/disk/by-uuid/ | grep $DRIVE | awk '{print$9}')
      cat > /etc/systemd/system/mnt-util.mount << EOL
      [Unit]
      Description=metal-mount-util-drive (/mnt/util)
      DefaultDependencies=no
      Conflicts=umount.target
      Before=local-fs.target umount.target
      After=swap.target
      [Mount]
      What=/dev/disk/by-uuid/$DRIVE_UUID
      Where=/mnt/util
      Type=xfs
      Options=defaults
      [Install]
      WantedBy=multi-user.target

      EOL

      systemctl daemon-reload
      systemctl start mnt-util.mount
      chmod 0400 /var/tmp/metal_disk_mangle.sh
    permissions: '0644'
```

## network
While this is too complicated for a TLDR, we essentially have to tear down the networking that comes with a Metal image because that networking applies addressing directly on the bond, which makes doing VLAN abstraction work impossible.

So we tear that networking down to rebuild a "`bridge` before the bond" model that allows us to easily extend VLAN networking into guest level abstractions.

We also lean on the opinions of the [Equinix Metal Solutions Architect Network Schema](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/em_sa_network_schema.md) to allow us to rebuild the network with enough opinion to be immediately useful.

```
  - path: "/var/tmp/metal_network_mangle.sh"
    owner: root:root
    append: false
    content: |
...
```
