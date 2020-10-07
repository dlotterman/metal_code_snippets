# metal_dynamic_inventory.py

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r'''
    name: metal_dynamic_inventory
    plugin_type: inventory
    short_description: Returns Ansible inventory packet.com API
    description: Returns Ansible inventory from packet.com API
    options:
      plugin:
          description: metal_dynamic_inventory
          required: true
          choices: ['metal_dynamic_inventory']
      metal_api_token:
        description: metal.equinix.com API read or write token
        required: false
      metal_projects:
        decription: YAML list of Packet projects to include in inventory
        required: True
      metal_device_prefixs:
        description: YAML list of prefix's to match hostnames off of, "ewr" will match "ewr1-t1.small.x86-01" for example. Each prefix will include a group of the same string
        required: False
      metal_ansible_ip:
        description: Add meta for ansible_host, valid options are "public_ipv4, public_ipv6, private_ipv4"
        required: False
'''



from ansible.plugins.inventory import BaseInventoryPlugin, Constructable, Cacheable
from ansible.errors import AnsibleError, AnsibleParserError
try:
    import packet
except:
    raise AnsibleError('packet-python package must be installed')
import os

class InventoryModule(BaseInventoryPlugin):
    NAME = 'metal_dynamic_inventory'
    

# Update the verify_file method

    def verify_file(self, path):
        valid = False
        if super(InventoryModule, self).verify_file(path):
            if path.endswith(('metal_dynamic_inventory.yaml',
                              'metal_dynamic_inventory.yml')):
                valid = True
        return valid
        
    def _add_packet_device(self, packet_device, prefix):
        self.inventory.add_group(packet_device['facility']['code'])
        device_plan = packet_device['plan']['name'].replace('.', '_')
        self.inventory.add_group(device_plan)
        self.inventory.add_group(prefix)
        self.inventory.add_group('all_packet_devices')
        
        self.inventory.add_host(host=packet_device['hostname'], group=packet_device['facility']['code'])
        self.inventory.add_host(host=packet_device['hostname'], group=device_plan)
        self.inventory.add_host(host=packet_device['hostname'], group=prefix)
        self.inventory.add_host(host=packet_device['hostname'], group='all')
        
        if self.packet_ansible_ip:            
            for ip_address_stanza in packet_device['ip_addresses']:                
                #Clean this up... goodness
                if self.packet_ansible_ip == 'public_ipv4':
                    if ip_address_stanza['address_family'] == 4:
                        if ip_address_stanza['public'] == True:
                            if ip_address_stanza['management'] == True:
                                self.inventory.set_variable(packet_device['hostname'], 'ansible_host', ip_address_stanza['address'])
                                break
                if self.packet_ansible_ip == 'private_ipv4':
                    if ip_address_stanza['address_family'] == 4:
                        if ip_address_stanza['public'] == False:
                            if ip_address_stanza['management'] == True:
                                self.inventory.set_variable(packet_device['hostname'], 'ansible_host', ip_address_stanza['address'])
                                break
                if self.packet_ansible_ip == 'public_ipv6':
                    if ip_address_stanza['address_family'] == 6:
                        if ip_address_stanza['public'] == True:
                            if ip_address_stanza['management'] == True:
                                self.inventory.set_variable(packet_device['hostname'], 'ansible_host', ip_address_stanza['address'])
                                break

    def _populate(self):
        '''Return the hosts and groups'''
        manager = packet.Manager(auth_token=self.metal_api_token)
        for project in self.packet_projects:
            project_devices = manager.list_devices(project)
            for device in project_devices:
                if self.packet_device_prefixs:
                    for prefix in self.packet_device_prefixs:
                        if device['hostname'].startswith(prefix):
                            self._add_packet_device(device, prefix)
        
    def parse(self, inventory, loader, path, cache):
        '''Return dynamic inventory from source '''
        super(InventoryModule, self).parse(inventory, loader, path, cache)
        # Read the inventory YAML file
        self._read_config_data(path)
        try:
            self.plugin = self.get_option('plugin')
            if self.get_option('metal_api_token'):
               self.packet_api_token = self.get_option('metal_api_token')
            elif os.getenv('PACKET_API_TOKEN'):
                self.metal_api_token = os.getenv('PACKET_API_TOKEN')
            else:
                raise AnsibleError('metal_api_token must be in metal_dynamic_inventory YAML file or in ENV viable PACKET_API_TOKEN')
            self.packet_projects = self.get_option('metal_projects')
            self.packet_device_prefixs = self.get_option('metal_device_prefixs')
            self.packet_ansible_ip = self.get_option('metal_ansible_ip')
        except Exception as e:
            raise AnsibleParserError(
               'All correct options required: {}'.format(e))
        # Call our internal helper to populate the dynamic inventory
        self._populate()
