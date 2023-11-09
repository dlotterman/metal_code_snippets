# Getting Started

Before beginning, it is strongly recomemended that an operator complete the [Equinix Metal Getting Started](https://metal.equinix.com/developers/docs/) guide before proceeding with anything referenced here. The getting started documentation will make sure the account is correctly setup and walk the operator through the basics of operating Metal.

### Required Accounts and Credentials and Assets:

- [Equinix Metal Read / Write Token](https://deploy.equinix.com/developers/docs/metal/accounts/api-keys/#project-api-keys)
    - Project token is fine as long as no Interconnection is needed
- [Equinix Metal Project ID](https://metal.equinix.com/developers/docs/accounts/projects/)
- A Shell where that Shell is presumed to be from an [EL](https://en.wikipedia.org/wiki/Category:Enterprise_Linux_distributions) or Ubuntu LTS based `bash`



### Environment setup:

This guide assumes a modern but *simple* execution environment. It makes use of Python's virtualenv functionality to create a isolated workspace. Any OS with a Python distrobution version of `3.8` or greater should work as expected.

Besides standard nix-like tooling, the remaining requirement is access to the public Internet for the package installation and reaching the Metal and Redhat Cloud's public APIs. There is no requirement for the environment to be able to host public facing applications, as in a NAT'ed VM or equivalent should work fine.

For the sake of being *copy + paste* useable, commands here will assume a RHEL8-clone (CentOS, Rocky or Alma) environment.

- [Install git](https://github.com/git-guides/install-git)
  - RHEL-8 clone: `sudo dnf install git -y`

- Clone this repository:
  - `git clone https://github.com/dlotterman/metal_plath`

- Install python3.11 or newer:
  - On EL9 `sudo dnf install python3.11 -y`
  - On Ubuntu 22.04: `sudo apt install -y python3.11-full`

Create the Python virtualenv
  - `python3.11 -m venv metal_plath`
	- On EL9: `python3.11 -m venv metal_plath`

- Change into the repository directory
  - `cd metal_plath`

- Source the virtualenv environment setup
  - `source bin/activate`

- Update pip
  - `pip3.11 install --upgrade pip`

- Install Python packages required
  - `pip install -r requirements.txt`

- Copy Equinix Metal Ansible Inventory File to `/dev/shm` (we are going to put a project ID credential in there)
  - `cp equinix_metal.yaml /dev/shm/metal_plath_inv.yaml`
  - `echo "  - $YOUR_PROJECT_ID_HERE" >> /dev/shm/metal_plath_inv.yaml`
    - This is confusing, but `YOUR_PROJECT_ID_HERE` needs to be your actual project UUID
