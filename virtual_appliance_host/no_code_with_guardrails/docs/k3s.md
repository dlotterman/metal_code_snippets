# k3s installation

`NCB` can install [k3s](https://k3s.io/) to itself. Simply tag the `NCB` instance with the tag `ncb_k3s` and the install will install k3s as if it were following the quick [start guide](https://docs.k3s.io/quick-start)

The only thing it modifies is moving the mangement services to a network inside a Metal VLAN, specifically VLAN `3880`. This is do for security.

`NCB` will also install `kubectl`, `clusterctl`, and `cert-manager` from recent pinned versions.


Traefik will take over port `80` for the ingress controller.
