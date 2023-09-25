# Known Issues

## Cockpit Virtual Machine VM WebUI resize difficulty

Certain OS's now try to set a very large resolution for initial screens like kernel selec or installer options select. This can catchout the Cockpit's WebUI for a VM's console, especially when loaded in a browser on a client widnow with a non HD display resolution.

This is the horror of piping this kind of workload through really magical JS. It's fixed upstream, just waiting to be captured by the Enterprise Linux release cycle.

More details here:

- [Github Issue](https://github.com/cockpit-project/cockpit/issues/8392)


### Workaround

This is relatively easy to work around by SSH tunneling a VNC session, which `libvirt` makes easy. That documentation just [needs to be done](./todo.md).
