## An operators short guide to working with Cloud-Init and Equinix Metal.

### Cloud-init Overview
[Cloud-init](https://cloud-init.io/) is a wonderful package and ecosystem with support for a variety of Operating Systems (Linux, [Windows](https://cloudbase.it/cloudbase-init/) and others), that among other uses, allows customers to control and manage early stages of a cloud instances provisoning, allowing instances to dynamically configure themselves before reaching their final "provisioned" state.

When we think about most of the concepts we associate with "cloud instances" ( auto-scaling, infrastructure-as-code etc), chances are most solution designs around those concepts will involve Cloud-init. It's one of the `easiest places to begin the cloud automation journey`(https://cloudinit.readthedocs.io/en/latest/topics/examples.html).

Cloud-init with Equinix Metal is a great pairing. Much of the value of a Metal instance is that it is a "lower level of abstraction" than other related compute services, where that lower level of abstraction enables workloads and designs that would be cumbersome or impossible on other platforms. When running at those lower levels of abstraction, the ease of bootstrapping an environment of configuration becomes even more critical, as there are less "guard rails" and "things provided as a service". Cloud-init offers a fantastic vector for operators to assume control of those Metal paradigms early on in an instance's lifecycle, making downstream configuration "once the instance is provisioned" easier and more straightforward.

Common examples
* Configure disks before loading needed data
* Configure NIC's with SR-IOV or Virtualization Networking at startup
* Configure software repositories before installing software
* Joining clusters or gathering config data before starting application services

Cloud-init is often referred to in combination with a couple of other services, in order to minimize confusion, I will also speak to those other services briefly, specically in conjunction with Equinix Metal.

#### Metadata API:

The Equinix Metal [Metadata API](https://metal.equinix.com/developers/docs/server-metadata/metadata/) is an HTTP endpoint that allows for unprivileged (no key / token necessary) queries from inside the customer's own Metal network, is dynamically responsive to what instance is making a query against it, and can respond with cloud Metadata specific to that instance.

If an instance needs to know what SSH-keys have been assigned to it, it can ask it's Metadata API. If an instance wants to know what it's configured tags are, it can ask the Metadata API. If the instance wants to know what it's IP address allocation is, it can ask the Metadata API.

#### user_data:

When a customer launches an Equinix Metal instance through the WebUI / Console, there is a field where customers can input their own strings of text, where those strings of text are likely some kind of configuration code. That data that gets stored by the platform for the lifecycle of the instance (until it's deleted), and is exposed through the Metadata API. That data is referred to as [user_data](https://metal.equinix.com/developers/docs/server-metadata/user-data/).


In the same way that an instance can query the Metadata API for it's IP addresses and SSH-keys, it can query the Metadata API to ask for it's `user_data`, in which case the Metadata API will respond back with the strings of text that the operator configured at provision time.


Example of launching an instate with user_data:

![user_data field](https://s3.us-east-1.wasabisys.com/metalstaticassets/user_data_doc.JPG)

An example of accessing that `user_data` through the Metadata API:

```
# curl https://metadata.platformequinix.com/2009-04-04/user-data
#cloud-config
#THIS IS INSTANCE HAS USER_DATA!
```

Cloud-init: [Cloud-init](https://cloudinit.readthedocs.io/en/latest/index.html) actually has very little to do with Equinix Metal. Cloud-init is a well adopted, well supported Open Source package that lives inside the Operating System of a cloud (Metal) instance. When a Operating System with Cloud-init baked into it's image boots, Cloud-init will reach out to the Metadata API, will load the instances user_data from the API, and if it finds a `#cloud-config` Cloud-init config inside of the Userdata it retrieved from Metadata API, and cloud-init will then configure the instance according to the instructions in that `#cloud-config`.

A write up documenting an example Cloud-init `#cloud-config` designed to be used with Equinix Metal can be [found here](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/cloud_init/example_cloud_init_walkthrough.md)
