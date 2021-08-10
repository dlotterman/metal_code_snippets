## Storage Options for *nix Centric deployments with Equinix Metal

Equinix Metal is a Bare Metal and Interconnection as a Service platform that provides unique and powerfully simple primitives for building significant and consequential compute, storage and networking infrastructure. As a platform for hosting "*nix centric" deployments, Metal aligns well with modern, thoughtful storage designs and configurations.



### No-Ops / *aaS Options

Especially for smaller workloads, users may want to reduce the amount of operational setup and lifecycle management required for a given deployment.

#### 3rd Party / Hosted Storage

At low storage or throughput / access volumes, hosted object storage can be a very pragmatic option. For log archival, data set backups, configuration storage / application chatter, these services can be remarkably cost effective given the value retuned, and can often replace the "additional slow disk" that is commonly attached to cloud provisioned instances to fill this role.

When calculating pricing, it is important remember that ingress to Equinix Metal from the public internet is free of charge.

For performance considerations, Equinix Metal tactically places itself as close to major internet meeting points as possible, more often than not plugging directly into the incumbent IX in a given geographic area. While performance of 3rd party object storage may not be as perfomant as local disk, it can be *surprisingly* performant for a majority of 2nd or 3rd tier data strategies. 

Examples:

* Wasabi - https://wasabi.com/
  * Well regarded, featureful and competitive pricing. In close network proximity to most Metal locations
  * Wasabi is available on the [Equinix Fabric](https://wasabi.com/press-releases/equinix-delivers-equinix-cloud-exchange-fabric-wasabi-technologies/), providing unique performance and pricing options to improve latency and throughput performance while reducing volume centric cost overhead.
* Seagate Lyve - https://www.seagate.com/services/cloud/storage/
  * Well regarded with compatibility with a number of strategic partners and vendors, hosted out of Equinix sites
  * Lyve is also available on the [Equinix Fabric](https://www.seagate.com/news/news-archive/seagate-unveils-lyve-cloud-built-to-store-activate-and-manage-the-massive-surge-in-data-pr-master/)
* Rsync.net https://www.rsync.net/
  * Uniquely *nix oriented data host that is an active member of the OSS cloud community
  * Includes ZFS send / receive functionality

#### Using Backend Transfer to consolidate smaller site storage to a larger one

For customers who are deploying smaller sites globally with a central or larger main site, Backend Transfer (see below) can be used as a easy enabler for shipping data from an edge or smaller site back to a central aggregation point, minimizing the operational overhead needed per smaller site.


### Self Hosted on Metal

The options for self-hosted on Metal are too many and with vastly different pro's and con's depending on the audience or the use case, so it is impossible to give them all credit. [This section will focus specifically on features or details of the Metal platform that provide value specifically to storage design](https://metal.equinix.com/developers/docs/storage/storage-options/), and would be beneficial to any commonly deployed technology such as [Ceph/Rook](https://metal.equinix.com/developers/guides/rook-ceph/), HDFS, [Minio](https://metal.equinix.com/developers/guides/minio-terraform/), [RedHat Storage](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/managing_storage_devices/index), [StorageOS](https://metal.equinix.com/developers/docs/integrations/containers/#storageos), ZFS, [Cohesity](https://www.cohesity.com/products/helios/) or other enabling technology.



* [Backend Transfer](https://metal.equinix.com/developers/docs/networking/backend-transfer/) - Inter-host and Inter-site private L3 Networking as a Service

  * Backend Transfer is a private (to a customer project) network provided as a service to each Metal instance that provides bother free of charge inter-host (two hosts in the same Metro, so app01.dallas <-> app99.dallas) as well as inter-site (app01.dallas <-> app99.sanjose) connectivity. While useful as a control plane network, it can also be an extra-ordinarily useful storage network, as the major constructs for availability and lifecycle are taken care of by the platform. Even for data egressing a metro area, the cost effectiveness of the transfer can still enable a number of network options for storage designs.

* NVMe inside of the [m3.large.x86](https://metal.equinix.com/product/servers/m3-large/)

  * The advertised `7.6TB` of NVMe in the *m3.large.x86* is actually 2x 3.8TB drives, where each drive is a high performance Micron 9XXX line device local to the chassis. [With each drive being capable of ~120k IOPs per drive](https://in.micron.com/about/blog/2019/june/using-namespaces-on-the-micron-9300-nvme-ssd-to-improve-application-performance), the `m3.large.x86` can be capable of north of ~240k IOPs per box. Having these drives a PCI lane away from the [CPU unlocks performance profiles not available in other platforms](https://www.micron.com/-/media/client/global/documents/products/technical-marketing-brief/9300_nvme_ssds_future_proof_cassandra_tech_brief.pdf), and is truly a differentiator for BYO / Self Hosted storage designs.

* NVMe and tiering inside of the [s3.xlarge.x86](https://metal.equinix.com/product/servers/s3-xlarge/)

  * The *s3.xlarge.x86* has three tiers of internal disk, SSD (intended for boot), NVMe (intended for cache) and HDD (intended for volume storage). The varying tactical options around disk layout and tiering mean the s3 can both fill a "higher performance" (Tier 1.5) function as well as archival (tier 3) functions. *nix in particular has a number of paths for creating resilient but performant disk tiering designs relevant to the *s3.xlarge.x86* instance type.
    * [ZFS Tiering](http://www.c0t0d0s0.org/2021-04-02/tiering-and-zfs.markdown)
    * [dm-cache](https://www.kernel.org/doc/Documentation/device-mapper/cache.txt)
    * [Ceph Crush Maps](https://docs.ceph.com/en/latest/rados/operations/crush-map/)
      * [Ceph Client Cache Tiering](https://docs.ceph.com/en/latest/rados/operations/cache-tiering/)
    * [HDFS Tiering](https://tech.ebayinc.com/engineering/hdfs-storage-efficiency-using-tiered-storage/)
    * [Minio Tiering](https://min.io/product/automated-data-tiering-lifecycle-management)
    * [Elasticsearch Tiering](https://www.elastic.co/guide/en/elasticsearch/reference/current/data-tiers.html)
    * [Cockroachdb Tiering](https://www.cockroachlabs.com/docs/stable/configure-replication-zones.html#stricter-replication-for-a-specific-table)
    * [MySQL](https://dev.mysql.com/doc/refman/5.7/en/optimizing-innodb-diskio.html) & [Postgres](http://cidrdb.org/cidr2020/papers/p16-haas-cidr20.pdf) & [MongoDB](https://www.mongodb.com/blog/post/tiered-storage-models-in-mongodb-optimizing)

* [RAID](https://metal.equinix.com/developers/docs/storage/storage-options/#customizing-your-disk-configurations)

  * Available as a feature in our platform for reserved instances only. Please consult a sales team for additional information
  * To be explicit and declarative, Equinix Metal instances launched with defaults have **NO** disk parity or protection enabled.


* Cohesity - https://metal.equinix.com/solutions/cohesity/

  * Cohesity has partnered with Equinix Metal to provide a unique performant, resilient and supported storage and services platform inside of a customer's Equinix Metal environment. 
  * This pre-certified solution takes advantage of all of the advantages detailed her and provides them in an easier to consume, fully supported and certified platform.

* [Layer-2 + Customer Owned Network](https://metal.equinix.com/developers/docs/layer2-networking/)

  * Storage is functionally useless without a supporting network. For storage designs that require specific constraints (floating VIPs, BYO-Subnets, BYO-Overlay etc), our Layer-2 functionality gives customers their own entirely dedicated Layer-2 domains (presented as 802.1q VLANs).
    * This also gives us a point of control for [storage traffic shaping](https://octetz.com/docs/2020/2020-09-16-tc/) on multi-tenant networks
    * This allows us to follow most "standard" or "traditional" design choices with storage and availability, for example enabling the traditional "Pacemaker / Keepalived" HA solutions. 

* [Metal Gateways](https://metal.equinix.com/developers/docs/networking/metal-gateway/)

  * For storage designs that need inter-network, and in particular public internet facing endpoints, Metal Gateways can add needed operational flexibility.

* The [Equinix Metal API](https://metal.equinix.com/developers/api/) and [Integrations](https://metal.equinix.com/developers/docs/integrations/)

  The Equinix Metal API and associated integrations enable Metal instances and configuration to be managed and lifecycled as "Infrastructure as Code", which also enables "Storage as Code" workflows. When designing distributed or robust storage architectures,  tools like ansible, terraform and cloud-init can be used to have nodes auto-join clusters, pull seed data from object stores and configure clients. 

* Hosting a Virtual Appliance


  * Equinix Metal is a great host for Virtual Appliances, which can be especially useful when a proprietary storage technology is required or a concept needs to be quickly mocked out. 

    * [Virtual Appliance Host as Code](https://github.com/dlotterman/metal_code_snippets/blob/main/virtual_appliance_host/no_code_with_guardrails/README.md)

### SAN-as-a-Service

Equinix Metal has partnered with a handful of strategic partners such as [Pure](https://metal.equinix.com/solutions/pure-storage/) to provide SAN-as-a-Service to customers with sufficient requirements to justify the implementation (generally around 50TB or higher). Please contact an Equinix Metal sales team for more information regarding this storage path. 

[Hints of what this looks like can be seen here](https://support.purestorage.com/Solutions/VMware_Platform_Guide/User_Guides_for_VMware_Solutions/Pure_Storage_on_Equinix_Metal).



### Inter-connection



[Via Equinix Inter-connection](https://metal.equinix.com/developers/docs/equinix-interconnect/introduction/), Metal can access IPv4 or IPv6 enabled storage resources colocated or hosted in another environment. For example via physical x-conn from a customers colocation footprint in the same facility, customers can achieve sub millisecond RTT for storage based networking.



### Example data flows



#### High activity flat file data set

Many high performance data intensive workloads now base their data set on extremely simple flat file layouts. Leveldb, Lucene, Kyoto Cabinet, RocksDB all leverage the same paradigm of simple flat files with process level compaction or lifecycling for intelligence. While simple from an intial setup and process bootstrapping perspective, these datasets can be unwiedly at scale. 

Nodes that participate in these data sets generally have the same operational lifecycle:

* Provision
* Seed
* Catchup
* Participate
* Backup
* Decommission intentionally or unintentionally 

In the scenario where we have a number of *m3.large.x86*'s hosting flat file datasets, each data set can be broken up across [NVMe namespaces](https://www.snia.org/sites/default/files/SDCEMEA/2020/4%20-%20Or%20Lapid%20Micron%20-%20Understanding%20NVMe%20namespaces%20-%20Final.pdf) for control and easy [sharding / scaling](https://en.wikipedia.org/wiki/Shard_(database_architecture)). A great ecosystem of tooling exists to back up large flat file datasets to *S3-like* endpoints, which we can leverage here. The backup target could be an *s3.xlarge.x86* running Minio with tiering, where that *s3.xlarge.x86* can be configured to backup it's own dataset to another *s3.xlarge.x86* in another site leveraging *Backend Transfer*.

When a new *m3.large.x86* joins the cluster or replaces a previous node, it can pull the shard dataset down from the local *s3.xlarge.x86* and become a participant in the cluster. It can seed this shard dataset at the full 10G or 20G available to the *s3.xlarge.x86*, so node entry into the cluster can be both performant and cost effective.  In the event that an entire site is lost, the *m3.large.x86* cluster can be brought up in the same site as the backup *s3.xlarge.x86*. For datasets that are sensitive to exact dataset position relative to a data timeline or history, we can configure our message queue or data pipeline (Kafka, NSQ, Fluentd, Pulsar, RabbitMQ ) that fronts the data set to also send a copy of the relevant data stream to the redundant site via Backend Transfer for replay.

With this perspective on a design, we can introduce pragmatic flexibility, cost effectiveness, performance and resilience with relatively minimal overhead into an Equinix Metal deployment. 
