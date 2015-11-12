HF 2015 Scoreboard
==================

This is the scoreboard used for the Hackfest 2015 CTF.

This project supports simple (jeopardy) capture the flags (CTF) but could be updated to run King of the Hill or other kind of CTFs.

The objectives behind the project were performance and security. Ease of use was our last concern.

The project was built and tested with the following technologies:

* OpenBSD 5.8
* Python 3
* Tornado (Python 3 web framework)
* Postgresql 9.4.4 (Database)
* nginx 1.9.3 (Web server)

Improvements since 2014
-----------------------

The following features were developed for 2015 edition:

* New Dashboard
* Black Market
* Loto HF

The following upgrades were performed at the infrastructure level:

* Use of psycopg2 instead of py-postgresql library for DB queries
* SQL Query load balancer
* Postgresql Master-Slave databases

Architecture
---------------

The configuration during Hackfest was similar to the following diagram but note that it can be merged to a single VM.

![architecture](https://github.com/hackfestca/hfscoreboard/raw/master/docs/img/architecture2015.png)

Only the presentation server (nginx) was accessible from players. 

Components
----------

The scoreboard is made of 5 core components in order to initialize, manage, play and display a CTF. 

* DB initialization script
* Admin script
* Player's script
* Player's script API
* Player's Web Application
* [optional] Flag Updater
* [optional] Black Market Item Updater
* [optional] Loto HF Updater

By design, all components except the player script are considered "trusted" and connect directly to the database. User privileges are restricted (see security below). Players interact with the scoreboard via a web app or a web API. 


User Experience
===============

The command line interface let players submit and display scores from a shell. 

```
$ ./player.py score
[-] Displaying score
+-----+----+---------------------------------------+-------------+-----------+
| Pos | ID | TeamName                              |     Cash    | Notoriety |
+-----+----+---------------------------------------+-------------+-----------+
|  1  | 6  | BAISSEZ LE VOLUME!                    |  73000.00 $ |    5650   |
|  2  | 36 | Les amateurs de sécurité informatique |  31000.00 $ |    5250   |
|  3  | 10 | Catch Me If You Scan                  | 104000.00 $ |    4850   |
|  4  | 23 | Gentlemen en fête                     |  51000.00 $ |    4250   |
|  5  | 9  | Cascading Style Sheeps                |  81000.00 $ |    3350   |
|  6  | 13 | DCI1                                  |  54000.00 $ |    3350   |
|  7  | 24 | Gliderous Tigers                      |  19000.00 $ |    3350   |
|  8  | 32 | Hopeless                              |  66000.00 $ |    3250   |
|  9  | 45 | Shell Hero                            |  54000.00 $ |    3250   |
|  10 | 53 | Unicorn as a Software                 |  67000.00 $ |    3150   |
|  11 | 19 | error404                              |  1000.00 $  |    3150   |
|  12 | 2  | 0-bae                                 |  67000.00 $ |    3100   |
|  13 | 29 | Hackable Team                         |  66000.00 $ |    3050   |
|  14 | 44 | Rootmont                              |  60000.00 $ |    2950   |
|  15 | 54 | Usedoils                              |  21000.00 $ |    2450   |
|  16 | 1  | _TMIH_                                |  3000.00 $  |    2350   |
|  17 | 51 | tinker^or^die                         |  45000.00 $ |    2250   |
|  18 | 52 | Unicorn as a Service                  |  57000.00 $ |    2200   |
|  19 | 31 | Helixors                              |  38000.00 $ |    2200   |
|  20 | 8  | BonziBuddy                            |  46000.00 $ |    2050   |
|  21 | 21 | Flag Spoofing                         |  9000.00 $  |    1700   |
|  22 | 47 | SPY VS CAT4                           |  3000.00 $  |    1650   |
|  23 | 25 | Gugfull                               |  41000.00 $ |    1600   |
|  24 | 37 | More Violent Python                   |    0.00 $   |    1600   |
|  25 | 49 | The one who listens to bob and alice  |  30000.00 $ |    1550   |
|  26 | 35 | Kevin. Stuart. Bob & friends          |  29000.00 $ |    1550   |
|  27 | 46 | Sniff my packets                      |  26000.00 $ |    1550   |
|  28 | 27 | h4ck1ng team                          |  7000.00 $  |    1500   |
|  29 | 39 | Over the rainbow Table                |  35000.00 $ |    1450   |
|  30 | 55 | Venom                                 |  30000.00 $ |    1450   |
|  31 | 4  | admin:admin                           |  6000.00 $  |    1450   |
|  32 | 38 | Nop Slider                            |  32000.00 $ |    1300   |
|  33 | 5  | ASP. Hack                             |  25000.00 $ |    1300   |
|  34 | 18 | Domain Uncontroled                    |  1000.00 $  |    1300   |
|  35 | 28 | Hack to the metal                     |  29000.00 $ |    1250   |
|  36 | 43 | Raven                                 |  14000.00 $ |    1250   |
|  37 | 17 | dnk                                   |  31000.00 $ |    1200   |
|  38 | 40 | PolyHack                              |  30000.00 $ |    1200   |
|  39 | 50 | The root is on fire                   |  24000.00 $ |    1200   |
|  40 | 41 | PolyHack2                             |  26000.00 $ |    1050   |
|  41 | 14 | DCI2                                  |  24000.00 $ |    950    |
|  42 | 34 | Keep Calm and Craic On                |  21000.00 $ |    950    |
|  43 | 30 | hackademic                            |  16000.00 $ |    750    |
|  44 | 26 | Gugless                               |  17000.00 $ |    700    |
|  45 | 22 | furious bastard and Geekinfinity      |  13000.00 $ |    600    |
|  46 | 15 | DCI3                                  |  20000.00 $ |    550    |
|  47 | 48 | Tchoupi & Doudou                      |  11000.00 $ |    300    |
|  48 | 11 | Collège Shawinigan                    |  11000.00 $ |    300    |
|  49 | 12 | Coprolite                             |  6000.00 $  |    250    |
|  50 | 42 | Port Smasher                          |  2000.00 $  |    250    |
|  51 | 3  | A Laval Mon Shell                     |  6000.00 $  |    150    |
|  52 | 33 | JDIs                                  |  3000.00 $  |    100    |
|  53 | 7  | Beer Overflow                         |  1000.00 $  |     0     |
|  54 | 20 | ESC-CRAC                              |  1000.00 $  |     0     |
|  55 | 16 | DevQc                                 |  1000.00 $  |     0     |
+-----+----+---------------------------------------+-------------+-----------+
```

The web interface let players submit and display scores but also shows live progression, which can be useful for projectors.

![dashboard](https://github.com/hackfestca/hfscoreboard/raw/master/docs/img/dashboard2015.png)


Install
=======

This procedure will describe a three(3) tier architecture but all steps can be done on a single box. Let's say we have the following topology:

* 2x Web presentation servers at 172.28.71.11-12, resolving to scoreboard.hf (cyclic round robin)
* 2x Web application servers at 172.28.70.22-23, resolving to sb-app01.hf and sb-app02.hf
* A database pooler server at 172.28.70.21, resolving to sb-db00.hf
* 2x database servers at 172.28.70.19-20, resolving to sb-db01.hf and sb-db02.hf
* Admins are in 172.16.66.0/24

You can change DNS names and IPs as you wish.

1. Install three(3) VMs with the latest version of [OpenBSD][openbsd]. Default config with no GUI will do. Increase the `var` partition if you plan to have a lot of logs (a lot of players, bruteforce, several binaries to download, etc.)
  
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
 Then, clone this git project in sb's home.
    ```bash
    su - sb
    git clone https://github.com/hackfestca/hfscoreboard
    ```

3. [On sb-db01.hf and sb-db02.hf] Generate a CA, generate a signed server certificate for the database and then 4 client certificates for different components. A simple way to generate certificates is to customize certificate properties in the `sh/cert/openssl.cnf` config file and then run the `sh/cert/gencert.sh` script. If you plan to use passwords instead, skip this step.

    ```bash
    cd sh/cert
    ./gencert.sh
    ```
 Copy the database certificate and key file to postgresql folder
    ```bash
    mkdir /var/postgresql/data/certs
    cp srv.psql.scoreboard.db.{crt,key} /var/postgresql/data/certs/
    ```
 Copy the flagUpdater certificate and key file to certs folder
    ```bash
    cp cli.psql.scoreboard.db.{crt,key} /home/sb/hfscoreboard/certs/
    ```
 Upload the web certificate and key file to sb-app
    ```bash
    scp cli.psql.scoreboard.web.{crt,key} root@sb-app01.hf:/home/sb/scoreboard/certs/
    ssh root@sb-app01.hf chown sb:sb /home/sb/scoreboard/certs/cli.psql.scoreboard.web.{crt,key}
    ```
 Upload the player certificate and key file to scoreboard.hf
    ```bash
    scp cli.psql.scoreboard.player.{crt,key} root@scoreboard.hf:/home/sb/scoreboard/certs/
    ssh root@scoreboard.hf chown sb:sb /home/sb/scoreboard/certs/cli.psql.scoreboard.player.{crt,key}
    ```

4. [On sb-db01.hf and sb-db02.hf] Install and configure postgresql

    ```bash
    pkg_add postgresql-server
    pkg_add postgresql-contrib    # for pgcrypto
    mkdir -p /var/postgresql/data
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

 Edit `/var/postgresql/data/pg_hba.conf` to configure database access. Don't forget to replace admin by your username. It should looks like this:
    ```
    hostssl scoreboard  owner       192.168.1.0/24         cert clientcert=1 
    hostssl scoreboard  admin       192.168.1.0/24         md5 
    hostssl scoreboard  flagupdater 172.28.0.10/32         cert clientcert=1
    hostssl scoreboard  web         172.28.0.11/32         cert clientcert=1 
    hostssl scoreboard  player      172.28.0.12/32         cert clientcert=1 
    ```
 Some useful rules for development purpose:
    ```
    hostssl scoreboard  flagupdater 192.168.1.0/24         cert clientcert=1
    hostssl scoreboard  player      192.168.1.0/24         cert clientcert=1 
    hostssl scoreboard  web         192.168.1.0/24         cert clientcert=1
    ```
 Then install ssh4py, to push new flags on challenges box using SSH but also black market items.
    ```bash
    git clone https://github.com/wallunit/ssh4py.git
    pkg_add libssh2-1.4.3
    cd /usr/local/include/python3.4m/
    ln -s ../libssh2.h libssh2.h 
    ln -s ../libssh2_sftp.h libssh2_sftp.h 
    ln -s ../libssh2_publickey.h libssh2_publickey.h 
    cd /root/ssh4py; python3.4 ./setup.py build; python3.4 ./setup.py install
    ```
 Edit `/var/postgresql/data/postgresql.conf` and set the following variables.
    ```
    listen_addresses = '172.28.0.10'
    ...
    ssl = on
    ssl_ciphers = 'DEFAULT:!LOW:!EXP:!MD5:@STRENGTH'
    ...
    ssl_cert_file = '/etc/ssl/srv.psql.scoreboard.db.crt' # (change requires restart)
    ssl_key_file = '/etc/ssl/srv.psql.scoreboard.db.key'  # (change requires restart)
    ssl_ca_file = '/etc/ssl/sb-ca.crt'        i           # (change requires restart)
    ...
    search_path = 'scoreboard'
    ...
    ```
 Restart postgresql
    ```bash
    /etc/rc.d/postgresql restart
    ```
5. [On sb-app] Install python dependencies

    ```bash
    pkg_add py3-pip py3-psycopg3 tornado
    pip install --upgrade pip
    ```
 Download the code from git
    ```bash
    cd /var/www
    git clone https://github.com/hackfestca/hfscoreboard scoreboard
    ```
 Download and install supervisor. This will be used to run the process as a service.
    ```bash
    pkg_add py-pip
    pip2.7 install --upgrade pip
    pkg_add supervisor
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
 Make a copy of config.default.py, name it config.py and customize it. Most important settings are `PLAYER_API_HOST` and `DB_HOST`
    ```bash
    cd hfscoreboard
    cp config.default.py config.py
    vim config.py
    ```
6. [On scoreboard.hf] Install nginx and python dependencies for player API

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

[openbsd]: http://www.openbsd.org


How to use
==========

Running the scoreboard
----------------------

[On sb-db01] You only need postgresql running with data initialized. Simply run `python3 ./initDB.py --all`

[On sb-app] Run `supervisorctl start all`

Initialize database
-------------------

You might want to configure categories, authors, flags and settings. To do so, edit `sql/data.sql` and run `initDB.py -d`. Important: This will delete all data.
    ```
    $ ./initDB.py -h
    usage: initDB.py [-h] [-v] [--debug] [--tables] [--functions] [--data]
                     [--flags] [--teams] [--black-market] [--security] [--all]
    
    HF Scoreboard database initialization script. Use this tool to create db
    structure, apply security and import data
    
    optional arguments:
      -h, --help          show this help message and exit
      -v, --version       show program's version number and exit
      --debug             Run the tool in debug mode
    
    Action:
      Select one of these action
    
      --tables, -t        Import structure only (tables and functions)
      --functions, -f     Import structure only (tables and functions)
      --data, -d          Import data only
      --flags, -l         Import flags only (from csv file: import/flags.csv)
      --teams, -e         Import teams only (from csv file: import/teams.csv)
      --black-market, -b  Import black market items (from csv file:
                          import/blackmarket.csv)
      --security, -s      Import security only
      --all, -a           Import all
    ```

Administer the CTF
------------------

Once data are initialized, several informations can be managed or displayed using `admin.py`. Note that every positional arguments have a sub-help page.

    ```
    $ ./admin.py -h
    usage: admin.py [-h] [-v] [--debug]
                    {team,news,flag,bm,cash,settings,score,stat,events,bench,conbench,security}
                    ...
    
    HF Scoreboard admin client. Use this tool to manage the CTF
    
    positional arguments:
      {team,news,flag,bm,cash,settings,score,stat,events,bench,conbench,security}
        team                Manage teams.
        news                Manage news.
        flag                Manage flags.
        bm                  Manage black market items.
        cash                Manage cash (wallet and loto).
        settings            Manage game settings.
        score               Print score table (table, matrix).
        stat                Display game stats, progression, history
        events              Display game events.
        bench               Benchmark some db stored procedure.
        conbench            Benchmark some db stored procedure using multiple
                            connections.
        security            Test database security.
    
    optional arguments:
      -h, --help            show this help message and exit
      -v, --version         show program's version number and exit
      --debug               Run the tool in debug mode
    ```

Play the CTF
------------

Players can interact with the scoreboard using `player.py` script.

    ```
    $ ./player.py -h
    usage: player.py [-h] [-v] [--debug]
                     {submit,score,bm,loto,catProg,flagProg,news,info,secrets} ...
    
    HF Scoreboard player client. Use this tool to submit flags, display score, buy
    loto tickets and use the black market.
    
    positional arguments:
      {submit,score,bm,loto,catProg,flagProg,news,info,secrets}
        submit              Submit a flag
        score               Display score
        bm                  Manage black market items
        loto                Buy loto tickets. See information on drawing
        catProg             Display category progression
        flagProg            Display flag progression
        news                Display News
        info                Display team information and statistics
        secrets             Display team secrets
    
    optional arguments:
      -h, --help            show this help message and exit
      -v, --version         show program's version number and exit
      --debug               Run the tool in debug mode
    ```

Security
========

Some principle
--------------

* Never run a service as root
* For long time use, jail or chroot it
* Certs > Passwords

Use user/pass authentication instead
------------------------------------

Most authentication are made using client certificates. To change authentication scheme:

1. Open `/var/postgresql/data/pg_hba.conf` on the database server.
2. Find line corresponding to the user you want to change. For example:

    ```
    hostssl scoreboard  player      172.28.71.11/32         cert clientcert=1 
    ```
3. Replace `cert clientcert=1` to `md5` so it looks like:

    ```
    hostssl scoreboard  player      172.28.71.11/32         md5
    ```
4. Restart database: `/etc/rc.d/postgresql restart`

Enable TLS
----------

Warning: The `player.py` script do not support SSL if the version of python is lower than 3.4. For now, HTTP and HTTPS should both be supported on the nginx. 

1. To enable TLS on the web server, first generate a CSR and sign it by an authority.
2. Add these lines to your nginx server configuration and replace `listen 80` to `listen 443`.

    ```
    ssl                  on;
    ssl_certificate      /etc/ssl/scoreboard.crt;
    ssl_certificate_key  /etc/ssl/scoreboard.key;
    ssl_session_timeout  5m;
    ssl_session_cache    shared:SSL:10m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers "HIGH:!aNULL:!MD5 or HIGH:!aNULL:!MD5:!3DES";
    ```
3. Add this section if you wish to redirect port 80 to 443.

    ```
    server {
        listen  80;
        return  301 https://$host$request_uri;
    }
    ```
4. To enable HSTS, add this line.

    ```
    add_header Strict-Transport-Security "max-age=2678400; includeSubdomains;";
    ```

Database replication
--------------------

1. Clone sb-db01.hf or make a fresh install of a primary database.
2. On the primary database, configure the following variables.

    ```
    wal_level = hot_standby
    ...
    max_wal_senders = 3
     ```   
 Then add this to pg_hba.conf

    ```
    host    replication     all             172.28.70.19/32         trust
    ```
3. On secondary database, configure the following variables.

    ```
    hot_standby = on
    ```

Application Load Balancing and Fail Over
----------------------------------------

You might need to update code during a CTF, thus cause a downtime by restarting application server. Also, on high load, the web tier is the second buttle neck after the database. Spreading the web VMs on multiple hosts can enhance performance. 

To configure web load balancing, clone the web server or make a fresh install using previous steps. Then, in the upstream block, append server lines as described here.

    upstream backends{
        server 172.28.0.11:5000;
        server 172.28.0.21:5000;
    }

To avoid downtime, configure a backup upstream. This will cause connection failures on primary servers to be sent on the backup server. To do so, simply append `backup` to a server line.

    upstream backends{
        server 172.28.0.11:5000;
        server 172.28.0.21:5000;
        server 172.28.0.31:5000 backup;
    }

Hardening
---------

TBD


Optimization
============

Login Class
-----------

On heavy load, this setup on OpenBSD for presentation and application tier may raise "too many opened files" errors. This can be fixed by creating a login class with specific properties in `/etc/login.conf`. Simply append the following lines:

    hfscoreboard:\
        :datasize=infinity:\
        :maxproc=infinity:\
        :maxproc-max=512:\
        :maxproc-cur=256:\
        :openfiles=20000:

Then, set the login class to the user.

    usermod -L hfscoreboard sb

Kernel settings
---------------

Under load, you might have this error:

    FATAL:  remaining connection slots are reserved for non-replication superuser connections

According to: http://www.postgresql.org/docs/9.0/static/kernel-resources.html, several fields must be updated.

To update sysctl configs, you can start by appending the relevant fields to the /etc/sysctl.conf file as follow:

    sysctl | egrep -e 'shminfo|seminfo' >> /etc/sysctl.conf

For Hackfest 2015, the following:

    kern.seminfo.semmni=10
    kern.seminfo.semmns=60
    kern.seminfo.semmnu=30

was changed to to:

    kern.seminfo.semmni=64
    kern.seminfo.semmns=512
    kern.seminfo.semmnu=256

Static files caching
--------------------

Ngninx handle much faster static files than a python application. To let nginx handle static files, create a location for URI `/static` by adding the following lines to nginx server configuration.

    location /static {
        alias /var/www/htdocs/static;
        proxy_cache hf;
        proxy_cache_lock on;
        proxy_cache_methods GET HEAD;
        proxy_cache_valid 200 60;
    }

Flags & Teams management
------------------------

The `initDB.py` script let database owner import flags and teams from CSV files. Use google spreadsheet to write flags at a central location so multiple admins can prepare their flags before the CTF. On a regular basis, export the spreadsheet in CSV format, move it to `import/flags.csv` and import flags by running `python3.3 ./initDB --flags`. The same procedure apply for teams.


Docs
====

If you are interested to know more about the code, the documentation is in *docs/* folder, generated with epydoc.

It is also accessible [here][hfdoc].

[hfdoc]: http://htmlpreview.github.io/?https://github.com/hackfestca/hfscoreboard/blob/master/docs/index.html


Contributors
============

This scoreboard was written by Martin Dubé (mdube) and \_eko for Hackfest 2014 and updated since (See http://www.hackfest.ca/ctf2015). However, a lot of ideas and tests were made by the Hacking Games team. Special thanks to FLR and Cechaput for trying to break it before the CTF. :)

For any comment, questions, insult: martin d0t dube at hackfest d0t ca. 


License
=======

Modified BSD License

