# Equinix Metal BYO-OS Crash Course

This documentation is unofficial, unsupported and very unpolished.

It should be considered a requirement to read and understand the [official Equinix Metal documentation](https://deploy.equinix.com/developers/guides/what-is-ipxe/) regarding iPXE before starting here.

So you want to bring your own operating system installation to an Equinix Metal? The power and flexibility of Equinix Metal means there are a number of paths to accomplish this, however the power and flexibility of Equinix Metal also means that none of these paths is **easy**.

The day-0 learning curve for BYO-OS with Equinix Metal is steep. There is no way around this.

The simplicity of the primitives being delivered by Equinix Metal demand proper ordering and understanding by an operator for them to work at all. That is to say explicitly, BYO-OS with Equinix Metal will always be a Rube Goldberg machine. When you are done, it may be a simple machine, it may be an elegant machine, but BYO-OS with Equinix Metal will always be a Rube Goldberg machine. There is no winging it and hoping it works, it wont.

The faster you try to move the slower you will go. Each widget needs to be properly sized and placed before the next. If even one widget is out of place, the whole machine immediately stops working end to end.

Slower is better.

When you are done with day-0, day-1/2 can be a reward full of herculean tasks achieved quickly. There are Equinix Metal customers who use `custom_ipxe` to re-install their custom OS as part of their CI/CD or deployment automation. `custom_ipxe` installs can take as little as 3-5 minutes to turn around a provision with complete control. The power and value is significant.

### Moving fast
If you really want to move fast, use an Equinix Metal provided image and install your software to that image, or run your OS in a VM on Equinix Metal. Tools like [ncb](https://github.com/dlotterman/metal_code_snippets/tree/main/virtual_appliance_host/no_code_with_guardrails) can make this easy.


## What do you want to install?

- I want to install my specific version of a common Linux distribution, packaged in ISO or HTTP hosted repo format, or something based off a common linux installer
    - Great! You're in luck, as Linux's use of iPXE as a core tool has made this fairly easy! Just understand the [challenges](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/byoos.md#things-that-make-custom_ipxe-with-equinix-metal-hard) and then skip [here](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/byoos.md#installing-common-linux-distributions).

- I want to bring my own OS, that has a well documented network install path such as PXE and can download it's needed install artifacts from an HTTP or equivalent hosted endpoint.
    - Great! Your in luck, iPXE can generally be tricked into doing anything a traditional PXE install could do, it might just take some thought.

- I want to install my specific FreeBSD or other Unix
    - You may have varying degrees of difficulty ahead of you. While FreeBSD and OpenBSD both have mature network installation suites, they are dependent on a more traditional install chain than the shortcuts iPXE makes.
        - You will either need to use a [Metal instance to bootstrap](https://github.com/dlotterman/metal_code_snippets/blob/main/virtual_appliance_host/no_code_with_guardrails/docs/byo_os.md) a local network install environment
        - Use [Project XEPA](https://github.com/enkelprifti98/metal-isometric-xepa)
        - Chance it's on [netboot](https://github.com/netbootxyz/netboot.xyz)

- I want to install my own Windows installation
    - This will be varying degrees of hard but possible. Outside of Microsoft's own tooling (which you can bring yourself if you wanted too), network booting Windows is known to be difficult.
        - You will need to spend significant time building a Windows PE install chain.
        - Use [Project XEPA](https://github.com/enkelprifti98/metal-isometric-xepa)

- I want to install my own or an appliance like OS that comes with a custom ISO or custom installer that has no network installer
    - This will be hard.
        - If your installer **CAN** send output to the second serial device (unlikely), you can use `custom_ipxe` if you are willing to spend lots of toiling on unpacking and repacking the ISO with the correct settings and everything needed for UEFI.
        - Use [Project XEPA](https://github.com/enkelprifti98/metal-isometric-xepa)
        - Install to a VM hosted on a Metal instance, this is easy with tools like [ncb](https://github.com/dlotterman/metal_code_snippets/tree/main/virtual_appliance_host/no_code_with_guardrails)

- I want to boot a VMDK or other OS like cloud-image
    - This should be considered impossible without significant wizardry. If you already have tooling that is capable of hydrating an virtual disk image into a Bare Metal OS, it should work on Metal just fine, but you are already into wizard's school at that point.
    - Run the VMDK or image as a VM on Metal, this is easy with tools like [ncb](https://github.com/dlotterman/metal_code_snippets/tree/main/virtual_appliance_host/no_code_with_guardrails)


## Challenges that make `custom_ipxe` with Equinix Metal hard

These are the obstacles your BYO-OS Rube Goldberg machine **MUST** overcome. If you do not have an understanding of how your machine handles each one of these challenges, slow down and get sanity.

### Asset Hosting

Equinix Metal provides no asset or artifact hosting functionality as part of it's service offering, while many of it's feature paths are depedant on leveraging hosted assets, Custom iPXE is a perfect example of this.

In order to install a server with a custom OS, you will likely need to host HTTP(s) accessible assets, likely over the public Internet. This can come from a service like HTTP accessible Object Storage, or from a simple HTTP server hosted **somewhere**.

Often when working with PoC's on Equinix Metal, this can present an ordering or "Chicken and Egg" problem, where bootstrapping involves a custom OS, where the assets for that must be available before the bootstrap.

This may require a little bit of thought and planning.

### Video / Keyboard / Mouse - Input / Output / Console

When you boot your computer at home, you have a keyboard and mouse plugged into the computer's I/O ports, and a monitor plugged into video output from the computer. You use the keyboard and mouse to send inputs to the computer, and the computer returns some of that feedback of those instructions to your monitor. This is generally the simplest and most common way human to computer interaction happens, and is replicated in tooling like virtualization tools or remote console software, where a computer's inputs and outputs are virtualized and rendered remotely, but still emulating a set of KVM to whatever the computer is.

This is **NOT** how human to computer interaction works with Equinix Metal.

Equinix Metal primarily expects human to computer interaction to happen via the front door, that is to say the public or private IP of the server. The network is expected to be the primary path for management. When leveraging Equinix Metal's pre-built images, everything about this works by default. Once you choose to BYO-OS, you now have chosen to configure a whole bunch of tedious things that came for free with the images, like getting alive on the network in the first place.

Generally speaking, Equinix Metal `custom_ipxe` installs are meant to be automated, that is to say triggered and completed end to end by automation. Often to get to the place where it is all automated, some engineering / debugging must be done to get it that way.

#### SOS / OOB / Serial Console / KVM

To operate and debug provisioning and boot level flows, Equinix Metal provides the [SOS or Out of Band console](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/serial-over-ssh/). This tool is very powerful and very cool.

It is also **NOT** keyboard / mouse + video. This can be very confusing.

If you are familiar with a datacenter grade server chassis, you are likely familiar with some kind of lights out function commonly known as iLO or iDRAC or IPMI or some kind of BMC / lifecycle controller like device. Those BMC devices provide a number of "virtual serial" interfaces to the inside of a chassis, that is to the OS side, where the OS will see what it thinks are real serial ports, but again are just virtual devices hosted and presented by the computer that is the BMC inside the server.

To clarify, an Equinix Metal chassis is *never* configured with customer facing physical serial access. If the physical server happens to have a physical serial port, it should be left unused. If the server does not have a physical server port, a first virtual one is configured in the BMC to face the OS, this is also intended to be entirely unused.

The BMC of an Equinix Metal instance is then configured to present a **SECOND** virtual serial interface to the OS.

The SOS / OOB service is then an Equinix Metal application that accepts SSH connections as integrated with Equinix Metal's [SSH Keys](https://deploy.equinix.com/developers/docs/metal/accounts/ssh-keys/), where a successful SSH authentication will enter a virtualized environment that securely connects to that virtualized serial port hosted on the BMC.

**TLDR**:

When you SSH into the SOS / OOB of an Equinix Metal instance, you are SSH'ing into a virtualized serial console attached to your Metal instance.

**What does this mean?**

You do **NOT** have keyboard / mouse + video access to your Equinix Metal instance. You have serial port access.

Most Operating Systems are not configured to send I/O via the serial port, they expect to send it via keyboard / mouse + video. When you load a Windows installer, that is sending and receiving data via keyboard / mouse + video, **NOT** serial.

Most appliance OS installers do not support sending I/O to serial, they expect KVM.

In order to use the SOS / OOB, whatever is booted on the instance's side must understand serial port I/O.

If the only option for your installer is KVM, you can either investigate [XEPA](https://github.com/enkelprifti98/metal-isometric-xepa) or potentially contact Equinix Metal sales about reserved instances if the deployment is significant.

This is why you see `console=ttyS1,115200n8` frequently in Equinix Metal related `custom_ipxe` documentation, it is what configures the next boot of a linux kernel to send I/O to the second (start from 0) serial port.

#### Linux specifics

Linux is special in having great primitives around restoring management access via the network throughout the network install boot chain. For example Enterprise Linux allows [VNC access to the installer](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/sect-vnc-installations-anaconda-modes), many Linux installers can be [SSH](https://ubuntu.com/server/docs/install/general)'ed into after they get a DHCP lease, Redhat can even send [kernel messages of syslog](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/assembly_configuring-a-remote-logging-solution_security-hardening#configuring-the-netconsole-service-to-log-kernel-messages-to-a-remote-host_assembly_configuring-a-remote-logging-solution).

Where possible, operators can move much more quickly once they get over the day-0 difficulty of accessing Linux install environments through the front door (network)

## CDROM

Many installers packaged inside an ISO have behavioral expectations on the idea that the ISO is presented to the OS as a real CDROM device. That is to say the installer expects it is either in a CDROM, or in a virtualized CDROM, which is then visible as a hardware CDROM to the OS side.

`custom_ipxe` provides no function that is equivalent to this. iPXE is fundamentally an "OS". The hardware boots into PXE, which then boots into iPXE, which then boots into subsequent boot stages, like GRUB. That is to say, iPXE loses its entire context everytime it boots to a new context.

When a server sees a CDROM and boots from it, what is in the CDROM will become the OS, but because the CDROM is physical, when the OS boots later stages, the data in the ISO will always be present in the same CDROM device, it can expect that it can find itself again every bootstage at the same device.

iPXE cannot replicate this as it is a downstream bootstage itself, not hardware. There is no physical or virtual CDROM.

##### Trying to boot an ISO

If you try to boot an ISO through iPXE, say by downloading the ISO in an iPXE script, **this likely will not work****. Yes, you can get iPXE to boot into the ISO, just the moment it does that, the memory that held the ISO is immediately lost because you booted into a new OS context. This is why custom installers or custom appliance ISOs can be a real challenge.

If one is thoughtful, and has the ability to unpack and repack and investigate INT13h tricks, it is potentially possible to make a custom installer / ISO work via this path, but it requires a high degree of expertise and will simply require toil to get working.

Along with overcoming the boot context problems with ISOs, custom installers also usually have problems with serial ports and other Metal challenges as well.

#### LACP

While a instance can iPXE boot from a single NIC (thanks to [LACP fallback](https://duckduckgo.com/?q=lacp+fallback&ia=web), it will likely be expected that somewhere in the install process, LACP with the correct addressing is configured for the appropriate NICs. The MAC addresses for each NIC in an instance can be pulled from the API (also via CLI).

That LACP should be configured with LACP `slow`, `100` ms miimon, and Layer3+4 802.3ad bonding options.

#### BIOS / UEFI handling

Equinix Metal instances provisioned via on-demand may come in unpredictable BIOS vs UEFI states, that is to say you may not know which one you will get. Put another way, one c3.medium provisioned in DA may be delivered to a customer in BIOS state, the next one immediately provisioned to that same customer could come out in UEFI state.

That means BYO-OS install toolchains must be able to accommodate both BIOS and UEFI hardware configurations.


## What happens when an Equinix Metal set to custom_ipxe boots?

When an Equinix Metal instance that is provisioned with `custom_ipxe` boots, it will do its standard BIOS POST. It will then proceed through the list of first boot devices, which would essentially look like:

1. NIC0 - PXE
2. Disk0

Because the first device in the bootlist is the first NIC, the system will hook into the NIC's PXE functionality, where the NIC will DHCP request out onto the network. The instance's DHCP request will be immediately answered by its Top of Rack switch, which will provide it with IP information including gateway (Public IPs if configured with publics, otherwise it will fall back to Private IPs), and a TFTP / PXE boot server. The instance will then ask for that tftp / PXE boot option, to which the Metal platform will give it a very simple iPXE script, which is configured to hand off to the iPXE information the customer provided at provision time.

Once the instance has booted through the iPXE chain and handed off to the customer iPXE chain, the platform considers the installation "done", and the instance goes "green" or "active" in the portal.  By default, DHCP will also now be turned off for instance at the Top of Rack. This means when the instance reboots after the installer, it will still go through the same boot devices, just when it asks for a DHCP lease, it will get none, so it will proceed to the next device, local disk0, which should have the recently installed OS on it, and the instance boots.

If your OS environment is such that the instance should get a DHCP lease every time / anytime and go on the iPXE chain every time at boot, you can enable the [always_pxe](https://deploy.equinix.com/developers/docs/metal/operating-systems/custom-ipxe/#persisting-pxe) option for the instance.

### What happens when a `custom_ipxe` server boots in Layer-2 only?

Exactly what you think, the server will boot into the NIC as its first device, the NIC will begin its ARP / DHCP chain on the native or untagged VLAN, and whatever networking is configured for Layer-2 on the Metal side will apply.

If you want to bring your own OS install chain, this is how you do it. Put everything into your own L2 domains and own the chassis journey from its first DHCP.

This will either require a bootstrap instance, or for fun wizardry, [Interconnection](https://deploy.equinix.com/developers/docs/metal/interconnections/introduction/) back to an existing provisioning stack.

## Installing Common Linux Distributions

If what you want to install is essentially just a Linux distribution (Alma, Ubuntu etc) from official or sanely packaged media or repositories, this should be very easy, just keep in mind things like LACP bonding and serial port configurations.

- [Example to unpack and host a Enterprise Linux ISO](https://www.redhat.com/sysadmin/apache-yum-dnf-repo)
- [Example with unpacking Ubuntu at the bottom](https://trn84.medium.com/using-pxe-for-the-automatic-and-customized-installation-of-ubuntu-18-04-server-e813a7c4d614)

Some examples of iPXE scripts for common Linux distributions can be found [here](https://github.com/dlotterman/metal_code_snippets/tree/main/ipxes).

You can then use [kickstart](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/performing_an_advanced_rhel_9_installation/kickstart-installation-basics_installing-rhel-as-an-experienced-user) or [pre-seed ](https://www.debian.org/releases/stable/amd64/apb.en.html) files to automate the install.

The common [Equinix Metal documentation](https://deploy.equinix.com/developers/guides/what-is-ipxe/) should be sufficient for this case, where [netboot](https://github.com/netbootxyz/netboot.xyz) can also be extremely useful to get up to speed quickly.

## Bring your own existing OS install toolchains

This is easier than one may think. If you want to use a tool like [ncb](https://github.com/dlotterman/metal_code_snippets/blob/main/virtual_appliance_host/no_code_with_guardrails/docs/byo_os.md) or bring your own installchain to a bootstrap instance.  You are free to catch the DHCP leases of Metal instances inside of a customer VLAN, and boot and power controls are exposed via the API.

This can enable things like [Automated Openshift installations](https://github.com/dlotterman/metal_assisted_openshift), and special projects like [not_ipmi_to_metal](https://github.com/equinix-labs/not_ipmi_to_metal)
