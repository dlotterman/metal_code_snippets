For a hint on how to turn a .yaml formatted file into one that will be accepted by the Equinix Metal API and or the Metal CLI:

[Look here, at the examples to combine files, just only combine one file](https://cloudinit.readthedocs.io/en/latest/explanation/format.html)


The content at that URL is also stashed here in case that URL goes stale.

###Helper subcommand to generate MIME messages
The cloud-init make-mime subcommand can also generate MIME multi-part files.

The make-mime subcommand takes pairs of (filename, “text/” mime subtype) separated by a colon (e.g., config.yaml:cloud-config) and emits a MIME multipart message to stdout.
####Examples
Create user data containing both a cloud-config (config.yaml) and a shell script (script.sh)
```
cloud-init devel make-mime -a config.yaml:cloud-config -a script.sh:x-shellscript > userdata
```
