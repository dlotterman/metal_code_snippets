# Via Equinix Metal Console (UI)

- [Follow along video here](https://equinixinc-my.sharepoint.com/:v:/g/personal/dlotterman_equinix_com/EWDXuOfNxCNDoZGRYgbz8JEBnQkky7fWD1Th4Eg5O41WLA?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0RpcmVjdCJ9fQ&e=aYpY6H)

1. The hostname chosen for the instance **MUST** end in a `-` delimited number. As in `-1`, `-01` and `-124` are all valid. The number must be unique to any other `ncb` instance in the [project](https://deploy.equinix.com/developers/docs/metal/accounts/projects/) / [metro](https://deploy.equinix.com/developers/docs/metal/locations/metros/).
2. Simply `Ctrl + C` & `Ctrl + V` this [cloud-init](cloud_inits/el9_no_code_safety_first_appliance_host.yaml) into the [Userdata](https://deploy.equinix.com/developers/docs/metal/server-metadata/user-data/) field when provisioning an [Equinix Metal instance](https://deploy.equinix.com/product/bare-metal/servers/)
    - It may be easiest to click on the "raw view" version of the cloud-init file to cleanly copy the text.
3. [Create and add](https://deploy.equinix.com/developers/docs/metal/layer2-networking/vlans/) the [relevant VLAN](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/em_sa_network_schema.md)'s needed to the `ncb` instance in [Hybrid Bonded](https://deploy.equinix.com/developers/docs/metal/layer2-networking/hybrid-bonded-mode/) mode
    - The configuration will be done for you on the instance side, so long as you follow the schema

# Via Equinix Metal CLI

This assumes that the operator has a working shell and has setup the [Equinix Metal CLI](https://deploy.equinix.com/developers/docs/metal/libraries/cli/)

- Clone this repository
```
git clone https://github.com/dlotterman/metal_code_snippets
```
  - Optionally, just `wget` or `curl` the cloud-init file:
    ```
    wget https://raw.githubusercontent.com/dlotterman/metal_code_snippets/main/virtual_appliance_host/no_code_with_guardrails/cloud_inits/el9_no_code_safety_first_appliance_host.mime
    ```
    ```
    curl -s -o el9_no_code_safety_first_appliance_host.mime https://raw.githubusercontent.com/dlotterman/metal_code_snippets/main/virtual_appliance_host/no_code_with_guardrails/cloud_inits/el9_no_code_safety_first_appliance_host.mime
    ```

- Setup the shell environment
```
METAL_METRO=sv
METAL_HOSTNAME="ncb-sv-02"
METAL_PLAN="c3.medium.x86"
```

- Provision the instance (using *mime* format cloud-init file, adjust path if necessary)
```
metal device create --hostname $METAL_HOSTNAME --plan $METAL_PLAN --metro $METAL_METRO --operating-system alma_9 --userdata-file metal_code_snippets/virtual_appliance_host/no_code_with_guardrails/cloud_inits/el9_no_code_safety_first_appliance_host.mime -t "metalcli,ncb"
```

- Provision vlans and attach, do so only for needed vlans
```
METAL_METRO=sv
METAL_VLAN=3880
METAL_HOSTNAME="ncb-sv-02"
```
```
metal virtual-network create -m $METAL_METRO --vxlan $METAL_VLAN
```
```
VLAN_ID=$(metal virtual-network get -o json | jq --argjson METAL_VLAN "$METAL_VLAN" -r '.virtual_networks[] | select (.vxlan==$METAL_VLAN) | .id')
```
```
HOSTNAME_ID=$(metal device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id') && \
HOSTNAME_BOND0=$(metal device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')
```
```
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_VLAN
```

- Wait for instance to finish provisioning (probably 3 minutes or so)
