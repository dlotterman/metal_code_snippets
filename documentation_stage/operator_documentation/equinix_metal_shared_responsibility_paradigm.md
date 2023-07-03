#### The Equinix Metal Shared Responsibility / Management Paradigm

When Amazon launched it's AWS, and in particular is I.a.a.S EC2 platform, it established a new (then) [joint or "shared" operator / vendor management model](https://aws.amazon.com/compliance/shared-responsibility-model/) that has become the defacto standard for cloud platforms going forward.

Equinix Metal, as an "Infrastructure as a Service"-like platform, has a similar joint or shared model to the defacto cloud / AWS EC2 model, where both operator and platform must understand and cooperate for a succesful deployment. Because Equinix Metal delivers a relatively unique service, Bare Metal Servers delivered as cloud instances, there are some particulars to the management paradigm that differ from that of other platforms.

The key to this paradigm is understanding the way Equinix Metal delivers Bare Metal Servers as cloud host instances, and the implications of that delivery of Bare Metal as a service.

The instances Equinix Metal delivers as a service, are single-tenant, dedicated, datacenter-grade chassis that act entirely and completely as individual server instances. When you think of a data center rack server, that is what you get when you take delivery of an Equinix Metal instance. There is no secret FPGA, backdoor, shim, agent, hypervisor in play. Effectively, when you take delivery of an Equinix Metal instance, the Equinix Metal platform locks itself out of the Operating System environment inside of the chassis.

This means Equinix Metal has no vector for managing or observing the internals of the chassis after it has been deployed. Any oppertunity Equinix Metal has to configure any element of "inside" of the instance is closed after the instance has been "succesfully" provisioned. Any changes made after provisioning, to add users, modify SSH-keys, network configurations, installation of monitoring software, MUST be performed by the operator.

To summarize, Equinix Metal provides a robust number of options to configure an Equinix Metal instance before or during provisioning. Once an Equinix Metal is provisioned, any and all downstream management must be the responsibility of the operator.
