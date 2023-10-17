# Security TLDR

This document can only start by saying the Operator is the only party that can be responsible for security. The tooling and glue in this resource may be useful in *securing* relative to not using it in the first place, but it cannot produce *secured* outputs on it's own. That requires and can only be an output of the Operator themselves.

## Build sources / where does this software come from?

`ncb` intentionally does not collect install artifacts or "shell out" to outside, unknown or untrusted platforms or networks. It receives it's initial install filesystem from the Equinix Metal managed image. It then updates itself from vendor upstream sources (If launched with Alma for example, the host will update itself directly from Alma repositories:
```
# cat /etc/yum.repos.d/almalinux-baseos.repo
[baseos]
name=AlmaLinux $releasever - BaseOS
mirrorlist=https://mirrors.almalinux.org/mirrorlist/$releasever/baseos
# baseurl=https://repo.almalinux.org/almalinux/$releasever/BaseOS/$basearch/os/
enabled=1
gpgcheck=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9
metadata_expire=86400
enabled_metadata=1
```

`ncb` doesn't download scripts from the internet, it writes them all itself from the code seen in the `cloud-init` itself, it doesn't clone random repositories from Github, it doesn't `curl | bash`, it doesn't even install `EPEL`.

Everything installed and managed comes from vanilla upstream enterprise linux.

## Outside in vectors

`ncb` is intentional in trying to reduce the number of outside in vectors to the public internet, while still preserving public Internet as a valid access and control plane network for `ncb` based deployments.

After a provision, nmap should reveal only two ports active to an `ncb` host from the public internet:
```
Host is up (0.039s latency).
Not shown: 65533 filtered ports
PORT     STATE SERVICE         VERSION                                                                                                             22/tcp   open  ssh             OpenSSH 8.7 (protocol 2.0)                                                                                          80/tcp   open  http            nginx 1.20.1                                                                                                        | http-methods:                                                                                                                                    |_  Supported Methods: GET HEAD                                                                                                                    |_http-server-header: nginx/1.20.1                                                                                                                 |_http-title: Test Page for the HTTP Server on AlmaLinux                                                                                           9090/tcp open  ssl/zeus-admin?
```

Where port `80` is a correctly configured and up to date NGINX daemon with no POST / write access, and `22` is a correctly configured and up to date openssh daemon. No other ports or access should be publically accessible.

## Users, Authorization and Authentication from outside <-> inside

`no_code_bastion` relies heavily on the SSH ecosystem and toolkit. This is a natural starting place as Equinix Metal itself is well tooled / conceived in that [SSH ecosystem](https://deploy.equinix.com/developers/docs/metal/accounts/ssh-keys/) as well.

When an Equinix Metal instance is launched with a [Supported OS](https://deploy.equinix.com/developers/docs/metal/operating-systems/supported/), the [public keys](https://console.equinix.com/profile/ssh-keys) of each user in the [project](https://deploy.equinix.com/developers/docs/metal/accounts/projects/#users-and-projects) will be appended to the `root` user's `authorized_keys` file (so `/root/.ssh/authorized_keys`). This means that by default, any Equinix Metal user with access to the project who has correctly configured their SSH in the platform, will be able to `ssh` into the instance via the root via their own private key.

This is a powerful piece of glue / tooling. Between Equinix Metal and the Operators Email / Identity Provider (gmail, O365, Okta etc), the validaty of users and their succesful authentication can be handled for us. Put another way:

In order to a user to upload their SSH key to be included in a project's scope, the following steps must have occured:

- An already authorized and authenticated Equinix Metal user must invite the new user to the project
- That invitation is extended via email
    - In order to receive that invitation, the new user must be able to authenticate and authorize access to that email
    - Presumably, that means 2FA / authentication requirements for that new users email login, which presumably has feature parity to O365 or other table stakes email / identity feature providers
- That user creates their Equinix Metal account, which can include 2FA and SSO limitations
- That user adds their SSH keys to their profile/ssh-keys
    - That SSH key can be locked with an SSH key passphrase for an additional lock on the door
    - This should even cover the [use of FIDO](https://ubuntu.com/blog/enhanced-ssh-and-fido-authentication-in-ubuntu-20-04-lts) (think Yubikey) protected keys

We can thus reasonably assume that for a public_key to be present on an Equinix Metal instance, it has been placed there by a process that is more authenticated through trusted tooling than anything we are likely to be able to re-create on our own.

So `no_code_bastion` leans on it hard, Equinix Metal takes care of our "List of Users" problem by managing users and dropping their keys on the instance.

From there, it's just SSH doing what SSH does to authenticate and authorize access, which is about as well understood and "trustable" as is possible.

As we learn in [TLDR](docs/tldr.md#Users), `no_code_bastion` moves many administrative roles away from the Metal `root` default to the pre-defined `adminuser` Linux user, including [SSH keys](https://github.com/dlotterman/metal_code_snippets/blob/86ef4fc72a175f08f2d8b7eff531745fc927fae3/virtual_appliance_host/no_code_with_guardrails/cloud_inits/el9_no_code_safety_first_appliance_host.yaml#L89). So if someone can `ssh` into the instance as `adminuser`, that must be because their public_key was placed in the root user's `authorized_keys`, which would have to have been done by the Equinix Metal platform, which means they must be an authenticated and authorized user of this instance.

Because we concentrate all "outside" <-> "inside" traffic flows through the SSH flow, we get encryption, authentication and authorization for free for everything. There is no dependency on security through obscurity, no hoping an attacker won't see RDP exposed to the internet on an unpatched Windows instance, no sharing of passwords via a spreadsheet attachment via email and unencrypted administrative tasks like VNC are encrypted by network boundary enforcement, I.E you must SSH to cross the network boundary, so your VNC must go over SSH.

If the tooling is well done, this security should come in for format of ***convenience*** for the end user, and this resource does that. It creates convenient and accessible endpoints for common administrative tasks, and funnels them through SSH or HTTPS. The features provided alone should encourage usage, where the use of those features just happens to improve the security footprint as it would otherwise be.

This logic is not without gaps, and is certainly not advised for production deployments or deployments that may store sensitive data.

But for PoC / lab / brush clearing work, not only is this resource a significant improvement from the Equinix Metal defaults, it's a significant improvement from other potential "quick path steps" that likely leave a significantly more vulnerable footprint exposed.

## Removing Cockpit as an outside in vector

Some Operators may not be comfortable with Cockpit being open to the broader Internet. For production purposes, this would be a correct best practices.

For PoC or exploratory purposes, the security profile of Cockpit is now so well understood, and is managed here with extra steps like user lockout, that the value Cockpit brings is enough to overcome the security burden of public exposure for it to be turned on by default.

For those Operators who would still prefer to disable outside in access via Cockpit, that can be easily achieved immediately after provisioning:
```
sudo firewall-cmd --permanent --zone=external --remove-service=cockpit
sudo firewall-cmd --permanent --zone=public --remove-service=cockpit
sudo firewall-cmd --reload
```
Cockpit is now still running, but only accesible through tunneling via SSH.

# /dev/shm/forget

Because it's likely that an `ncb` host will be used as a "DevOps" workstation that will need certain credentials of varying sensitivity, `ncb` creates a folder in `/dev/shm` called `forget` specifically intended for writing sensitive credentials without writing them to disk.

There is a daily cronjob that is scheduled to `rm -rf /dev/shm/forget/*`, the idea being that will catch accidentally left over credentials from the days PoC work.

### TODO

There is a known [todo](docs/todo.md) to add letsencrypt so the SSL chain is E2E client valid by default
