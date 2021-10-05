# Metal Smokeping Instance

Copy + Paste Smokeping Instance / Appliance for Equinix Metal. 

## What it is
This script, in conjunction with the associated [cloud-init](../boiler_plate_cloud_inits/smokeping_ubuntu_2004.yaml) file, will turn a Metal instance provisioned with Ubuntu 20.04 into a self-configuring smokeping instance. This is intended to be used for troubleshooting or gathering an understanding of the latency characteristics of various network endpoints from the perspective of the launched instance, ideally with "no-code" or "no-ops" besides the copying and pasting of the cloud-init text into the user_data field of the Equinix Metal instance as it is launched.

The cloud-init file will take care of various security and operations tasks, and then it will download this script and execute it to install and configure the smokeping instance.

Currently, the smokeping instance is configured to monitor:
- The host's [public gateway on the Metal Layer-3 network](https://metal.equinix.com/developers/docs/networking/ip-addresses/), gathered from the instance's metadata
- The host's private gateway on the Metal Layer-3 network
- An endpoint for every Metal region, gathered from the [Equinix Metal Looking Glass](https://metal.equinix.com/developers/looking-glass/) tool
- An endpoint for each AWS region
- An HTTP endpoint for each GCP region
  - Please note, this is a HTTP request for latency measurement, NOT ICMP ping. It is not valid to measure this against the latency of ICMP endpoints, but can be useful to compare one GCP region to another.
- Various known popular public endpoints such as DNS hosts

NGINX is configured to host the smokeping instance as the default HTTP host, so just taking the public IP into a browser should be all thats needed to reach the smokeping read-only WebUI.

### MTRs and Netstat
For Metal Routers, AWS Endpoints and Random Endpoints, a small script will be created and placed into `/etc/cron.hourly/` which will run a `mtr` report against that endpoint, where the output of that meter is placed in a directory that is exposed through nginx `/mtrs/`, simply going to the Metal instance's public ip with `/mtrs/` will provide a directory listing of the output files, named by endpoint by hour. There will also be a `.netstat` file which will contain the output of a `netstat -a` for debugging.

### Modifying / Adding to the config

The script will only run once, as part of the cloud-init execution. It can be re-run if needed, but it will not clear out the `/var/lib/smokeping/` dir which may cause stale configs if re-run without being cleaned.

To add to the targets being monitored, simply SSH in as `adminuser`, and add to the Targets configuration file in ` /etc/smokeping/config.d/Targets`


## Maintenance and Support

### Maintenance

[![unstable](http://badges.github.io/stability-badges/dist/unstable.svg)](http://github.com/badges/stability-badges)

This code / project is intended for non-production operation use. It is intended to be a safe and sane but quick and dirty tool or path towards providing monitoring and trending data of network latency and health, it is not intended to be integrated into any production environment. 

The expectation of the code / project however is that it should function to serve it's purpose, and is currently maintained to do so. 

### Support

This code / project should be considered self-supported, and is not supported directly by any party besides the operator. For customers of Equinix Metal who would like assistance with a deployment, please contact your Equinx Metal Sales team.


## License

[Apache 2.0](./LICENSE)
