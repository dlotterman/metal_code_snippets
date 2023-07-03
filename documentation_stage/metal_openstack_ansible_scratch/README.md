### This folder is for documentation sharing purposes only. It should not be considered prescriptive or valid.

[Github](https://github.com/equinix/ansible-collection-metal)
[Github YAML example](https://github.com/equinix/ansible-collection-metal/blob/main/docs/equinix.metal.device_inventory.rst)
[Ansible Inventory Plugin / Collection documentation](https://docs.ansible.com/ansible/latest/plugins/inventory.html)


```
time ansible-playbook -u adminuser -i equinix_metal.yaml 00_metal_hosts.yaml
ansible -i equinix_metal.yaml tag_os -u adminuser -m ping
```
