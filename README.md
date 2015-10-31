HF 2014 Scoreboard
==================

This is the scoreboard used for the Hacking Games at Hackfest 2014. 

This project supports simple (jeopardy) capture the flags (CTF) or King of the Hill CTF. 

The objectives behind the project were performance and security. Ease of use was our last concern.

The project was built and tested with the following technologies:

* OpenBSD 5.5
* Python 3
* Tornado (Python 3 web framework)
* Postgresql 9.3 (Database)
* nginx 1.5.7 (Web server)


Architecture
------------

The configuration during Hackfest was similar to the following diagram but note that it can be merged to a single VM.

![architecture](https://github.com/hackfestca/hfscoreboard/raw/master/docs/img/architecture.png)

Only the presentation server (nginx) was accessible from players. 

Components
----------

The scoreboard is made of 6 components in order to initialize, manage, play and display a CTF. 

* DB initialization script
* Admin script
* Player script
* Player API
* Flag updater
* Web scoreboard

By design, all components except the player script are considered "trusted" and connect directly to the database. User privileges are restricted (see security below). Players interact with the scoreboard via a web app or a web API. 


User Experience
===============

The command line interface lets players submit and display scores from a shell. 

```
$ ./player.py --score
Displaying score (top 30)
+----+-----------------------------+---------+-------------+-------+
| ID | TeamName                    | FlagPts | FlagInstPts | Total |
+----+-----------------------------+---------+-------------+-------+
| 3  | return ENEEDGIN;            |  10675  |     1660    | 12335 |
| 14 | l33tb33s                    |   9825  |      0      |  9825 |
| 4  | DCIETS                      |   8800  |     226     |  9026 |
| 23 | BonziBuddy                  |   6400  |      0      |  6400 |
| 11 | Good Work IOIextreme        |   6000  |     212     |  6212 |
| 2  | _TMIH_                      |   5925  |      0      |  5925 |
| 19 | Relentless Penguin Uprising |   5900  |      0      |  5900 |
| 10 | GLO in the dark             |   5250  |      0      |  5250 |
| 6  | Shellbleedoodleshock        |   5175  |      0      |  5175 |
| 12 | crackmayorsecurity          |   5150  |      0      |  5150 |
| 13 | In the middle man           |   4675  |      0      |  4675 |
| 17 | PolyHack                    |   4550  |      0      |  4550 |
| 25 | Unicorn as a service        |   4350  |      0      |  4350 |
| 9  | Flaggots                    |   4175  |      0      |  4175 |
| 22 | Shell investigator          |   3825  |      0      |  3825 |
| 18 | Quick Overflow              |   2975  |      0      |  2975 |
| 26 | Freethinker1                |   2950  |      0      |  2950 |
| 28 | usedoils                    |   2875  |      0      |  2875 |
| 7  | Eliteroot                   |   2750  |      0      |  2750 |
| 15 | Packet Drop                 |   2725  |      0      |  2725 |
| 24 | thinker^or^die              |   2650  |      0      |  2650 |
| 27 | Freethinker2                |   2300  |      0      |  2300 |
| 5  | Hack ULaval                 |   2150  |      0      |  2150 |
| 21 | Sea and Tea                 |   1050  |      0      |  1050 |
| 8  | EMTA XIDLESYC GODS !        |   450   |      0      |  450  |
| 20 | @dminPr0tect n friends      |   450   |      0      |  450  |
| 1  | Team HF Crew                |    25   |      0      |   25  |
| 16 | Ping Master                 |    0    |      0      |   0   |
| 29 | Team Dube                   |    0    |      0      |   0   |
| 30 | Team HF DMZ                 |    0    |      0      |   0   |
+----+-----------------------------+---------+-------------+-------+
```

The web interface lets players submit and display scores but also shows live progression, which can be useful for projectors.

![dashboard](https://github.com/hackfestca/hfscoreboard/raw/master/docs/img/dashboard.png)


Install
=======

This procedure will describe a three(3) tier architecture but all steps can be done on a single box. Let's say we have the following topology:

* A web presentation server at 172.28.0.12, resolving to scoreboard.hf
* A web application server at 172.28.0.11, resolving to web.hf
* A database server at 172.28.0.10, resolving to db.hf
* Admins are in 192.168.1.0/24

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

3. [On db.hf] Generate a CA, generate a signed server certificate for the database and then 4 client certificates for different components. A simple way to generate certificates is to customize certificate properties in the `sh/cert/openssl.cnf` config file and then run the `sh/cert/gencert.sh` script. If you plan to use passwords instead, skip this step.

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
 Upload the web certificate and key file to web.hf
    ```bash
    scp cli.psql.scoreboard.web.{crt,key} root@web.hf:/home/sb/scoreboard/certs/
    ssh root@web.hf chown sb:sb /home/sb/scoreboard/certs/cli.psql.scoreboard.web.{crt,key}
    ```
 Upload the player certificate and key file to scoreboard.hf
    ```bash
    scp cli.psql.scoreboard.player.{crt,key} root@scoreboard.hf:/home/sb/scoreboard/certs/
    ssh root@scoreboard.hf chown sb:sb /home/sb/scoreboard/certs/cli.psql.scoreboard.player.{crt,key}
    ```
 Finally, upload `cli.psql.scoreboard.owner.{crt,key}` files on your machine and/or to certs folder to manage database from db.hf
    ```bash        
    cp cli.psql.scoreboard.owner.{crt,key} /home/sb/hfscoreboard/certs/
    ```

4. [On db.hf] Install and configure postgresql

    ```bash
    pkg_add postgresql-server
    pkg_add postgresql-contrib-9.3.2 # for pgcrypto
    mkdir -p /var/postgresql/data
    su - _postgresql
    postgres -D /var/postgresql/data
    exit
    /etc/rc.d/postgresql restart
    ```
 Create database (see `sql/install.sql`)
    ```sql
    -- DB Creation (owner role + schema + extension + db)
    CREATE ROLE owner LOGIN INHERIT;
    CREATE DATABASE scoreboard WITH OWNER owner ENCODING 'UTF-8' TEMPLATE template0;
    #\c scoreboard;
    
    CREATE SCHEMA IF NOT EXISTS scoreboard AUTHORIZATION owner;
    CREATE SCHEMA IF NOT EXISTS pgcrypto AUTHORIZATION owner;
    CREATE SCHEMA IF NOT EXISTS tablefunc AUTHORIZATION owner;
    CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA pgcrypto;
    CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA tablefunc;
    GRANT CONNECT ON DATABASE scoreboard TO owner;
    
    -- Modify default privileges
    ALTER DEFAULT PRIVILEGES IN SCHEMA scoreboard REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC; 
    ALTER DEFAULT PRIVILEGES IN SCHEMA scoreboard REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC; 
    ALTER DEFAULT PRIVILEGES IN SCHEMA scoreboard REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC; 
    
    -- Access roles
    CREATE ROLE hfadmins NOINHERIT;     -- Admins 
    CREATE ROLE hfplayers NOINHERIT;    -- Players 
    CREATE ROLE hfscore NOINHERIT;      -- Scoreboard access
    CREATE ROLE hfflagupdater NOINHERIT;-- FlagUpdater access
    
    CREATE ROLE player LOGIN INHERIT PASSWORD 'player';
    CREATE ROLE web LOGIN INHERIT PASSWORD 'web';
    CREATE ROLE flagupdater LOGIN INHERIT PASSWORD 'flagUpdater';
    
    GRANT hfadmins to owner;
    GRANT hfplayers to player;
    GRANT hfscore to web;
    GRANT hfflagupdater to flagupdater;

    -- Create yourself a role here. Replace admin by something else on both lines
    CREATE ROLE admin LOGIN INHERIT PASSWORD '<CHANGE_ME>';
    GRANT hfadmins to admin;
    ```
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
 Then install ssh4py, needed for flagUpdater.py only, to push new flags on challenges box using SSH.
    ```bash
    git clone https://github.com/wallunit/ssh4py.git
    pkg_add libssh2-1.4.3
    cd /usr/local/include/python3.3m/
    ln -s ../libssh2_sftp.h libssh2_sftp.h 
    ln -s ../libssh2_sftp.h libssh2_sftp.h 
    cd /root/ssh4py; python3.2 ./setup.py build; python3.2 ./setup.py install
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
5. [On web.hf] Install python dependencies

    ```bash
    curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
    python3.3 get-pip.py
    pip install py-postgresql
    pip install tornado
    ```
 Download the code from git
    ```bash
    git clone https://github.com/hackfestca/hfscoreboard hfscoreboard
    ```
 Make a copy of config.default.py, name it config.py and customize it. Most important settings are `PLAYER_API_HOST` and `DB_HOST`
    ```bash
    cd hfscoreboard
    cp config.default.py config.py
    vim config.py
    ```
6. [On scoreboard.hf] Install nginx and python dependencies for player API

    ```bash
    pkg_add nginx-1.5.7
    mkdir /var/www/htdocs/public /var/www/htdocs/static
    curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
    python3.3 get-pip.py
    pip install py-postgresql
    ```
 Download the code from git
    ```bash
    git clone https://github.com/hackfestca/hfscoreboard hfscoreboard
    ```
 Make a copy of config.default.py and customize the config.py file. Most important settings are `PLAYER_API_HOST` and `DB_HOST`
    ```bash
    cd hfscoreboard
    cp config.default.py config.py
    vim config.py
    ```
 Then configure the web server to do reverse proxy to web.hf. You can also configure TLS, caching and static files handling (see below).
    ```
    upstream backends{
        server 172.28.0.11:5000;
    }
    
    # This should be on a ramfs
    proxy_cache_path /var/www/cache/responses levels=1:2 keys_zone=hf:10m;
    proxy_temp_path /var/www/cache/proxy_temp 1 2;

    server {
            listen       80;
            server_name  scoreboard.hf;
            server_name  172.28.0.12;
            root         /var/www/htdocs;
    
            location / {
                proxy_cache hf;
                proxy_cache_lock on;
                proxy_cache_key "$remote_addr$request_uri";
                proxy_cache_methods GET HEAD;
                proxy_cache_valid 404 16h;
                proxy_cache_valid 200 5;
        
                proxy_redirect off;
                proxy_pass_header Server;                       
                proxy_set_header Host $http_host;                       
                proxy_set_header X-Real-IP $remote_addr;                       
                proxy_set_header X-Scheme $scheme;                       
                proxy_pass http://backends;                       
                proxy_next_upstream error;
            }
    
            location /status {
                 stub_status on;
                 access_log   off;
                 allow 192.168.1.0/24;
                 deny all;
            }

            # Can be used for challenges and share your CA certificate.
            location /public {
                alias /var/www/htdocs/public;
                autoindex on;
            }
        
            location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico)$ {
                access_log        off;
                expires           max;
                add_header Pragma public;
                add_header Cache-Control "public, must-revalidate, proxy-revalidate";
            }
        
            location ~* \.(eot|ttf|woff)$ {
                    add_header Access-Control-Allow-Origin \*;
            }
        
            access_log  /var/log/nginx/scoreboard.access.log;
            error_log /var/log/nginx/scoreboard.error.log;
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
    }
    ```

[openbsd]: http://www.openbsd.org


How to use
==========

Running the scoreboard
----------------------

[On db.hf] You only need postgresql running with data initialized. Simply run `python3.3 ./initDB.py --all`

[On web.hf] As user scoreboard (in a tmux, ideally), run `python3.3 ./web.py`

[On scoreboard.hf] As user scoreboard (in a tmux, ideally), run `python3.3 ./player-api.py --start`

Initialize database
-------------------

You might want to configure categories, authors, flags and settings. To do so, edit `sql/data.sql` and run `initDB.py -d`. Important: This will delete all data.

    # ./initDB.py -h
    usage: initDB.py [-h] [-v] [--debug] [--tables] [--functions] [--data] [--flags] [--teams] [--security] [--all]
    
    HF Scoreboard database initialization script. Use this tool to create db structure, apply security and import data
    
    optional arguments:
      -h, --help       show this help message and exit
      -v, --version    show program's version number and exit
      --debug          Run the tool in debug mode
    
    Action:
      Select one of these action
    
      --tables, -t     Import structure only (tables and functions)
      --functions, -f  Import structure only (tables and functions)
      --data, -d       Import data only
      --flags, -l      Import flags only (from csv file:
                       import/flags.csv)
      --teams, -e      Import teams only (from csv file:
                       import/teams.csv)
      --security, -s   Import security only
      --all, -a        Import all

Administer the CTF
------------------

Once data are initialized, several informations can be managed or displayed using `admin.py`. Note that every positional arguments have a sub-help page.

    # ./admin.py -h
    usage: admin.py [-h] [-v] [--debug] {team,news,flag,settings,score,history,stat,bench,conbench,security} ...
    
    HF Scoreboard admin client. Use this tool to manage the CTF
    
    positional arguments:
      {team,news,flag,settings,score,history,stat,bench,conbench,security}
        team                Manage teams.
        news                Manage news.
        flag                Manage flags.
        settings            Manage game settings.
        score               Print score table (table, matrix).
        history             Print Submit History.
        stat                Display game stats.
        bench               Benchmark some db stored procedure.
        conbench            Benchmark some db stored procedure using multiple connections.
        security            Test database security.
    
    optional arguments:
      -h, --help            show this help message and exit
      -v, --version         show program's version number and exit
      --debug               Run the tool in debug mode

Play the CTF
------------

Players can interact with the scoreboard using `player.py` script.

    # ./player.py -h
    usage: player.py [-h] [-v] [--debug] [--submit FLAG] [--score] [--catProg] [--flagProg] [--news] [--info] [--top TOP] [--cat CAT]
    
    HF Scoreboard player client. Use this tool to submit flags and display score
    
    optional arguments:
      -h, --help            show this help message and exit
      -v, --version         show program's version number and exit
      --debug               Run the tool in debug mode
    
    Action:
      Select one of these action
    
      --submit FLAG, -s FLAG
                            Submit a flag
      --score               Display score
      --catProg, -c         Display category progression
      --flagProg, -f        Display flag progression
      --news, -n            Display news
      --info, -i            Display team information
    
    Option:
      Use any depending on choosen action
    
      --top TOP, -t TOP     Limit --score number of rows
      --cat CAT             Print results only for this category name

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

1. Clone db.hf or make a fresh install of a primary database.
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

TODO: Find a python postgresql spooler to support multiple database servers.

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

Core
----

On heavy load, this setup on OpenBSD for presentation and application tier may raise "too many opened files" errors. This can be fixed by creating a login class with specific properties in `/etc/login.conf`. Simply append the following lines:

    hfscoreboard:\
        :datasize=infinity:\
        :maxproc=infinity:\
        :maxproc-max=512:\
        :maxproc-cur=256:\
        :openfiles=20000:

Then, set the login class to the user.

    usermod -L hfscoreboard sb

Static files handling
---------------------

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

Database
--------

Under load, you might have this error:

    FATAL:  remaining connection slots are reserved for non-replication superuser connections

According to: http://www.postgresql.org/docs/9.0/static/kernel-resources.html, several fields must be updated.

To update sysctl configs, you can start by appending the relevant fields to the /etc/sysctl.conf file as follow:

    sysctl | egrep -e 'shminfo|seminfo' >> /etc/sysctl.conf

In my case, I changed:

    kern.seminfo.semmni=10
    kern.seminfo.semmns=60
    kern.seminfo.semmnu=30

to

    kern.seminfo.semmni=64
    kern.seminfo.semmns=512
    kern.seminfo.semmnu=256


Docs
====

If you are interested to know more about the code, the documentation is in *docs/* folder, generated with epydoc.

It is also accessible [here][hfdoc].

[hfdoc]: http://htmlpreview.github.io/?https://github.com/hackfestca/hfscoreboard/blob/master/docs/index.html


Contributors
============

This scoreboard was written by Martin Dubé (mdube) and \_eko for Hackfest 2014 (See http://www.hackfest.ca/hacking-games-2014). However, a lot of ideas and tests were made by the Hacking Games team. Special thanks to FLR and Cechaput for trying to break it before the CTF. :)

For any comment, questions, insult: martin d0t dube at hackfest d0t ca. 


License
=======

Modified BSD License
