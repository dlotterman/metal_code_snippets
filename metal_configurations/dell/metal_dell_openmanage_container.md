# Modifying the chassis configuration of a Dell based Equinix Metal instance

Everything in this document is strictly **UN-SUPPORTED** and should be considered dangerous. It is for reference only.

All the hard work on this was done by others:

Reference links
- [Original Work](https://github.com/kamermans/docker-openmanage/tree/master)
    - [Additional work](https://github.com/wolviex/docker-openmanage/tree/master)
        - Dockerhub and [Dockerhub](https://hub.docker.com/r/wolviex/docker-openmanage)
            - [DSET Dockerhub](https://hub.docker.com/r/kamermans/dell-dset/)

## Reboot instance into Rescue mode

- [Rescue mode documentation](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/rescue-mode/)

- Metal CLI:
```
curl -s -X POST \
--header 'X-Auth-Token: $YOURTOKEN' \
--header 'Content-Type: application/json' 'https://api.equinix.com/metal/v1/devices/$UUID/actions'  \
--data '{"type": "rescue"}'
```

## Setup Alpine for Docker

[REFERENCE DOCUMENTATION HERE](https://wiki.alpinelinux.org/wiki/Docker)
```
apk add docker
rc-update add docker default
service docker start
```


## Run commands

- `docker run --rm -ti --privileged --net=host -v /dev:/dev  kamermans/docker-openmanage "omreport chassis biossetup"`
- `docker run --rm -ti --privileged --net=host -v /dev:/dev  kamermans/docker-openmanage "omconfig chassis biossetup attribute=ProcCcds setting=All"`
- `docker run --rm -ti --privileged --net=host -v /dev:/dev  kamermans/docker-openmanage dsu`
