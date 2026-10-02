# Setup Workshop

## sample env

    load balancer / jmeter machine: ldap-01.ldapcon2026.symas.net
    ldap provider :ldap1-01.ldapcon2026.symas.net
    ldap consumer: ldap2-01.ldapcon2026.symas.net
    monitor host: monitor-01.ldapcon2026.symas.net

# preparation

If you are using cn=config, change it back.

```bash
cd /opt/symas/etc/openldap/
ls -al .

root@ldap1-96:/opt/symas/etc/openldap# ls -al
lrwxrwxrwx 1 root     root       25 Oct  1 21:31 slapd.conf -> /etc/opt/symas/slapd.conf
drwxr-xr-x 3 openldap openldap 4096 Oct  2 10:28 slapd.d

rm -rf slapd.d
service slapd restart
```
    
# Enable Prometheus

1. Login to monitor host

- replace [monitor-host]:

```bash
ssh root@[monitor-host].symas.net
```

2. configure service

- replace [hostname1], [hostname2], [hostname3], [monitor-host]:
-e.g.
  - ldap-01
  - ldap1-01
  - ldap2-01
  - monitor-01

If machine set is '01'

```/etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'telegraf'
    scrape_interval: 10s
    static_configs:
      - targets: ['[hostname1].ldapcon2026.symas.net:9100','[hostname2].ldapcon2026.symas.net:9100','[hostname3].ldapcon2026.symas.net:9100']
    scheme: https
    tls_config:
      cert_file: /opt/symas/ssl/[monitor-host].ldapcon2026.symas.net.crt
      key_file: /opt/symas/ssl/[monitor-host].ldapcon2026.symas.net.key
      ca_file: /opt/symas/ssl/ca.crt
      insecure_skip_verify: false
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - 'localhost:9093'
rule_files:
  - "openldap_alerts.yml"
```

3. restart service

```bash
service prometheus restart
```

4. test/verify

These tests are optional.

```bash
service prometheus status
journalctl -u  prometheus

Sep 26 22:21:52 monitor-01.ldapcon2026.symas.net prometheus[15398]: time=2026-09-26T22:21:52.655Z level=INFO source=manager.go:176 msg="Starting rule manager..." component="rule manager"
```

# Not good if you see this:
```
Sep 26 22:21:57 monitor-01.ldapcon2026.symas.net prometheus[15398]: time=2026-09-26T22:21:57.657Z level=ERROR source=manager.go:196 msg="error creating new scrape pool" component="scrape manager" err="err>

# verify the targets are being scraped:
curl -s "http://localhost:9090/api/v1/query" --data-urlencode 'query=up'

# should return a ton of data:
curl -sG "http://localhost:9090/api/v1/query" --data-urlencode 'query={__name__=~".+"}' 
````

more stats

```bash
# check a few of the metrics being tracked:
curl -s "http://localhost:9090/api/v1/query" --data-urlencode 'query=openldap_connections_current'
curl -s "http://localhost:9090/api/v1/query" --data-urlencode 'query=cpu_usage_idle'
curl -s "http://localhost:9090/api/v1/query" --data-urlencode 'query=mtail_line_count'
```

these return lots of data

```bash
# show all metric names:
curl -s "http://localhost:9090/api/v1/label/__name__/values"
# show all label names:
curl -s "http://localhost:9090/api/v1/labels"
# Show all currently stored series
curl -sG "http://localhost:9090/api/v1/series" --data-urlencode 'match[]={__name__=~".+"}'
# Show the latest value for every metric
curl -sG "http://localhost:9090/api/v1/query" --data-urlencode 'query={__name__=~".+"}'
```

# Enable Grafana

1. Login to monitor host

- replace [monitor-host]:

```bash
ssh root@[monitor-host].symas.net
```

2. configure grafana datasource

It connects grafana with prometheus's time-series database.

a. edit
```/etc/grafana/provisioning/datasources/prometheus-datasource.yml
apiVersion: 1

datasources:
  - name: SymasTest
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    uid: symas-openldap
```

b. chown
```bash
chown grafana: /etc/grafana/provisioning/datasources/prometheus-datasource.yml
```

3. enable grafana dashboard

a. edit
```/etc/grafana/provisioning/dashboards/symas-dashboard.yaml
apiVersion: 1

providers:
 - name: 'symas-openldap'
   orgId: 1
   folder: ''
   folderUid: ''
   type: file
   options:
     path: /var/lib/grafana/dashboards                           
```

b. chown
```bash
chown grafana: /etc/grafana/provisioning/dashboards/symas-dashboard.yaml
```

4. stage grafana dashboard

```bash
cp /tmp/symas-openldap.json /var/lib/grafana/dashboards/
```

# dest: '/var/lib/grafana/dashboards/symas-openldap.json'
# owner: grafana group: grafana mode: "0644"

5. restart grafana-server

```bash
service grafana-server restart
```

6. loginto grafana

- replace [monitor-host] with your instance
```
https://[monitor-host].ldapcon2026.symas.net:3000
```

admin/...

7. Goto dashboard

- on the side panel, click on "Dashboards"
- click on "OpenLDAP Monitor v3"
- change the ldap hostname, view the stats
- why isn't ldap2 working? (hint, go to next section)

8. Drilldown Metrics

- on the side panel, click on "Drilldown", and then "Metrics"
- slapd - contains mtail stats

# Enable Telegraf on LDAP2

1. Login to ldap2 host

- replace [ldap2-host]:

```bash
ssh root@[ldap2-host].ldapcon2026.symas.net
```

2. Basic setup for telegraf agent

- replace entire contents of the telegraf.conf (default) file with ...
- replace the [hostname] with ldap2's hostname:

```/etc/telegraf/telegraf.conf
[global_tags]
  dc = "ldap-test" #Example: ldap-dev, ldap-production

[agent]
  hostname = "[hostname].ldapcon2026.symas.net"
  interval = "3s"
  round_interval = true
  metric_batch_size = 10000
  metric_buffer_limit = 100000
  flush_interval = "10s"
  omit_hostname = false
  logfile = "/var/log/telegraf/telegraf.log"
  logfile_rotation_interval = "48h"
  logfile_rotation_max_size = "200MB"
  logfile_rotation_max_archives = 10
  debug = false
```

3. Enable telegraf plug-ins

a. input ldap

```/etc/telegraf/telegraf.d/input-openldap.conf
[[inputs.ldap]]
  dialect = "openldap"
  bind_mechanism = "EXTERNAL"
  server = "ldapi://%2Fvar%2Fsymas%2Frun%2Fldapi"
  interval = "10s"
# log_level = "debug"
```

b. input mtail

```/etc/telegraf/telegraf.d/input-mtail.conf
[[inputs.prometheus]]
  urls = ["http://localhost:3903/metrics"]
```

c. input system

```/etc/telegraf/telegraf.d/input-system.conf
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false
  core_tags = false
[[inputs.disk]]
  ignore_fs = ["ramfs", "tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]
[[inputs.diskio]]
[[inputs.kernel]]
[[inputs.mem]]
[[inputs.processes]]
[[inputs.swap]]
[[inputs.system]]
[[inputs.net]]
```

d. output prometheus

- replace [hostname]:

```/etc/telegraf/telegraf.d/output-prometheus.conf
[[outputs.prometheus_client]]
  listen = ":9100"
  tls_cert = "/opt/symas/ssl/[hostname].ldapcon2026.symas.net.crt"
  tls_key  = "/opt/symas/ssl/[hostname].ldapcon2026.symas.net.key"
  tls_allowed_cacerts = ["/opt/symas/ssl/ca.crt"]
```

4. Grant telegraf user access to crypto artifacts

- replace [hostname]:

```bash
usermod -aG openldap telegraf
# replace with actual hostname:
chmod g+r /opt/symas/ssl/[hostname].ldapcon2026.symas.net.key
```

5. restart daemon

```bash
service telegraf restart
```

If startup fails ...

```bash
journalctl -u telegraf
```

6. Verify Telegraf Metrics

- replace [hostname]:

```bash
curl -sk https://127.0.0.1:9100/metrics   --cert /opt/symas/ssl/[hostname].ldapcon2026.symas.net.crt   --key  /opt/symas/ssl/[hostname].ldapcon2026.symas.net.key   | grep -i ldap

# e.g.
curl -sk https://127.0.0.1:9100/metrics   --cert /opt/symas/ssl/ldap2-test.ldapcon2026.symas.net.crt   --key  /opt/symas/ssl/ldap2-test.ldapcon2026.symas.net.key   | grep -i ldap
```

7. Open firewall so prometheus can scrape stats

We are allowing the monitor host access to the prometheus port.

- replace [hostname]:

Ping the monitor host:

```bash
ping [hostname].ldapcon2026.symas.net

# e.g.
ping monitor-01.ldapcon2026.symas.net
```

- substitute x.x.x.x with IP fr

```bash
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="x.x.x.x" port protocol="tcp" port="9100" accept'
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="x.x.x.x" port protocol="tcp" port="9100" accept'

# e.g.
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="172.236.21.37" port protocol="tcp" port="9100" accept'
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="172.236.21.37" port protocol="tcp" port="9100" accept'
```

8. Verify on monitor host

- replace [monitor-hostname]:
- replace [hostname]:

```bash
curl -k --cert /opt/symas/ssl/[monitor-hostname].ldapcon2026.symas.net.crt --key /opt/symas/ssl/[monitor-hostname].ldapcon2026.symas.net.key https:/[hostname].ldapcon2026.symas.net:9100/metrics

# e.g.
curl -k --cert /opt/symas/ssl/monitor-01.ldapcon2026.symas.net.crt --key /opt/symas/ssl/monitor-01.ldapcon2026.symas.net.key https:/ldap2-01.ldapcon2026.symas.net:9100/metrics
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0# HELP cpu_usage_guest Telegraf collected metric
# TYPE cpu_usage_guest gauge
cpu_usage_guest{cpu="cpu-total",dc="ldap-test",host="ldap2-01.ldapcon2026.symas.net"} 0
...
```

9. Verify in Grafana console (after it has been enabled)

10. Where are the stats from the slapd monitor database?

- The telegraf ldap plugin has enabled connecting with slapd w/ unix socket and it's not working.
- These commands are run from ldap2

```bash
# It does works as root:
ldapsearch -QLLLb cn=monitor -s one 1.1 -Y EXTERNAL -H ldapi:///

# But it doesn't work as the telegraf user: 
sudo -u telegraf /opt/symas/bin/ldapsearch -QLLLb cn=monitor -s one -Y EXTERNAL -H ldapi:/// 1.1
No such object (32)
```

-- Why?

11. Enable telegraf to gather openldap monitor stats using unix sockets

a. get the id for telegraf user

```bash
id telegraf
uid=997(telegraf) gid=988(telegraf) groups=988(telegraf)
root@ldap2-test:/opt/symas/etc/openldap# 
```

b. add authz-regexp for that user slapd.conf

- place telegraf's id in the authz-regexp for the monitor database (at the end of the file)

```/opt/symas/etc/openldap/slapd.conf
...
database monitor

access to *
  by dn.exact="cn=monitoruser,ou=administrators,dc=example,dc=com" read
  by dn.exact="dc=example,dc=com" write
  by * none

# Place it here:
authz-regexp "gidNumber=988\\+uidNumber=997,cn=peercred,cn=external,cn=auth" "dc=example,dc=com"
```

c. restart the daemon

```bash
service slapd restart
```

d. verify

```bash
# as the telegraf user: 
sudo -u telegraf /opt/symas/bin/ldapsearch -QLLLb cn=monitor -s one -Y EXTERNAL -H ldapi:/// 1.1
dn: cn=Backends,cn=Monitor
dn: cn=Connections,cn=Monitor
dn: cn=Databases,cn=Monitor
...
```

e. verify ldap2's monitor stats are updating in grafana console

- Not working yet? Might take a minute.
- After waiting a few minutes, verify that the firewall is open between ldap2 and the monitor machine.

# Extra Credit

Build Dashboards

Query Grafana for metrics available: Drilldown->metrics

Use search terms:
slapd: mtail
ldap: openldap monitor

Here are some example:
slapd_syncrepl_messages_bucket
slapd_syncrepl_messages_count
slapd_syncrepl_messages_sum
slapd_ppolicy_expired
slapd_tls_failure
openldap_delete_operations_completed
openldap_modify_operations_completed
openldap_add_operations_completed\


# Jmeter troubleshooting


## Logs

/var/log/loadtest.log

## Workaround on PW Policies

In case the env has elaborate rules that breaks the tests, add to slapd.conf to workaround

```slapd.conf
ppolicy_rule require_password=no no_policy stop
```
