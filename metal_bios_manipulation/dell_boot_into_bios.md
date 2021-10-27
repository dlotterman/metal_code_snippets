### Getting into the BIOS of a Dell based Metal Instance ###

* [Dell OpenManage 9.5 Documentation](https://www.dell.com/support/home/en-us/product-support/product/openmanage-server-administrator-v9.5/docs)

1. Follow the [OpenManage installation steps](http://linux.dell.com/repo/community/openmanage/) to install OpenManage and get the services running for your distrobution of choice. 
    * Example one-liner for apt source file creation for OpenMange `9.5.0` with Ubuntu 20.04 / `focal` release: `sudo echo 'deb http://linux.dell.com/repo/community/openmanage/950/focal focal main' | sudo tee -a /etc/apt/sources.list.d/linux.dell.com.sources.list`
    * It is strongly suggested to install the `srvadmin-all` OpenManage metapackage
    * Note there is a missed dependency on `libxslt.so.1` for Ubuntu and Debian based distros, this can be installed via the package `libxslt1-dev`

2. Start OpenManage: `/opt/dell/srvadmin/sbin/srvadmin-services.sh start`

3. Look at / sanity check current BIOS settings via: ```/opt/dell/srvadmin/sbin/omreport chassis biossetup```

4. Instruct the BIOS to reboot into a device list after the next reboot cycle: ```/opt/dell/srvadmin/sbin/omconfig chassis biossetup attribute=OneTimeBootMode setting=OneTimeUefiBootSeq```

5. Prepare for reboot by opening a [SOS Console](https://metal.equinix.com/developers/docs/resilience-recovery/serial-over-ssh/) to the Metal instance
    * Personal suggestion, increase the size of your SSH / PUTTY / Terminal window to wider / taller then the traditional 80 columns, the screenshot in this write is taken at 100 x 40 for example. This will make rendering the BIOS menus significantly easier on the ~20 layers of software abstraction involved.


6. Reboot the host: ```reboot```

7. The host will go through two reboot loops, on the second loop, after loading the lifecycle chain, you will see the following console prompt, after a prompt providing a legend for keystroke translation between virtual -> physical keystrokes. 
    * For windows based keyboards, the `Esc` + `2` keys in conjuction should register through the SSH session and console emulator to proceed into the BIOS

```Initializing PCIe, USB, and Video... Done
PowerEdge R6415
BIOS Version: 1.7.6
Console Redirection Enabled Requested by iDRAC

F2       = System Setup
F10      = Lifecycle Controller (Config
       iDRAC, Update FW, Install OS)
F11      = Boot Manager
F12      = PXE Boot
iDRAC IP:  10.250.34.27
Initializing Firmware Interfaces...
Entering System Setup
```

8. Make any needed adjustments in the BIOS, save changes and reboot.

![BIOS](https://s3.wasabisys.com/metalstaticassets/dell_bios.PNG)
