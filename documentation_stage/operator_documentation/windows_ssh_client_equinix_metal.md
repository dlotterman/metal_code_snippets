## Using the native Windows 10 SSH client with Equinix Metal

**Disclaimer:**
*This document is UN-official, is only meant to be used as a reference, and is in no way supported by Equinix Metal itself.*

Since ~2018, most up-to-date distributions of Windows 10 and adjacent releases (Server etc) have included a command-line SSH client as part of it's standard distrobution. This ssh client, which can be found via the `cmd` terminal or powershell terminal, closely mimics/behaves in line with the common behaviors exhibited by default SSH clients on *nix platforms. 

This greatly simplifies paths to *nix systems administration and operation from Windows 10 based workstations, however, the native client has some behavior deviations from the standard *nix clients that can be confusing, and can potentially clash with other "ssh client" documentation easily found via search engines. 

This document aims to quickly describe:

* Equinix Metal and its use of SSH
* Generating an SSH key on a Windows 10 workstation with the native Windows 10 ssh toolchain
* Applying and using that generated SSH key with Equinix Metal


### Equinix Metal and its use of SSH

Equinix Metal uses SSH and SSH keys for two key functions of systems administration:


1) Primary operator management vector for configuration of the host OS via the host Operating Systems environment and networking (aka SSH into host OS after provision as OS user)
2) Secondary, "Out of Band" (or more appropriately named: Serial over SSH or SOS) operator management vector for instance, and host OS configuration, where Equinix Metal provides an SSH endpoint that drops the operator at an emulated Serial (ttyS1 in Linux speak) console attached to the lifecycle controller of the Bare Metal Instance.

*Most importantly*, it should be understood that the use of SSH keys with Equinix Metal is a critical function of the platform, and an essential consideration for a succesful deployment. These SSH keys, especially in conjunction with the SOS / OOB functionality described below, are part of your operator toolchain for recovering Metal instances under the most critical times of duress, and these mechanics should be understood specific to your deployment.

#### Primary Management Vector

When an Equinix Metal instance is provisioned with an [Equinix Metal provided image](https://metal.equinix.com/developers/docs/operating-systems/), it is loaded with the [cloud-init](https://cloudinit.readthedocs.io/en/latest/) service, which on first boot will pull a variety of metadata attributes from the [Metal Metadata API](https://metal.equinix.com/developers/docs/servers/metadata/). This metadata includes a variety of things including hostnames, networking, user provided data, [and also SSH keys](https://metal.equinix.com/developers/docs/accounts/ssh-keys/). When deploying an instance, the operator can choose which user's SSH keys are available to the instance at provision time. The SSH keys are copied from the Metadata API and written to the `root` user's SSH `~/.ssh/authorized_keys` file, which opens up the initial management vector for the instance, via the instances own networking that is also stood up at provision time.

This means that SSH keys, and their installation onto a Metal instance by the Metal platform, is a one time, at provision time event, where because of the [Equinix Metal Joint Management Paradigm](/documentation_stage/operator_documentation/equinix_metal_shared_responsibility_paradigm.md), the Equinix Metal platform is unable to modify or reconfigure the SSH keys on a host after provision time. Any changes to the SSH keys on the host OS after initial provisioning must come from the operators themselves.


#### Secondary / SOS / OOB

The Equinix Metal SOS is a secondary management vector for the management of Equinix Metal instances. It can be used in a variety of different ways / functions depending on the design of the deployment, but is primarily there as a "backup" management vector of last resort, intended for "loss of networking" events or instances that need to be configured when a management network is unavailable. 

When an Equinix Metal instance is provisioned, the same SSH-keys that are provided to the host via the Metadata API, are also installed at the SSH keys granting access to the SOS console. Similar to host Operating System SSH keys, these SOS SSH keys are primarily managed at install time. Unlike the host OS management problem, Equinix Metal has end to end lifecycle control over the SOS console, and hence can manage and update SSH keys after provisioning time. This can be key to recovering an instance where the initial management SSH keys may have been lost, or new users are added to the platform that may need that management access.

It is worth being extremely clear here: The SOS console ONLY provides logical ACCESS to the Bare Metal instance's host OS, it does NOT provide a user or an authentication vector to the host OS behind the SOS console. The operator must have the local login credentials to the box, even with the SOS console. Think of the SOS console as your IP-KVM, where you still need a local user inside the host OS in order to subsequently login to the Operating Systems environment. 

It should be noted that the feature to update the SSH keys of the SOS console is new to the platform as of Q4 2021. Previously it was a static configuration set at deploy time.

### Generating an SSH key on a Windows 10 workstation with the native Windows 10 ssh toolchain

Generating an SSH key with the Windows 10 ssh toolchain for the most part will follow SSH client documentation, in particular Windows documentation. What "search engine" found documentation will often miss is that keys, including SSH keys, are an attribute of Microsoft systems configuration, and things like environment variables and default behavior can be inherited from Active Directory or other change management sources. 

Most often, this can mean SSH key files are generated either in unexpected directories, or any directory outside of the default / expected `~/.ssh/` folder. Because of this, I encourage users to specify their own name for the SSH key, this will force the generation of the associated private and public files to be written to the local, working directory at the time of generation. This lets us know for a fact where our keys are.

The flag for this is the `-f` option in the `ssh-keygen` command. My example would be:

`ssh-keygen -t ed25519 -C "myemail@domain.com" -f metal_ssh_key`

This will generate an SSH key, using a modern encryption scheme (`ed25519` which is supported by the SOS as well as modern sshd servers), tagged to the defined email address, and it will write out the private key as a file named `metal_ssh_key` as the private key and a file named `metal_ssh_key.pub` as the public key in the working directory the command was run from.

Note that it would be recommended to use a more descriptive SSH key name, both for easier reference on your local machine as well as to identify your key vs the keys of other users in the Equinix Metal account.

Please be sure to see the section of this document titled "Using your SSH key with the Windows SSH client" as well, it contains the flag to instruct the Windows 10 ssh client to use the key we generated, where similar Active Directory / Change Management may obscure it's usage.

### Applying and using that generated SSH key with Equinix Metal

The **exact** string contents of the `metal_ssh_key.pub` file are [what need to be uploaded to the Equinix Metal platform as the users public side of their SSH key](https://metal.equinix.com/developers/docs/accounts/ssh-keys/#ssh-keys). For example from the command issued above, the string to be entered would be: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJxlYzr2vfFzwo3Dk1RHobYBm7LdmQrYAjDp6NNrN7z1 dmyemail@domain.com` . Note that if your string contains the substring `-----BEGIN OPENSSH PRIVATE KEY-----`, you are looking at the PRIVATE key, which is the incorrect side to upload to the Metal platform.

#### Updating the SOS console 

When a new key is uploaded to the Equinix Metal platform, there is an option to "Associate key with these instances", where the operator can filter and select the already provisioned instances they would like to add their SSH key to. 

![](https://s3.wasabisys.com/metalstaticassets/metal_ssh_key_add.JPG)

Per the documentation above, Equinix Metal *CAN NOT* update the SSH keys installed to the host OS after provision time. This means that the uploaded key will *NOT* be present on the instance until the operator uploads the key themselves, or the instance is "reinstalled" via the Equinix Metal platform, which functionally triggers a full re-provision, which gives the oppertunity for the new key to be loaded. 

However, the SSH keys for the SOS / OOB endpoint for the instances WILL be updated, such that the new key should immediately be available for use with the SOS / OOB console after it is uploaded, so long as the correct instances are selected at upload time.

#### Using your SSH key with the Windows SSH client

Windows environments are often heavily managed by Active Directory or other change management engines, which can apply environment defaults or behaviors that can impact which SSH keys (among other attributes) are used by default with the ssh client.

For this reason, I strongly advise users to always specify the private side of the SSH key they would like to use with the Windows SSH client, until sufficient comfort with the toolchain is reached that the user can decide their own best practices.

To specify the key we generated in our previous example, the `-i` flag is used to specify the identity key files to use:

```
ssh -i .\metal_ssh_key UUID-STRING@sos.ny5.platformequinix.com
The authenticity of host 'sos.ny5.platformequinix.com (147.28.136.163)' can't be established.
RSA key fingerprint is SHA256:AAAAAAAAAAAAAAAAAAAEXAMPLE.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'sos.ny5.platformequinix.com,IP' (RSA) to the list of known hosts.
[SOS Session Ready. Use ~? for help.]
[Note: You may need to press RETURN or Ctrl+L to get a prompt.]
```

