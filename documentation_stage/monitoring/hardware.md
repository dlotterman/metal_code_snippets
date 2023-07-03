# The unofficial guide to monitoring with Equinix Metal: Hardware

## Introduction

Observing and monitoring the underlying hardware of an Equinix Metal instance should be considered an operational imperative for a successful production deployment on Equinix Metal infrastructure.

While the number of possible deployment models and technology stacks make it impossible to provide a single "correct answer" for how to monitor hardware, this document will attempt to cover the most pressing subjects and strategies for addressing them.

- [Management Model](#Management-Model)

	- This will cover the "joint management" model with Equinix Metal and the unique paradigm it imposes on operations of the hardware

- [Platform and Automation](#Platform-and-Automation)

	- This will cover areas where certain features Equinix Metal platform can assist in the deployment of monitoring solutions as well as the automation available to assist with those deployments.

- [Monitoring Subject Areas](#Monitoring-Subject-Areas)

	- This will cover areas of particular interest surfaced by operating Bare Metal

- [Monitoring Stacks](#Monitoring-Stacks)

	- This will cover certain highlighted software stacks from both open-source projects and proprietary providers that may be immediately useful to customers deploying on top of Equinix Metal
	- This section will also cover specifics regarding underlying hardware OEM's available in Equinix Metal and the implications thereof


### Underlying Hardware Monitoring vs "Systems Monitoring"

It is worth clarifying that this document specifically focuses on monitoring of the underlying, physical hardware that makes up an [Equinix Metal instance](https://metal.equinix.com/developers/docs/servers/about/), and not general *Systems Monitoring*, though they both may use overlapping terms and concepts. As an example, this document is focused on monitoring "CPU Temperatures" as collected by the motherboard and CPUs sensor data, vs "CPU Load", which would be an attribute of *Systems Monitoring*

## Management Model

Equinix Metal operates in a "Joint Management" model with its customers, where that "Joint Management" model should be immediately recognizable to that of other Cloud Infrastructure platforms where both the platform and the operator must cooperate in the overall operations of a healthy deployment.

Particular to Equinix Metal, there is a unique paradigm where the platform itself is intentionally unable to assist in certain aspects of management or operations. Consider receiving a Bare Metal instance from the platform as an end operator (customer):

- A Equinix Metal Bare Metal instance is provisioned into a customer account via the console or API

	- While the Operating System may come from an Equinix Metal source (its image repository for example), that operating system has no built-in agent, shim, or software that is accessible to the Equinix Metal platform or staff. It is dedicated entirely to the customer

	-	So much so that the root Operating System password is reset to something unknown to Equinix Metal, and the SSH keys are pre-configured as defined by the Operator when provisioning the instance

-	Because these are Bare Metal instances, there is no secret hypervisor or backplane access to the customer's OS environment

This means that once a customer has "taken delivery" of an instance, that is the instance has been successfully provisioned into their account, there is no vector of access for any kind of management from the Equinix Metal platform. This means Equinix Metal has no point of visibility with which to monitor the actual health of the chassis from the key perspective of the operating system installed. This is by design for the safety and security of the operator (customer).

This means that the end operator must implement sufficient monitoring of the underlying hardware to meet their operational requirements.

The customer can work with their Equinix Metal sales teams to define a path to communicating and cooperating on hardware events as they arise from operating the Metal Instances themselves.

### Platform and Automation

The Equinix Metal platform provides many useful features for operators as they work to deploy any kind of supporting monitoring platform or stack, including integrations that can or are leveraged by a variety of automation stacks to extend those features into the customers' operational model.

#### The Equinix Metal API

The [Equinix Metal API](https://metal.equinix.com/developers/api/devices/) exposes several endpoints that could be useful to monitoring operations.

- The [devices endpoint](https://metal.equinix.com/developers/api/devices/) can provide a variety of lists of deployed instances or resources, which can be filtered in several ways
	- This endpoint is well integrated into many different [libraries](https://metal.equinix.com/developers/docs/libraries/) and [projects](https://metal.equinix.com/developers/docs/integrations/), including , [Ansible](https://github.com/equinix/ansible-collection-metal), and

	- The [events endpoint](https://metal.equinix.com/developers/api/events/) can provide transparency regarding the lifecycle of a deployed resource overtime

#### Operations Tooling Integrations

Equinix Metal is well integrated with tools like [Terraform](https://registry.terraform.io/providers/equinix/metal/latest), [Ansible](https://github.com/equinix/ansible-collection-metal) and [others](https://metal.equinix.com/developers/docs/integrations/devops/). These integrations can dramatically simplify the operational cost of monitoring implementation by allowing complex deployments to be templated with metadata from the API and other sources.

This code snippet for example, is all thats needed to template a Prometheus config with Ansible to scrape the [node_exporter](#prometheus--node_exporter--grafana) for every Metal instance in a project:

```
#jinja2: trim_blocks:False
---
global:
  scrape_interval: 15s

  external_labels:
    monitor: 'metal-monitor'

scrape_configs:
  - job_name: 'all-host-node-exporter'

    static_configs:
      {% for host in groups['all'] %}
      {{"- targets:"}}
        {{"- " + hostvars[host]['ansible_facts']['bond0_0']['ipv4']['address'] + ":9100"}}
        {{"labels:"}}
          {{"instance: " + hostvars[host]['ansible_facts']['hostname']}}
    {% endfor %}
```

#### Metadata Endpoint

The Equinix Metal [Metadata Endpoint](https://metal.equinix.com/developers/docs/servers/metadata/) is an endpoint that is virtually hosted inside of every Equinix Metal project, that provides HTTP retrievable information about the instance, its configuration and user-assigned attributes such as tags. Its usage should be similar to the private Metadata Endpoints of other I.a.a. S-like platforms. This can be quite powerful when used in conjunction with the Userdata function, allowing instances to dynamically configure themselves as they exit the provisioning stages but before production enrollment

#### Userdata

Equinix Metal instances can be [launched with a variety of "Userdata" options](https://metal.equinix.com/developers/docs/servers/user-data/), including "first boot scripts" or `cloud-init` configurations that extend the ability of an instance to configure itself as part of provisioning. This can be immensely useful in the automation of hardware monitoring software.

#### Port Monitoring

While it would be regarded as more of a *Systems Monitoring* attribute, the Equinix Metal platform will monitor /trend the physical switch ports attached to an Equinix Metal instance. The monitoring of these switch ports is primarily enabled because they are the primary visibility point for our billing data collection systems, however, the data is surfaced in the Console for use by customers as well. An instance's bandwidth usage is thus visible in the console by Selecting an instance, where the "24-Hour Traffic Trend" graph should be visible on the lower right-hand side. Clicking on that graph will expand the page into a larger, interactable graphing page.

### Monitoring Subject Areas

#### Drive Health

Monitoring the health of the drives in a chassis is arguably *the most important* attribute to monitor and trend in an Equinix Metal deployment.

While potentially daunting seeming, the actual operational tasks of disk monitoring are quite well understood, with a robust ecosystem of tools and packages available.

When monitoring underlying disks, it is important to understand levels of abstraction that may be in play. Individual disks should always be monitored for health and activity. If those disks are placed into a RAID construct, the health of that RAID construct should also be monitored while still monitoring the underlying disks that make up that RAID construct.

**The downstream consequences of a failing individual disk should never be underestimated.**

NVMe drives specifically may introduce additional specificity needed in monitoring, where many operating systems are still [catching up](https://www.cyberciti.biz/faq/linux-find-nvme-ssd-temperature-using-command-line/) to [established norms](https://www.phoronix.com/scan.php?page=news_item&px=Linux-5.5-NVMe-HWMON-Support) for drive monitoring access. The [SMARTMON ecosystem has been NVMe aware](https://www.smartmontools.org/wiki/NVMe_Support) for some time now.

#### Chassis and Sensor Data

Outside of OEM-specific packaging (discussed later in [Monitoring Stacks]), modern data-center grade servers provide a wealth of chassis, sensors, and other data. While the specific source of this data, including:

- Environmental

	- Temperature of CPUs, motherboard sensors, and others
- 	Various motherboard level electrical voltages and stats
- 	Fan speeds

The monitoring of these specific attributes can be different depending on the underlying hardware and what is available for the software running on that hardware. For example, while AMD has been actively investing in its sensor exposure in Linux, as of Q4 2021 it is still contributing patches to the upstream Linux ecosystem for its currently deployed lineup. As such the availability of certain sensor data or modules to monitor that sensor data may or may not be "built-in" to the kernel version of a released OS.

As a specific example, to monitor an AMD Rome chip, the needed `k10temp` module is not present in Ubuntu 20.04 releases by default and must be built before loading any sensor data.

#### The physical network

While *Systems Monitoring* around host-level network attributes is generally well understood, the nature of an Equinix Metal instance being directly connected to a physical network introduces a variety of other attributes that should be monitored due to their significance in upstream systems.

Beyond just link-state, network interfaces offer a [wealth of statistics on packet rates and errors](https://www.kernel.org/doc/html/latest/networking/statistics.html). [Specific drivers](https://community.mellanox.com/s/article/understanding-mlx5-ethtool-counters) can also expose their own driver level statistics, which can be immensely useful in capturing NIC <-> Host OS-specific problem areas.

Particular to Equinix Metal, which makes heavy use of [LACP / Link Aggregation](https://metal.equinix.com/developers/docs/layer2-networking/hybrid-bonded-mode/), capturing [bond specific level metrics](https://www.kernel.org/doc/Documentation/networking/bonding.txt) can be useful as well.

While more of a Systems Monitoring level concern, it can also be useful to trend the network latency between an instance and its [public and private gateways](https://metal.equinix.com/developers/docs/networking/ip-addresses/).

#### Monitoring Stacks

One of the most important characteristics of Equinix Metal instances is that at the end of the day they are just Bare Metal Servers. Any existing tooling or methods of monitoring Bare Metal Servers an Operator may have, should more or less *just work* with Equinix Metal. Having said that, this section will outline a couple of notable monitoring stacks and their usage with Equinix Metal.

#### smartmontools

While not a fully-featured monitoring stack itself, smartmontools is a useful foundational tool for any Bare Metal deployment. It is well maintained, well integrated with operations tools like Ansible and Terraform, easily incorporated with the below monitoring stacks as well.

##### Nagios-Icinga / Zabbix / OpenNMS

These monitoring software stacks are well known and well documented. They all have robust features for monitoring the [Subject Areas](#monitoring-subject-areas) covered earlier, and are also all relatively easy to extend where needed. Equinix Metal instances will behave as "just any other server" to these tools.

Using Nagios-Icinga as a reference, here are some examples of packages which cover these specifc subjects:

- Disk: [smartmon](https://www.thomas-krenn.com/en/wiki/SMART_Attributes_Monitoring_Plugin_setup), [software-raid](https://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check_md_raid/details)

- Chassis: [chassis temperatures](https://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check_temp/details)

- Network: [bonding](https://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check_linux_bonding/details), [interface statistics](https://www.claudiokuenzler.com/monitoring-plugins/check_netio.php)

#### Prometheus / node_exporter / [Grafana](https://metal.equinix.com/customers/grafana/)

While originally purposed for application-level monitoring, the community around [Prometheus](https://prometheus.io/docs/guides/node-exporter/) and particularly its [node_exporter](https://github.com/prometheus/node_exporter) role rapidly extended it into a variety of other monitoring domains including hardware.

Beyond the list of built-in `collectors`, it is relatively easy to extend `node_exporter` with it's `textfile` collectors, for example this [textfile collector extension](https://github.com/prometheus-community/node-exporter-textfile-collector-scripts) that supports [SMART monitoring](https://github.com/prometheus-community/node-exporter-textfile-collector-scripts/blob/master/smartmon.py) among other attributes.

Prometheus is also relatively easy to template out with tools like *Ansible* and *Terraform* , which can both leverage [the automation integrations]() we provide for those tools, and can also be leveraged in many deployment models outside of the traditional *Nix environments, for example [vSphere]() and [Windows](https://github.com/prometheus-community/windows_exporter)

#### DataDog / Opsview / New Relic / SpiceWorks

Similar to their open-source counterparts listed above, Equinix Metal instance will "behave as just another server", with all of the advantages of automation and templating you may be able to leverage within these tool's ecosystems.

#### OEM / Dell OpenManage / SuperMicro "IPMICFG"

The Equinix Metal configuration lineup comes from a broad variety of chassis and component vendors. Most customers would likely find the most benefit from monitoring their servers in a "hardware vendor" agnostic way, as in any chassis will be a combination of parts regardless of OEM, and automating monitoring deployments to be capable or monitoring any present individual parts may be a more pragmatic route than trying to monitor "the specific chassis from this specific OEM".

However, in some deployment models, it may be preferred to leverage the software from a chassis OEM. This could be because an operator already has this glue, E.G "I already monitor Dell hardware via Nagios `check_dell_openmanage` in my datacenter, I want to extend that to Equinix Metal", or perhaps it's the only way to get visibility into proprietary hardware, say for a Dell BOSS card.

- Dell OpenMange (for Dell OEM'ed chassis)
	- [RedHat RHEL Officially Supported, Debian / Ubuntu Community Supported](https://linux.dell.com/repo/hardware/omsa.html)
	- [ESXi / VMWare](https://www.dell.com/support/kbdoc/en-us/000179481/how-to-install-openmanage-server-administrator-omsa-on-vmware-to-collect-logs)
	- [Windows](https://www.dell.com/support/kbdoc/en-us/000132087/support-for-dell-emc-openmanage-server-administrator-omsa)

- [SuperMicro IPMICFG](https://www.supermicro.com/en/solutions/management-software/ipmi-utilities)

- LSI / Avago / Broacom
	- While most "stock" Equinix Metal instance's do not have a disk controller capable of presenting a RAID device the `storcli` [interface can still be useful for monitoring](https://www.broadcom.com/support/knowledgebase/1211161499760/lsi-command-line-interface-cross-reference-megacli-vs-twcli-vs-s) and metrics collection.

##### Network Access to the Lifecycle Controller

In the subject space of OEM software and monitoring where there is a lot of terminology overlap, it is worth clarifying that Equinix Metal does not, and will never provide network access to the lifecycle controller (iDRAC, iLO, IPMI, etc) of an Equinix Metal instance to a customer. These are reserved for Equinix Metals sole use as well as heavily restricted for security reasons.

While customers may be able to leverage parts of OEM software to monitor a local instance, there will never be network access to the lifecycle controller itself.

##### Open19

There is currently no end operator software for our Open19 based instances. They should be monitored for their individual parts rather than the chassis.
