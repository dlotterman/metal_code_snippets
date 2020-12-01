### Getting into the BIOS of a SuperMicro based Metal instance ###

1. Download the [IPMICFG](https://www.supermicro.com/SwDownload/SwSelect_Free.aspx?cat=IPMI) utility from SuperMicro to the host and unzip it to the desired folder structure

2. Look at the options available for boot priority, looking for the BIOS option
```
# ./IPMICFG-Linux.x86_64 -soft -help
Command: -soft
Command(s):
 -soft <index>              Initiates a soft-shutdown for OS and forces system
                             to boot from the selected device.
For reboot device index :
0: Default boot device
1: PXE             2: Hard-drive
3: CD/DVD          4: Bios
5: USB KEY         6: USB HDD
7: USB Floppy      8: USB CD/DVD
9: UEFI Hard-drive 10:UEFI CD/DVD
11:UEFI USB KEY    12:UEFI USB HDD
13:UEFI USB CD/DVD 14:UEFI PXE
```

3. Prepare for reboot by opening a [SOS / OOB console](https://metal.equinix.com/developers/docs/resilience-recovery/serial-over-ssh/) to the Metal instance
    * Personal suggestion, increase the size of SSH / PUTTY / etc window to wider / taller then the traditional 80 columns, screenshot in this write is taken at 100 x 40 for example. This will make rendering the BIOS menus significantly easier on the 20 layers of software abstraction involved.


4. Through the IPMICFG utility, reboot the instance into the chassis BIOS
    * ```./IPMICFG-Linux.x86_64 -soft 4```


5. Catch the BIOS keyprompt, it will be after the initial memory and HBA boot screen flashes, and can be caught with the <TAB> key


6. Interact with the BIOS and make needed changes.

![console bios](https://s3.wasabisys.com/metalstaticassets/consolebios.PNG)
