### Elastic Virtual Vircuit Keepalived Disco

This folder is a document dump of a Proof of Concept to use `keepalived` as a skeleton for managing VLAN <-> VC mappings as a result of detected availability changes.

In short, two VRRP instances watch down different paths of the same connection. In the event of a failure on the primary path, fail whole thing over to the up virtual circuit.

When *MASTER* faults, *BACKUP* will become master, orchestrate the failover, then *BACKUP* will also self-fault.

Total observed failover time, the discovery of which this was the primary purpose, is **around ~20 seconds**, the majority of that time is spent making API calls for failover:

```
ping -D -O 192.168.200.55
```
```
[1644854957.413278] 64 bytes from 192.168.200.55: icmp_seq=75 ttl=64 time=6.51 ms
[1644854958.415180] 64 bytes from 192.168.200.55: icmp_seq=76 ttl=64 time=6.53 ms
[1644854959.416919] 64 bytes from 192.168.200.55: icmp_seq=77 ttl=64 time=6.51 ms
[1644854961.421099] no answer yet for icmp_seq=78
[1644854962.444954] no answer yet for icmp_seq=79
[1644854963.468982] no answer yet for icmp_seq=80
[1644854964.492974] no answer yet for icmp_seq=81
[1644854965.517081] no answer yet for icmp_seq=82
[1644854966.541074] no answer yet for icmp_seq=83
[1644854967.565161] no answer yet for icmp_seq=84
[1644854968.588987] no answer yet for icmp_seq=85
[1644854969.612889] no answer yet for icmp_seq=86
[1644854970.637052] no answer yet for icmp_seq=87
[1644854971.661135] no answer yet for icmp_seq=88
[1644854972.684887] no answer yet for icmp_seq=89
[1644854973.709099] no answer yet for icmp_seq=90
[1644854974.733026] no answer yet for icmp_seq=91
[1644854975.757114] no answer yet for icmp_seq=92
[1644854976.781092] no answer yet for icmp_seq=93
[1644854977.805144] no answer yet for icmp_seq=94
[1644854978.829159] no answer yet for icmp_seq=95
[1644854979.853130] no answer yet for icmp_seq=96
[1644854980.876839] no answer yet for icmp_seq=97
[1644854980.883149] 64 bytes from 192.168.200.55: icmp_seq=98 ttl=64 time=6.13 ms
[1644854981.884963] 64 bytes from 192.168.200.55: icmp_seq=99 ttl=64 time=6.39 ms
[1644854982.886851] 64 bytes from 192.168.200.55: icmp_seq=100 ttl=64 time=6.45 ms
[1644854983.888793] 64 bytes from 192.168.200.55: icmp_seq=101 ttl=64 time=6.48 ms
```


#### Default State


![](https://s3.wasabisys.com/metalstaticassets/vrrpdefault.JPG)


#### Failed State

![](https://s3.wasabisys.com/metalstaticassets/vrrpfailed.JPG)

### Recover State

![](https://s3.wasabisys.com/metalstaticassets/vrrprecovery.JPG)