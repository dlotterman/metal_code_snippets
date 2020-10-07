## Launch an iperf server instance on Equinix Metal


### Configure
- Adjust `metal_dynamic_inventory.yaml` in this dir 
  - `ansible-playbook -i metal_dynamic_inventory.yaml metal_hosts.yaml`
- Accept ssh-key and validate host is reachable
  - `ansible all -i metal_dynamic_inventory.yaml --playbook-dir ./ -u root -m ping`
- Adjust `common.yaml` vars to include public IP in "whitelist_ips"
  - `ansible-playbook -i metal_dynamic_inventory.yaml -u root common.yaml`
  - `ansible-playbook -i metal_dynamic_inventory.yaml -u root iperf.yaml`

