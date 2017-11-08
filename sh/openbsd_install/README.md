# OpenBSD Install

## HF 2015 Architecture

The configuration during Hackfest was similar to the following diagram but note that it can be merged to a single VM.

![architecture](https://github.com/hackfestca/hfscoreboard/raw/master/docs/img/architecture2015.png)

Only the presentation server (nginx) was accessible from players. 

## Installation procedure

This procedure roughly describe a three(3) tier architecture but all steps can be done on a single box. Let's say we have the following topology:

* 2x Web presentation servers at 172.28.71.11-12, resolving to scoreboard.hf (cyclic round robin)
* 2x Web application servers at 172.28.70.22-23, resolving to sb-app01.hf and sb-app02.hf
* A database load balancer server at 172.28.70.21, resolving to sb-db00.hf
* 2x database servers at 172.28.70.19-20, resolving to sb-db01.hf and sb-db02.hf
* Admins are in 172.16.66.0/24

Indeed, you can change DNS names and IPs as you wish.

1. Install one or many VMs with the latest version of [OpenBSD][openbsd]. Default config with no GUI will do. Increase the `var` partition if you plan to have a lot of logs (a lot of players, bruteforce, several binaries to download, etc.)

 For Hackfest 2015, 7 VMs were setup with 512mb of RAM, 8gb of disk and 1 CPU on each. This was overkill. 
  
 **It will work with another OS as long as you are resourceful :)**

2. Create a low privilege user on all VMs. Let's call it sb.

    ```
    # adduser sb
    Enter username []: sb
    Enter full name []: Scoreboard
    Enter shell csh ksh nologin sh [ksh]: 
    Uid [1000]: 
    Login group sb [sb]: 
    Login group is ''sb''. Invite sb into other groups: guest no 
    [no]: 
    Login class authpf bgpd daemon default staff [default]: 
    Enter password []: 
    Disable password logins for the user? (y/n) [n]: y
    
    Name:        sb
    Password:    ****
    Fullname:    Scoreboard
    Uid:         1000
    Gid:         1000 (sb)
    Groups:      sb
    Login Class: default
    HOME:        /home/sb
    Shell:       /bin/ksh
    OK? (y/n) [y]: 
    Added user ''sb''
    Copy files from /etc/skel to /home/sb
    Add another user? (y/n) [y]: n
    Goodbye!
    ```

3. [On sb-db01.hf and sb-db02.hf] Install and configure postgresql

    ```bash
    pkg_add postgresql-server
    pkg_add postgresql-contrib    # for pgcrypto
    mkdir -p /var/postgresql/data
    chown _postgresql:_postgresql /var/postgresql/data
    su - _postgresql
    initdb -D /var/postgresql/data
    exit
    /etc/rc.d/postgresql restart
    ```
 Create database (see `sql/install.sql`)
    ```bash
    $ su - _postgresql
    $ psql postgres
    psql (9.4.4)
    Type "help" for help.
    
    postgres=#  
    ```
 Then customize `sql/install.sql` file and copy/paste in this shell.

 Edit `/var/postgresql/data/pg_hba.conf` to configure database access. 

    ```
    host scoreboard  owner       172.28.70.21/32            trust
    host scoreboard  flagupdater 172.28.70.21/32            trust
    host scoreboard  player      172.28.70.21/32            trust
    host scoreboard  web         172.28.70.21/32            trust
    host scoreboard  admin       172.28.70.21/32            trust

    hostssl scoreboard  owner       172.16.66.0/24          cert clientcert=1
    hostssl scoreboard  flagupdater 172.16.66.0/24          cert clientcert=1
    hostssl scoreboard  flagupdater 172.28.70.22/32         cert clientcert=1
    hostssl scoreboard  flagupdater 172.28.70.23/32         cert clientcert=1
    hostssl scoreboard  player      172.16.66.0/24          cert clientcert=1
    hostssl scoreboard  player      172.28.70.22/32         cert clientcert=1
    hostssl scoreboard  player      172.28.70.23/32         cert clientcert=1
    hostssl scoreboard  web         172.16.66.0/24          cert clientcert=1
    hostssl scoreboard  web         172.28.70.22/32         cert clientcert=1
    hostssl scoreboard  web         172.28.70.23/32         cert clientcert=1
    hostssl scoreboard  admin       172.16.66.0/24          md5
    ```

 Edit `/var/postgresql/data/postgresql.conf` and set the following variables.
    ```
    listen_addresses = '0.0.0.0'
    ...
    ssl = on
    ssl_ciphers = 'DEFAULT:!LOW:!EXP:!MD5:@STRENGTH'
    ...
    ssl_cert_file = '/etc/ssl/hf.srv.db.hf.crt' # (change requires restart)
    ssl_key_file = '/etc/ssl/hf.srv.db.hf.key'  # (change requires restart)
    ssl_ca_file = '/etc/ssl/hf.ca.sb.crt'       # (change requires restart)
    ...
    search_path = 'scoreboard'
    ...
    ```

4. [On sb-db00.hf] Install pgpool-II
    ```bash
    pkg_add pgpool-II
    ```

 Configure pgpool-II in `/etc/pgpool.conf`. Here, two backends are configured and SSL is enabled.
    ```
    backend_hostname0 = 'sb-db01.hf'
    backend_port0 = 5432
    backend_weight0 = 1 
    backend_data_directory0 = '/var/postgresql/data'
    backend_flag0 = 'DISALLOW_TO_FAILOVER'
    
    backend_hostname1 = 'sb-db02.hf'
    backend_port1 = 5432
    backend_weight1 = 1 
    backend_data_directory1 = '/var/postgresql/data'
    backend_flag1 = 'DISALLOW_TO_FAILOVER'
    ```

    ```
    ssl = on
    ssl_cert = '/etc/pgpool/hf.srv.db.hf.crt'    # (change requires restart)
    ssl_key = '/etc/pgpool/hf.srv.db.hf.key'     # (change requires restart)
    ssl_ca = '/etc/pgpool/hf.ca.sb.crt'          # (change requires restart)
    ```

Configure database access: `/etc/pool_hba.conf`

```
hostssl scoreboard  owner       172.16.66.0/24          cert clientcert=1
hostssl scoreboard  flagupdater 172.16.66.0/24          cert clientcert=1
hostssl scoreboard  flagupdater 172.28.70.22/32         cert clientcert=1
hostssl scoreboard  flagupdater 172.28.70.23/32         cert clientcert=1
hostssl scoreboard  player      172.16.66.0/24          cert clientcert=1
hostssl scoreboard  player      172.28.70.22/32         cert clientcert=1
hostssl scoreboard  player      172.28.70.23/32         cert clientcert=1
hostssl scoreboard  web         172.16.66.0/24          cert clientcert=1
hostssl scoreboard  web         172.28.70.22/32         cert clientcert=1
hostssl scoreboard  web         172.28.70.23/32         cert clientcert=1
hostssl scoreboard  admin       172.16.66.0/24          md5
```

 Enable load balancing mode. Whitelisted patterns will be load balanced between the master and the slaves. This means that these functions must only read data, not write. 
    ```
    load_balance_mode = on
    ```

    ```
    white_function_list = 'getScore*,getTeamInfoFromIp*,getCatProgressFromIp*,
                           getFlagProgressFromIp*,getNewsList*,getLotoCurrentList*,
                           getLotoHistory*,getLotoInfo,getNewsList,getModelCountDown,
                           getModelTeamsTop'
    black_function_list = '*,currval,lastval,nextval,setval'
    ```

 Enable Master/Slave mode.
    ```
    master_slave_mode = on
    ```

 Note that Automatic Failover was not configured this year. TODO 2016 ;)

5. [On sb-app] Install python dependencies

```bash
pkg_add py3-pip py3-psycopg2
ln -sf /usr/local/bin/pip3.4 /usr/local/bin/pip
pip install --upgrade pip
pip install tornado
```

Download the code from git

```bash
cd /var/www
git clone https://github.com/hackfestca/hfscoreboard scoreboard
chown -R sb:sb scoreboard
cd scoreboard
mkdir logs
chmod g+w /home/sb/scoreboard/logs
```

Download and install supervisor. This will be used to run the process as a service.

    ```bash
    pkg_add py-pip
    pip2.7 install --upgrade pip
    pkg_add supervisor
    ```

Download, compile and install ssh4py

```bash
git clone https://github.com/wallunit/ssh4py.git
pkg_add libssh2
cd /usr/local/include/python3.4m/
ln -s ../libssh2.h libssh2.h 
ln -s ../libssh2_sftp.h libssh2_sftp.h 
ln -s ../libssh2_publickey.h libssh2_publickey.h 
cd /root/ssh4py; python3.4 ./setup.py build; python3.4 ./setup.py install
```

Uncomment the last two lines of `/etc/supervisord.conf`

```
[include]
files = supervisord.d/*.ini
```

Setup a supervisor program for the player API in `/etc/supervisord.d/playerApi.ini`

```
[program:playerApi]
directory=/var/www/scoreboard
command=python3.4 player-api.py --start --behind-proxy
user=sb
stdout_logfile=/var/log/scoreboard.player.log
redirect_stderr=true
autostart=true
autorestart=true
```

Setup a supervisor program for the web application in `/etc/supervisord.d/web.ini`

```
[program:web]
directory=/var/www/scoreboard
command=python3.4 web.py
user=sb
stdout_logfile=/var/log/scoreboard.web.log
redirect_stderr=true
autostart=true
autorestart=true
```

 Make a copy of config.default.py, name it config.py and customize it. Most important settings are `PLAYER_API_URI` and `DB_HOST`

```bash
cd /var/www/scoreboard
cp config.default.py config.py
vim config.py
```

6. [On scoreboard.hf] Install nginx

    ```bash
    pkg_add nginx
    mkdir /var/www/htdocs/{public,static,blackmarket}
    ```

 Then configure the web server to do reverse proxy to sb-app. You can also configure TLS, caching and static files handling (see below). Note that caching was removed this year.

    ```
    upstream web{
     server 172.28.70.22:5000;
     server 172.28.70.23:5000;
    }
    
    upstream playerApi{
     server 172.28.70.22:8000;
     server 172.28.70.23:8000 backup;
    }

    server {
        listen  80;
        server_name  scoreboard.hf;
        server_name  172.28.71.11;
        client_max_body_size 1m;
        client_body_temp_path /var/www/cache/client_body_temp_80;
    
        access_log  /var/log/nginx/scoreboard.access.log;
        error_log /var/log/nginx/scoreboard.error.log;
    
        location / {
            return  301 https://$host$request_uri;
        }
    
        location /RPC2 {
            proxy_redirect off;
            proxy_pass_header Server;                       
            proxy_set_header Host $http_host;                       
            proxy_set_header X-Real-IP $remote_addr;                       
            proxy_set_header X-Scheme $scheme;                       
            proxy_pass http://playerApi;                       
            proxy_next_upstream error;
        }
    }
    
    server {
        listen       443;
        server_name  scoreboard.hf;
        server_name  172.28.71.11;
        root         /var/www/htdocs;
        client_max_body_size 1m;
        client_body_temp_path /var/www/cache/client_body_temp_443;
    
        access_log  /var/log/nginx/scoreboard.access.log;
        error_log /var/log/nginx/scoreboard.error.log;
    
        location / {
            proxy_redirect off;
            proxy_pass_header Server;                       
            proxy_set_header Host $http_host;                       
            proxy_set_header X-Real-IP $remote_addr;                       
            proxy_set_header X-Scheme $scheme;                       
            proxy_pass http://web;                       
            proxy_next_upstream error;
        }
    
        location /RPC2 {
            proxy_redirect off;
            proxy_pass_header Server;                       
            proxy_set_header Host $http_host;                       
            proxy_set_header X-Real-IP $remote_addr;                       
            proxy_set_header X-Scheme $scheme;                       
            proxy_pass http://playerApi;                       
            proxy_next_upstream error;
        }
    
       location /status {
            # Turn on stats
            stub_status on;
            access_log   off;
            allow 192.168.1.0/24;
            deny all;
       }
    
        location /static {
            alias /var/www/htdocs/static;
        }
    
        location /blackmarket {
            alias /var/www/htdocs/blackmarket;
        }
    
        location /public {
            alias /var/www/htdocs/public;
        }
    
        location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico)$ {
            access_log        off;
            expires           max;
            add_header Pragma public;
            add_header Cache-Control "public, must-revalidate, proxy-revalidate";
        }
    
        location ~* \.(eot|ttf|woff)$ {
                add_header Access-Control-Allow-Origin *;
        }
    
        error_page  404              /404.html;
        location = /404.html {
            root   /var/www/htdocs;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /var/www/htdocs;
        }
    
        location ~ /\.ht {
            deny  all;
        }
    
        # Enable HSTS
        # http://axiacore.com/blog/enable-perfect-forward-secrecy-nginx/
        add_header Strict-Transport-Security "max-age=2678400; includeSubdomains;";
    
        ssl                  on;
        ssl_certificate      /etc/ssl/hf.srv.scoreboard2016.hf.crt;
        ssl_certificate_key  /etc/ssl/hf.srv.scoreboard2016.hf.key;
    
        ssl_session_timeout  5m;
        ssl_session_cache    shared:SSL:10m;
    
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    
        ssl_ciphers "HIGH:!aNULL:!MD5 or HIGH:!aNULL:!MD5:!3DES";
        #ssl_prefer_server_ciphers   on;
    }
    ```

7. Several certificates are required for database authentication or TLS on the web server.

 Overview:
 * Database CA
   * Server certificate for db.hf
   * Client certificate for player xmlrpc API
   * Client certificate for web access
   * Client certificate for owner
   * Client certificate for flagUpdater.py / lotoUpdater.py / bmUpdater.py
 * Player CA
   * Server certificate for scoreboard.hf
   
 A simple way to generate certificates is to customize certificate properties in the `sh/cert/openssl.cnf` config file and then run the `sh/cert/gencert.sh` script. If you plan to use passwords instead, skip this step.
    ```bash
    cd sh/cert
    ./gencert.sh
    ```
 Copy the database certificate and key file on the databases and load balancers
    ```bash
    scp hf.srv.sb.hf.{crt,key} root@sb-db01.hf:/var/postgresql/data/certs/
    scp hf.srv.sb.hf.{crt,key} root@sb-db02.hf:/var/postgresql/data/certs/
    scp hf.srv.sb.hf.{crt,key} root@sb-db00.hf:/etc/pgpool/
    scp hf.ca.sb.crt root@sb-db01.hf:/var/postgresql/data/certs/
    scp hf.ca.sb.crt root@sb-db02.hf:/var/postgresql/data/certs/
    scp hf.ca.sb.crt root@sb-db00.hf:/etc/pgpool/
    ```
 Copy the flagUpdater certificate and key file on sb-app01.hf
    ```bash
    cp hf.cli.db.flagupdater.{crt,key} root@sb-app01.hf:/var/www/scoreboard/certs/
    ssh root@sb-app01.hf chown sb:sb /var/www/scoreboard/certs/hf.cli.db.web.{crt,key}
    ```
 Upload the web certificate and key file to sb-app{01,02}.hf
    ```bash
    cp hf.cli.db.web.{crt,key} root@sb-app01.hf:/var/www/scoreboard/certs/
    cp hf.cli.db.web.{crt,key} root@sb-app02.hf:/var/www/scoreboard/certs/
    ssh root@sb-app01.hf chown sb:sb /var/www/scoreboard/certs/hf.cli.db.web.{crt,key}
    ssh root@sb-app02.hf chown sb:sb /var/www/scoreboard/certs/hf.cli.db.web.{crt,key}
    ```
 Upload the player certificate and key file to scoreboard.hf
    ```bash
    cp hf.cli.db.player.{crt,key} root@sb-app01.hf:/var/www/scoreboard/certs/
    cp hf.cli.db.player.{crt,key} root@sb-app02.hf:/var/www/scoreboard/certs/
    ssh root@sb-app01.hf chown sb:sb /var/www/scoreboard/certs/hf.cli.db.player.{crt,key}
    ssh root@sb-app02.hf chown sb:sb /var/www/scoreboard/certs/hf.cli.db.player.{crt,key}
    ```

[openbsd]: http://www.openbsd.org


## Starting the scoreboard

* [On sb-db01.hf and sb-db02.hf] Run `/etc/rc.d/postgresql start`
* [On sb-db00.hf] Run `/etc/rc.d/pgpool start`
* [On sb-app01.hf and sb-app02.hf] Run `supervisorctl start all`
* [On sb-web01.hf and sb-web02.hf] Run `/etc/rc.d/nginx start`
