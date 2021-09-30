#!/bin/bash
## Full credit to https://www.vultr.com/docs/monitor-latency-with-smokeping-on-ubuntu-20-04 for baseline steps

set -e 

METAL_ROUTER_IPS=('136.144.56.179' '145.40.125.17' '145.40.75.3' '147.75.87.3' 
'145.40.73.1' '145.40.113.3' '145.40.105.1' '147.28.133.1' '147.75.199.23' 
'136.144.55.31' '145.40.77.1' '145.40.93.77' '145.40.71.21' '145.40.109.1' 
'136.144.60.195' '147.75.92.5' '136.144.50.171' '145.40.87.43' '145.40.121.9'
'139.178.82.17' '147.75.70.17' '147.75.66.143' '147.75.94.153' '147.75.33.169')

# http://ec2-reachability.amazonaws.com/
AWS_ENDPOINTS=('3.80.0.0' '68.66.113.112' '15.181.176.161' '15.181.192.183' '72.41.10.180' '15.181.98.141' '64.187.131.1' '15.181.144.146' '3.12.0.0' '18.252.0.253' '13.52.0.0' '18.236.0.0' '15.181.17.111' '15.253.0.254' '3.32.0.253' '3.96.0.0' '15.228.0.0' '3.248.0.0' '3.64.0.0' '3.8.0.0' '15.160.0.0' '13.36.0.0' '13.48.0.0' '13.245.0.253' '15.184.0.253' '3.112.0.0' '3.34.0.0' '13.208.32.253' '3.0.0.9' '3.24.0.0' '3.6.0.0' '16.162.0.253' '52.80.5.207' '52.82.0.253')	

# https://github.com/GoogleCloudPlatform/gcping/blob/main/internal/config/endpoints.go
GCP_ENDPOINTS=('asia-east1-5tkroniexa-de.a.run.app' 'asia-east2-5tkroniexa-df.a.run.app' 'asia-northeast1-5tkroniexa-an.a.run.app' 'asia-northeast2-5tkroniexa-dt.a.run.app' 'asia-northeast3-5tkroniexa-du.a.run.app' 'asia-south1-5tkroniexa-el.a.run.app' 'asia-south2-5tkroniexa-em.a.run.app' 'asia-southeast1-5tkroniexa-as.a.run.app' 'asia-southeast2-5tkroniexa-et.a.run.app' 'australia-southeast1-5tkroniexa-ts.a.run.app' 'australia-southeast2-5tkroniexa-km.a.run.app' 'europe-central2-5tkroniexa-lm.a.run.app' 'europe-north1-5tkroniexa-lz.a.run.app' 'europe-west1-5tkroniexa-ew.a.run.app' 'europe-west2-5tkroniexa-nw.a.run.app' 'europe-west3-5tkroniexa-ey.a.run.app' 'europe-west4-5tkroniexa-ez.a.run.app' 'europe-west6-5tkroniexa-oa.a.run.app' 'northamerica-northeast1-5tkroniexa-nn.a.run.app' 'northamerica-northeast2-5tkroniexa-pd.a.run.app' 'southamerica-east1-5tkroniexa-rj.a.run.app' 'us-central1-5tkroniexa-uc.a.run.app' 'us-east1-5tkroniexa-ue.a.run.app' 'us-east4-5tkroniexa-uk.a.run.app' 'us-west1-5tkroniexa-uw.a.run.app' 'us-west2-5tkroniexa-wl.a.run.app' 'us-west3-5tkroniexa-wm.a.run.app' 'us-west4-5tkroniexa-wn.a.run.app')

# DNS carriers + https://www.dotcom-monitor.com/blog/technical-tools/network-location-ip-addresses/
RANDOM_ENDPOINTS=('208.67.222.222' '208.67.220.220' '1.1.1.1' '1.0.0.1' '8.8.8.8' '8.8.4.4' '139.130.4.5' '69.162.81.155' '192.199.248.75' '162.254.206.227' '207.250.234.100' '184.107.126.165' '206.71.50.230' '65.49.22.66' '23.81.0.59' '207.228.238.7')
METADATA_JSON_FILE='/tmp/metal_metadata.json'

rm -f $METADATA_JSON_FILE
curl --silent --retry 5 -o $METADATA_JSON_FILE https://metadata.platformequinix.com/metadata 2>/dev/null

chmod 0400 $METADATA_JSON_FILE

METAL_PUBLIC_IP=$(jq -r '.network.addresses[0].address' $METADATA_JSON_FILE)
METAL_PUBLIC_GW=$(jq -r '.network.addresses[0].gateway' $METADATA_JSON_FILE)
METAL_PRIVATE_GW=$(jq -r '.network.addresses[2].gateway' $METADATA_JSON_FILE)

sudo DEBIAN_FRONTEND=noninteractive apt-get  -yq --no-install-suggests --no-install-recommends --force-yes install nginx fcgiwrap smokeping > /dev/null 2>&1

sudo cp -f /usr/share/doc/fcgiwrap/examples/nginx.conf /etc/nginx/fcgiwrap.conf

sudo rm -f /etc/nginx/sites-enabled/default

sudo rm -f /etc/nginx/sites-available/smokeping
sudo rm -f /tmp/sites_available_smokeping
sudo cat > /tmp/sites_available_smokeping << EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    location = /smokeping/smokeping.cgi {
            fastcgi_intercept_errors on;

            fastcgi_param   SCRIPT_FILENAME    /usr/lib/cgi-bin/smokeping.cgi;
            fastcgi_param   QUERY_STRING            \$query_string;
            fastcgi_param   REQUEST_METHOD          \$request_method;
            fastcgi_param   CONTENT_TYPE            \$content_type;
            fastcgi_param   CONTENT_LENGTH          \$content_length;
            fastcgi_param   REQUEST_URI             \$request_uri;
            fastcgi_param   DOCUMENT_URI            \$document_uri;
            fastcgi_param   DOCUMENT_ROOT           \$document_root;
            fastcgi_param   SERVER_PROTOCOL         \$server_protocol;
            fastcgi_param   GATEWAY_INTERFACE       CGI/1.1;
            fastcgi_param   SERVER_SOFTWARE         nginx/\$nginx_version;
            fastcgi_param   REMOTE_ADDR             \$remote_addr;
            fastcgi_param   REMOTE_PORT             \$remote_port;
            fastcgi_param   SERVER_ADDR             \$server_addr;
            fastcgi_param   SERVER_PORT             \$server_port;
            fastcgi_param   SERVER_NAME             \$server_name;
            fastcgi_param   HTTPS                   \$https if_not_empty;

            fastcgi_pass unix:/var/run/fcgiwrap.socket;
    }

    location ^~ /smokeping/ {
            alias /usr/share/smokeping/www/;
            index smokeping.cgi;
            gzip off;
    }

    location / {
            return 301 http://$METAL_PUBLIC_IP/smokeping/smokeping.cgi;
    }

	location /mtrs/ {
		alias /var/www/html/mtrs/;
		autoindex on;
		autoindex_exact_size off;
		autoindex_format html;
		autoindex_localtime on;
	}	
}
EOL

sudo mkdir -p /var/www/html/mtrs/
sudo chown -R www-data:www-data /var/www/html/mtrs
sudo chmod 0777 /var/www/html/mtrs
sudo rm -rf /etc/cron.hourly/*mtr*

sudo cp -f /tmp/sites_available_smokeping /etc/nginx/sites-available/smokeping

sudo rm -f /etc/nginx/sites-enabled/smokeping
sudo ln -s /etc/nginx/sites-available/smokeping /etc/nginx/sites-enabled/smokeping

sudo service nginx restart

sudo rm -f /etc/smokeping/config.d/General
sudo rm -f /tmp/smokeping_general
sudo cat > /tmp/smokeping_general << EOL
*** General ***

owner    = metal_smokeping
contact  = root@localhost
mailhost = localhost
cgiurl   = http://$METAL_PUBLIC_IP/smokeping/smokeping.cgi
# specify this to get syslog logging
syslogfacility = local0
# each probe is now run in its own process
# disable this to revert to the old behaviour
# concurrentprobes = no

@include /etc/smokeping/config.d/pathnames
EOL

sudo cp -f /tmp/smokeping_general /etc/smokeping/config.d/General

sudo rm -f /etc/smokeping/config.d/Probes

sudo cat > /tmp/smokeping_probes << EOL
*** Probes ***

+ FPing

binary = /usr/bin/fping

+Curl

binary = /usr/bin/curl
forks = 5
offset = 50%
step = 300
follow_redirects = yes
include_redirects = yes
insecure_ssl = 1
pings = 5
timeout = 20
urlformat = http://%host%/
EOL

sudo cp -f /tmp/smokeping_probes /etc/smokeping/config.d/Probes

sudo rm -f /etc/smokeping/config.d/Targets

sudo cat > /tmp/smokeping_targets_gw << EOL
*** Targets ***
probe = FPing
menu = Top
title = Metal Network Latency Grapher
remark = Welcome to this Metal Smokeping Instance


+ local_gateways
menu = local_gateways
title = local_gateways

++ public_gateway
probe = FPing
host = $METAL_PUBLIC_GW
title = public_gateway

++ private_gateway
probe = FPing
host = $METAL_PRIVATE_GW
title = private_gateway
EOL

echo "+ global_metal_routers" >> /tmp/smokeping_targets_gw
echo "menu = global_metal_routers" >> /tmp/smokeping_targets_gw
echo "title = global_metal_routers" >> /tmp/smokeping_targets_gw

for ROUTER in "${METAL_ROUTER_IPS[@]}"; do
    echo "++ $(echo $ROUTER | tr -d ".")" >> /tmp/smokeping_targets_gw
    echo "probe = FPing" >> /tmp/smokeping_targets_gw
    echo "host = $ROUTER" >> /tmp/smokeping_targets_gw
    echo "title = metal_router_$(echo $ROUTER | tr -d ".")" >> /tmp/smokeping_targets_gw
	
	sudo cat > /tmp/metal_router_$(echo $ROUTER | tr -d ".")_mtr << EOL
#!/bin/bash
sleep \$[ ( $RANDOM % 100 )  + 1 ]s
DATE=\$(date -u +"%Y_%m_%d_%H")
sudo mtr -r $ROUTER > /var/www/html/mtrs/$(echo $ROUTER | tr -d ".")_\$DATE.mtr 2>&1
EOL
	
	sudo chmod 0750 /tmp/metal_router_$(echo $ROUTER | tr -d ".")_mtr
	sudo mv -f /tmp/metal_router_$(echo $ROUTER | tr -d ".")_mtr /etc/cron.hourly/
done

echo "+ global_aws_endpoints" >> /tmp/smokeping_targets_gw
echo "menu = global_aws_endpoints" >> /tmp/smokeping_targets_gw
echo "title = global_aws_endpoints" >> /tmp/smokeping_targets_gw

for ENDPOINT in "${AWS_ENDPOINTS[@]}"; do
    echo "++ $(echo $ENDPOINT | tr -d ".")" >> /tmp/smokeping_targets_gw
    echo "probe = FPing" >> /tmp/smokeping_targets_gw
    echo "host = $ENDPOINT" >> /tmp/smokeping_targets_gw
    echo "title = aws_endpoint_$(echo $ENDPOINT | tr -d ".")" >> /tmp/smokeping_targets_gw

	sudo cat > /tmp/aws_endpoint_$(echo $ENDPOINT | tr -d ".")_mtr << EOL
#!/bin/bash
sleep \$[ ( $RANDOM % 100 )  + 1 ]s
DATE=\$(date -u +"%Y_%m_%d_%H")
sudo mtr -r $ENDPOINT > /var/www/html/mtrs/$(echo $ENDPOINT | tr -d ".")_\$DATE.mtr 2>&1
EOL
	sudo chmod 0750 /tmp/aws_endpoint_$(echo $ENDPOINT | tr -d ".")_mtr
	sudo mv -f /tmp/aws_endpoint_$(echo $ENDPOINT | tr -d ".")_mtr /etc/cron.hourly/	
done

echo "+ global_gcp_endpoints" >> /tmp/smokeping_targets_gw
echo "menu = global_gcp_endpoints" >> /tmp/smokeping_targets_gw
echo "title = global_gcp_endpoints" >> /tmp/smokeping_targets_gw

for ENDPOINT in "${GCP_ENDPOINTS[@]}"; do
    echo "++ $(echo $ENDPOINT | tr -d ".")" >> /tmp/smokeping_targets_gw
    echo "probe = Curl" >> /tmp/smokeping_targets_gw
    echo "host = $ENDPOINT" >> /tmp/smokeping_targets_gw
    echo "title = gcp_endpoint_$(echo $ENDPOINT | tr -d ".")" >> /tmp/smokeping_targets_gw
done

echo "+ random_endpoints" >> /tmp/smokeping_targets_gw
echo "menu = random_endpoints" >> /tmp/smokeping_targets_gw
echo "title = random_endpoints" >> /tmp/smokeping_targets_gw

for ENDPOINT in "${RANDOM_ENDPOINTS[@]}"; do
    echo "++ $(echo $ENDPOINT | tr -d ".")" >> /tmp/smokeping_targets_gw
    echo "probe = FPing" >> /tmp/smokeping_targets_gw
    echo "host = $ENDPOINT" >> /tmp/smokeping_targets_gw
    echo "title = random_endpoint_$(echo $ENDPOINT | tr -d ".")" >> /tmp/smokeping_targets_gw
	
	sudo cat > /tmp/random_endpoint_$(echo $ENDPOINT | tr -d ".")_mtr<< EOL
#!/bin/bash
sleep \$[ ( $RANDOM % 100 )  + 1 ]s
DATE=\$(date -u +"%Y_%m_%d_%H")
mtr -r $ENDPOINT > /var/www/html/mtrs/$(echo $ENDPOINT | tr -d ".")_\$DATE.mtr 2>&1
EOL
	sudo chmod 0750 /tmp/random_endpoint_$(echo $ENDPOINT | tr -d ".")_mtr
	sudo mv -f /tmp/random_endpoint_$(echo $ENDPOINT | tr -d ".")_mtr /etc/cron.hourly/		
done


sudo cp -f /tmp/smokeping_targets_gw /etc/smokeping/config.d/Targets

sudo service smokeping restart

sudo cat > /tmp/netstat.sh << EOL
#!/bin/bash
sleep \$[ ( $RANDOM % 100 )  + 1 ]s
DATE=\$(date -u +"%Y_%m_%d_%H")
netstat -s > /var/www/html/mtrs/netstat_\$DATE.netstat 2>&1
EOL

sudo chmod 0750 /tmp/netstat.sh
sudo mv -f /tmp/netstat.sh /etc/cron.hourly/


sudo rm -f /tmp/smokeping_general
sudo rm -f /tmp/smokeping_targets_gw
sudo rm -f /tmp/sites_available_smokeping
sudo rm -f /tmp/smokeping_probes
sudo rm -f /tmp/metal_metadata.json
sudo touch /var/lib/smokeping/metal_instance_done.touch
