### CPR Notes ###

In any CPR json file in this repo, the incrementing alphabetical characters for each drive may be different from chassis to chassis. That is to say, one chassis `/dev/sdb` which maps to a `480GB` drive on one chassis, may map to a `240GB` drive on a different chassis of the same layout.

#### Debugging #####


When an error with CPR occurs during a host's provisioning cycle, the host will be left in it's installation environment (Commonly referenced as 'Alpine', named after the Linux distrobution from which it's based. 

A operator can log into Alping via the [OOB/SOS Console](https://metal.equinix.com/developers/docs/resilience-recovery/serial-over-ssh/), and leverage common Linux tools to build a map of names of the disks there. 

The [CPR Documentation](https://metal.equinix.com/developers/docs/servers/custom-partitioning-raid/) also references Alpine in being able to leverage the [Rescue Mode](https://metal.equinix.com/developers/docs/resilience-recovery/rescue-mode/) function of the platform as well. 