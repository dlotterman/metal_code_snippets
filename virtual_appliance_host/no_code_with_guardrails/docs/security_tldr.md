# Security TLDR

This document can only start by saying the Operator is the only party that can be responsible for security. The tooling and glue in this resource may be useful in *securing* relative to not using it in the first place, but it cannot produce *secured* outputs on it's own. That requires and can only be an output of the Operator themselves.

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

### TODO

There is a known [todo](docs/todo.md) to add letsencrypt so the SSL chain is E2E client valid by default
