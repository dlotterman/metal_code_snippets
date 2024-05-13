## Notes

- [flatcar documentation](https://www.flatcar.org/docs/latest/provisioning/config-transpiler/)
- [butane documentation](https://coreos.github.io/butane/)
- [flatcar on Metal](https://thenewstack.io/tutorial-explore-container-runtimes-with-flatcar-container-linux/)
```
podman run --interactive --rm --security-opt label=disable \
       --volume ${PWD}:/pwd --workdir /pwd quay.io/coreos/butane:release \
       --pretty --strict TARGET.bu > transpiled_config.ign
```
