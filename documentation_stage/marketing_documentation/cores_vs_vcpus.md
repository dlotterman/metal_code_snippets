Before any hypervisor or virtualazation, any semi-modern server grade CPU will have a concept of multiple threads per physical core, with multiple cores per socket. This is often short-handed to Intel's original name for this with x86 called [Hyperthreading](https://en.wikipedia.org/wiki/Hyper-threading), though the more correct term is [SMT](https://en.wikipedia.org/wiki/Simultaneous_multithreading).

Intel's default of two threads to a core has stuck ever since in x86 world. This 2x default is not true in other architectures, such as Arm, which Metal also provides [on-demand](https://deploy.equinix.com/product/servers/c3-large-arm64/).

So when an OS is installed to a server with "Hyperthreading", if that server has a single socket CPU, where that CPU has 8x physical cores, the OS will see 16x processors available.

This is what happens with Metal. The customer's OS lives on-top of the real CPU, and gets access to the full core / thread count of the CPU. When Metal details it's instance configurations, and says the [c3.medium.x86](https://deploy.equinix.com/product/servers/c3-medium/) has 24 cores / CPUs, we mean real cores, the customer's OS will see 48x CPUs.

With large parts of the EC2 instance catalogue as an example (and most providers of virtual infrastructure), when they reference a CPU / Core count, what they really mean is thread. They use virtualization to cut up the thread count into CPUs before the customer's OS. So when AWS details a configuration and says "4 vCPUs on the [c5.xlarge](https://instances.vantage.sh/aws/ec2/c5.xlarge)", the customers OS will see 4vCPUs.

To be explict, many vendors, including the Hyperscalers, have toggles and options around this subject, this snippet is not authoratative on other products.

This is one of the reasons we believe Metal to be so cost advantageous for on-demand compute, but it often gets lost in Apples to Oranges conversation (edited) 

Hyperscaler Documentation:
- [GCP](https://cloud.google.com/compute/docs/instances/set-threads-per-core)
- [AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-optimize-cpu.html)
- [Azure](https://learn.microsoft.com/en-us/azure/virtual-machines/mitigate-se#core-count)
