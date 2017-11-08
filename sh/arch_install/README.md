# Arch linux install

## Introduction

This is the documentation to install the scoreboard in a proxmox container with the following settings:

* Template: `archlinux-base_20170704-1_amd64.tar.gz`
* Root Disk: local-zfs,size=16G
* CPU: 2 cores
* Memory: 2GB
* Start at boot: Yes

The root password and SSH key was added via the proxmox webUI.


## OS configurations

```bash
systemctl enable sshd
systemctl start sshd

pacman -S archlinux-keyring
pacman -Syu

pacman -S git tmux

# Edit /etc/locale. Uncomment one of the list
locale-gen

# reboot
```


## Scoreboard configuration

```bash
pacman -S extra/postgresql extra/nginx extra/python-pip
pip3 install --upgrade pip

useradd --system -d /home/sb --create-home sb

mkdir /home/sb/.ssh
cp /root/.ssh/id_ed25519* /home/sb/.ssh/
cp /root/.ssh/config /home/sb/.ssh/config
cp /root/.vimrc /home/sb/
chown -R sb:sb /home/sb/.*

su - sb
git clone https://github.com/hackfestca/hfscoreboard
mkdir scoreboard/logs
# edit /home/sb/scoreboard/sql/install.sql (Change admin password)
exit
cp /home/sb/scoreboard/sql/install.sql /var/lib/postgres/
chown postgres:postgres /var/lib/postgres/install.sql
chmod 640 /var/lib/postgres/install.sql

cd /home/sb/scoreboard
pip3 install -r requirements.txt

# generate certificates and put them in /etc/ssl
# * /etc/ssl/sb.hf.h0m3.lan.crt
# * /etc/ssl/sb.hf.h0m3.lan.key
# * /etc/ssl/hf.ca.sb.crt (CA)
chown postgres:postgres /etc/ssl/sb.hf.h0m3.lan.*

su - postgres
initdb -D /var/lib/postgres/data

echo "# TYPE  DATABASE        USER            ADDRESS                 METHOD
hostssl  scoreboard      admin           172.22.0.0/24           md5
hostssl  scoreboard      admin           172.28.66.0/24          md5
hostssl  scoreboard      owner           172.22.0.0/24           md5
hostssl  scoreboard      owner           172.28.66.0/24          md5
#hostssl  scoreboard      web             172.22.0.0/24           trust" \
    >> /var/lib/postgres/data/pg_hba.conf

echo "unix_socket_directories = '/tmp'    # comma-separated list of directories
unix_socket_group = 'postgres'          # (change requires restart)
unix_socket_permissions = 0770      # begin with 0 to use octal notation

ssl = on            # (change requires restart)
ssl_ciphers = 'DEFAULT:!LOW:!EXP:!MD5:@STRENGTH'
ssl_cert_file = '/etc/ssl/sb.hf.h0m3.lan.crt'
ssl_key_file = '/etc/ssl/sb.hf.h0m3.lan.key'
ssl_ca_file = '/etc/ssl/hf.ca.sb.crt'" >> /var/lib/postgres/data/postgresql.conf

echo "# DB Version: 9.6
# Source: http://pgtune.leopard.in.ua/
# OS Type: linux
# DB Type: web
# Total Memory (RAM): 4 GB
# Number of Connections: 50
max_connections = 50
shared_buffers = 1GB
effective_cache_size = 3GB
work_mem = 20971kB
maintenance_work_mem = 256MB
min_wal_size = 1GB
max_wal_size = 2GB
checkpoint_completion_target = 0.7
wal_buffers = 16MB
default_statistics_target = 100" \   >> /var/lib/postgres/data/postgresql.conf

exit
systemctl restart postgresql

su - postgres
psql -f install.sql

# Edit and configure /etc/nginx/nginx.conf

# Unknown bug, nginx look for /etc/nginx/...
ln -s /usr/share/nginx/html /etc/nginx/html

for port in `seq 5000 5010`;
do
    echo "[Unit]
Description=HF Scoreboard Web app
After=syslog.target

[Service]
Type=simple
User=sb
Group=sb
WorkingDirectory=/home/sb/scoreboard
ExecStart=/home/sb/scoreboard/web.py --authByIP --port=$port
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target" > /usr/lib/systemd/system/sb_web_$port.service
done

echo "[Unit]
Description=HF Scoreboard Web API
After=syslog.target

[Service]
Type=simple
User=sb
Group=sb
WorkingDirectory=/home/sb/scoreboard
ExecStart=/home/sb/scoreboard/player-api.py -s --behind-proxy
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target" > /usr/lib/systemd/system/sb_api.service

systemctl enable postgresql
systemctl enable nginx
systemctl enable sb_api
systemctl start postgresql
systemctl start nginx
systemctl start sb_api

for port in `seq 5000 5010`;
do
    systemctl enable sb_web_$port
    systemctl start sb_web_$port
done
```

