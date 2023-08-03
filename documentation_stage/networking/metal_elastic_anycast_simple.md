## Using Equinix Metal Global Anycast IP ElasticIP addresses

Equinix Metal has a relatively unique feature in being able to offer what is essentially global anycast as a service attached to it's Bare Metal compute.

Using the Global Anycast ElasticIP feature, customers can reserve a slice of a globally anycasted network, and then choose where to backhaul that traffic to, where the Metal network will take care of the the customers chosen Metal compute.

Clients trying to connect to a Global Anycast IP will connect to the closest Metal POP, so a client in Athens would likely connect to the Metal POP in Frankfurt example. If the closest location where that Metal customer had a location was Amsterdam, the customer's traffic will be hauled Metal's own network from FR to AM, providing "best as possible" global connectivity paths for a single IP.


### Provision ElasticIP hosts

Via the Portal or API, two groups of 2x instances, ideally where the groups are seperated by a large geographic (ideally oceanic) distance. Each group will have a Host and Client to validate the expirament.

Notice how while the Host and Client are in the same Geographic term "US / Europe", they are in different Metro's within those Geo's, so in the US we will use DA for the Host and SV for the client.

The clients do not have to be Metal instances, we are simply using those for convenience. If you have access to geographically diverse clients, you can use those instead.

For the sake of this walkthrough, we will use:

**US Group***
- [ ]
```
metal device create --hostname elastichost-da01 --plan m3.small.x86 --metro da --operating-system rocky_9 --project-id $YOURID
```
- [ ]
```
metal device create --hostname elasticclient-sv01 --plan m3.small.x86 --metro sv --operating-system rocky_9 --project-id $YOURID
```

**European Group***
- [ ]
```
metal device create --hostname elastichost-am01 --plan m3.small.x86 --metro am --operating-system rocky_9 --project-id $YOURID
```
- [ ]
```
metal device create --hostname elasticclient-fr01 --plan m3.small.x86 --metro fr --operating-system rocky_9 --project-id $YOURID
```

#### Reserve Global Anycast ElasticIP address

[Follow the documentation here to reserve a Global Anycast ElasticIP](https://deploy.equinix.com/developers/docs/metal/networking/global-anycast-ips/)

#### Announce the Anycast ElasticIP to the Metal network via BGP from Hosts

For the guide in this [Github Repo](https://github.com/enkelprifti98/Equinix-Metal-BGP) (from a Metal Solutions Architect) about quickly instantiating Bird as a BGP speaker on the Metal instance

#### Use Podman to quickly provide a test and connect to it from a client:

You can see at the bottom of the container logs, that clients connect to each instance depending on the geograhy of the client:

- SV -> DA
```
[adminuser@elastichost-da01 ~]$ sudo podman  run --name docker-nginx -p 8080:80 docker.io/nginx
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2023/08/03 16:28:20 [notice] 1#1: using the "epoll" event method
2023/08/03 16:28:20 [notice] 1#1: nginx/1.25.1
2023/08/03 16:28:20 [notice] 1#1: built by gcc 12.2.0 (Debian 12.2.0-14)
2023/08/03 16:28:20 [notice] 1#1: OS: Linux 5.14.0-284.11.1.el9_2.x86_64
2023/08/03 16:28:20 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2023/08/03 16:28:20 [notice] 1#1: start worker processes
2023/08/03 16:28:20 [notice] 1#1: start worker process 24
2023/08/03 16:28:20 [notice] 1#1: start worker process 25
2023/08/03 16:28:20 [notice] 1#1: start worker process 26
2023/08/03 16:28:20 [notice] 1#1: start worker process 27
2023/08/03 16:28:20 [notice] 1#1: start worker process 28
2023/08/03 16:28:20 [notice] 1#1: start worker process 29
2023/08/03 16:28:20 [notice] 1#1: start worker process 30
2023/08/03 16:28:20 [notice] 1#1: start worker process 31
2023/08/03 16:28:20 [notice] 1#1: start worker process 32
2023/08/03 16:28:20 [notice] 1#1: start worker process 33
2023/08/03 16:28:20 [notice] 1#1: start worker process 34
2023/08/03 16:28:20 [notice] 1#1: start worker process 35
2023/08/03 16:28:20 [notice] 1#1: start worker process 36
2023/08/03 16:28:20 [notice] 1#1: start worker process 37
2023/08/03 16:28:20 [notice] 1#1: start worker process 38
2023/08/03 16:28:20 [notice] 1#1: start worker process 39
172.249.68.36 - - [03/Aug/2023:16:30:24 +0000] "GET / HTTP/1.1" 200 615 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36" "-"
2023/08/03 16:30:24 [error] 25#25: *1 open() "/usr/share/nginx/html/favicon.ico" failed (2: No such file or directory), client: 172.249.68.36, server: localhost, request: "GET /favicon.ico HTTP/1.1", host: "147.75.40.47:8080", referrer: "http://147.75.40.47:8080/"
172.249.68.36 - - [03/Aug/2023:16:30:24 +0000] "GET /favicon.ico HTTP/1.1" 404 555 "http://147.75.40.47:8080/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36" "-"
84.54.51.142 - - [03/Aug/2023:16:46:30 +0000] "CONNECT google.com:443 HTTP/1.1" 400 157 "-" "-" "-"
```


- FR -> AM
```
[adminuser@elastichost-am01 ~]$ sudo podman  run --name docker-nginx -p 8080:80 docker.io/nginx
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2023/08/03 16:29:39 [notice] 1#1: using the "epoll" event method
2023/08/03 16:29:39 [notice] 1#1: nginx/1.25.1
2023/08/03 16:29:39 [notice] 1#1: built by gcc 12.2.0 (Debian 12.2.0-14)
2023/08/03 16:29:39 [notice] 1#1: OS: Linux 5.14.0-284.11.1.el9_2.x86_64
2023/08/03 16:29:39 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2023/08/03 16:29:39 [notice] 1#1: start worker processes
2023/08/03 16:29:39 [notice] 1#1: start worker process 24
2023/08/03 16:29:39 [notice] 1#1: start worker process 25
2023/08/03 16:29:39 [notice] 1#1: start worker process 26
2023/08/03 16:29:39 [notice] 1#1: start worker process 27
2023/08/03 16:29:39 [notice] 1#1: start worker process 28
2023/08/03 16:29:39 [notice] 1#1: start worker process 29
2023/08/03 16:29:39 [notice] 1#1: start worker process 30
2023/08/03 16:29:39 [notice] 1#1: start worker process 31
2023/08/03 16:29:39 [notice] 1#1: start worker process 32
2023/08/03 16:29:39 [notice] 1#1: start worker process 33
2023/08/03 16:29:39 [notice] 1#1: start worker process 34
2023/08/03 16:29:39 [notice] 1#1: start worker process 35
2023/08/03 16:29:39 [notice] 1#1: start worker process 36
2023/08/03 16:29:39 [notice] 1#1: start worker process 37
2023/08/03 16:29:39 [notice] 1#1: start worker process 38
2023/08/03 16:29:39 [notice] 1#1: start worker process 39
145.40.95.197 - - [03/Aug/2023:16:30:41 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.76.1" "-"
45.128.232.84 - - [03/Aug/2023:16:37:53 +0000] "CONNECT www.twitch.tv:443 HTTP/1.1" 400 157 "-" "-" "-"
43.251.84.196 - - [03/Aug/2023:16:41:49 +0000] "GET / HTTP/1.1" 200 615 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36" "-"
141.98.11.44 - - [03/Aug/2023:16:42:34 +0000] "GET / HTTP/1.1" 200 615 "-" "Mozilla/5.0 (Windows NT 5.1; rv:9.0.1) Gecko/20100101 Firefox/9.0.1" "-"
```
