# Using NCB to deploy VCSA on Equinix Metal

This doc is still in scratch state, please excuse the mess.

## Create vcsaesxi-20

Why 20? Just to leave `0-19` as safe numbers for other uses within network name spaces.

### set envs
```
METAL_PROJ_ID=###YOUR_PROJECT_ID
METAL_HOSTNAME=vcsaesxi-20
METAL_MGMT_A_VLAN=3880
METAL_INTER_A_VLAN=3850
METAL_LOCAL_A_VLAN=3860
METAL_METRO=da
```

```
METAL_PROJ_ID=###YOUR_PROJECT_ID
METAL_HOSTNAME=tmpesxi-14
METAL_MGMT_A_VLAN=3880
METAL_INTER_A_VLAN=3850
METAL_LOCAL_A_VLAN=3860
METAL_METRO=da

metal device create --hostname $METAL_HOSTNAME --plan m3.large.x86 --metro $METAL_METRO --operating-system vmware_esxi_7_0 --project-id $METAL_PROJ_ID -t "metalcli,ncb" --public-ipv4-subnet-size 0

metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_MGMT_A_VLAN
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_LOCAL_A_VLAN
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_INTER_A_VLAN

HOSTNAME_ID=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id')

HOSTNAME_BOND0=$(metal -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')

HOSTNAME_PIP0=$(metal device get -i $HOSTNAME_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')

metal port vlan -i $HOSTNAME_BOND0 -a $METAL_MGMT_A_VLAN && \
sleep 10 && \
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_LOCAL_A_VLAN && \
sleep 10 && \
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_INTER_A_VLAN
```

- Now log onto ESXi WebUI and add `172.16.100.20` as IP on `mgmt_3880` portgroup on `vSwitch0` (do not create a new vSwtich).

- Remove Public IP vmk

- Reset password

#### TODO

Have the above CLI'ed with SSH + ESXi commands.

## Launch ncb-01
```
METAL_PROJ_ID=###YOUR_PROJECT_ID
METAL_HOSTNAME=ncb-01
METAL_MGMT_A_VLAN=3880
METAL_INTER_A_VLAN=3850
METAL_LOCAL_A_VLAN=3860
METAL_METRO=da
```

```
metal device create --hostname $METAL_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system alma_9 --userdata-file ~/code/github/metal_code_snippets/virtual_appliance_host/no_code_with_guardrails/cloud_inits/el9_no_code_safety_first_appliance_host.mime --project-id $METAL_PROJ_ID -t "metalcli,ncb"
```

### Set envs
```
HOSTNAME_ID=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id')

HOSTNAME_BOND0=$(metal -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')

HOSTNAME_PIP0=$(metal device get -i $HOSTNAME_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')
```

```
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_MGMT_A_VLAN && \
sleep 10 && \
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_LOCAL_A_VLAN && \
sleep 10 && \
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_INTER_A_VLAN
```


ssh adminuser@$HOSTNAME_PIP0 "mkdir -p /mnt/util/export/nfs1/isos"
ssh adminuser@$HOSTNAME_PIP0 "wget --quiet -O /mnt/util/export/nfs1/isos/vmwarevcsaall703.iso http://ipxe.dlott.casa/util/vmware/vmwarevcsaall703.iso"

metal device get -i $HOSTNAME_ID -o json | jq . | grep passw

ssh adminuser@$HOSTNAME_PIP0 "mkdir /mnt/util/export/vcsa && sudo mount -o loop,ro /mnt/util/export/nfs1/isos/vmwarevcsaall703.iso /mnt/util/export/vcsa && mkdir /tmp/.config && chmod 0700 /tmp/.config/"

ssh adminuser@$HOSTNAME_PIP0 "sudo -S dnf install -y libnsl"

```
echo '
{
    "__version": "2.13.0",
    "__comments": "Equinix GTST cli based VCSA deployment, expects ncb-01",
    "new_vcsa": {
        "esxi": {
            "hostname": "172.16.100.14",
            "username": "root",
            "password": "Equinixmetal0$",
            "deployment_network": "vm_3880",
            "datastore": "datastore1"
        },
        "appliance": {
            "__comments": [
                "You must provide the 'deployment_option' key with a value, which will affect the vCenter Server Appliance's configuration parameters, such as the vCenter Server Appliance's number of vCPUs, the memory size, the storage size, and the maximum numbers of ESXi hosts and VMs which can be managed. For a list of acceptable values, run the supported deployment sizes help, i.e. vcsa-deploy --supported-deployment-sizes"
            ],
            "thin_disk_mode": true,
            "deployment_option": "small",
            "name": "egtst-vcsa01"
        },
        "network": {
            "ip_family": "ipv4",
            "mode": "static",
            "system_name": "egtst-vcsa01.gtst.local",
            "ip": "172.16.100.239",
            "prefix": "24",
            "gateway": "172.16.100.1",
            "dns_servers": [
                "172.16.100.1"
            ]
        },
        "os": {
            "password": "Equinixmetal0$",
            "time_tools_sync": true,
            "ssh_enable": true
        },
        "sso": {
            "password": "Equinixmetal0$",
            "domain_name": "gtst.local"
        }
    },
    "ceip": {
        "description": {
            "__comments": [
                "++++VMware Customer Experience Improvement Program (CEIP)++++"
            ]
        },
        "settings": {
            "ceip_enabled": true
        }
    }
}
' | ssh adminuser@$HOSTNAME_PIP0 "tee /tmp/.config/gtst-vsca.json"
```

## Start VCSA install
You probably want to do this on a `tmux` or `screen` on ncb-01, you could run it through SSH like above, just hope the connections good.

Total install time should be ~20min
/mnt/util/export/vcsa/vcsa-cli-installer/lin64/vcsa-deploy install --precheck-only --accept-eula --acknowledge-ceip /tmp/.config/gtst-vsca.json

/mnt/util/export/vcsa/vcsa-cli-installer/lin64/vcsa-deploy install --accept-eula --acknowledge-ceip --no-ssl-certificate-verification /tmp/.config/gtst-vsca.json


It should end with a successful report:

```
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(RUNNING 55/100)    - Starting
VMware Trust Management Service...
VCSA Deployment is still running
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(RUNNING 59/100)    - Starting
VMware vSphere Client...
VCSA Deployment is still running
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(RUNNING 65/100)    - Starting
VMware ESX Agent Manager...
VCSA Deployment is still running
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(RUNNING 69/100)    - Starting
VMware vSphere Profile-Driven Storage Service...
VCSA Deployment is still running
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(RUNNING 77/100)    - Starting
VMware vSphere Authentication Proxy...
VCSA Deployment is still running
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(RUNNING 81/100)    - Starting
VMware vService Manager...
VCSA Deployment is still running
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(RUNNING 89/100)    - Starting
Workload Control Plane...
VCSA Deployment is still running
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(RUNNING 91/100)    - Starting
VMware Content Library Service...
VCSA Deployment is still running
==========VCSA Deployment Progress Report==========         Task: Install required RPMs for the appliance.(SUCCEEDED
100/100)       - Task has completed successfully.         Task: Run firstboot scripts.(SUCCEEDED 100/100) - Task has
completed successfully.
Successfully completed VCSA deployment.  VCSA Deployment Start Time: 2024-01-18T18:59:38.660Z VCSA Deployment End Time:
2024-01-18T19:10:02.029Z
 [SUCCEEDED] Successfully executed Task 'MonitorDeploymentTask: Monitoring Deployment' in TaskFlow 'gtst-vsca' at
19:10:10
Monitoring VCSA Deploy task completed
The certificate of server 'egtst-vcsa01.gtst.local' will not be verified because you have provided either the
'--no-ssl-certificate-verification' or '--no-esx-ssl-verify' command parameter, which disables verification for all
certificates. Remove this parameter from the command line if you want server certificates to be verified.
====================== [START] Start executing Task: Join active domain if necessary at 19:10:12 ======================
Domain join task not applicable, skipping task
===== [SUCCEEDED] Successfully executed Task 'Running deployment: Domain Join' in TaskFlow 'gtst-vsca' at 19:10:12 ================== [START] Start executing Task: Provide the login information about new appliance. at 19:10:14 =============    Appliance Name: egtst-vcsa01
    System Name: egtst-vcsa01.gtst.local
    System IP: 172.16.100.239
    Log in as: Administrator@gtst.local
 [SUCCEEDED] Successfully executed Task 'ApplianceLoginSummaryTask: Provide appliance login information.' in TaskFlow
'gtst-vsca' at 19:10:14
======================================================= 19:10:16 =======================================================Result and Log File Information...
WorkFlow log directory: /tmp/vcsaCliInstaller-2024-01-18-18-54-it52joyi/workflow_1705604064405
```
