HF 2014 Scoreboard
==================

This is the scoreboard used for Hacking Games at Hackfest 2014. 

This project support simple (jeopardy style) capture the flags (CTF) or King of the Hill style CTF. 

Objectives behind the project were: performance + security. Ease of use was our last concern. 

The project was build and test on the following technologies:

* OpenBSD 5.5
* Python 3
* Tornado (Python 3 web framework)
* Postgresql 9.3 (Database)
* nginx (Web server)


Architecture
------------

Setup during Hackfest was like the following diagram but it could run on a single VM. 

*INSERT DIAGRAM HERE*

Only presentation server (nginx) was accessible from players. 


Components
----------

The scoreboard is made of 6 components in order to initialize, manage, play and display a CTF. 

* DB initialization script
* Admin script
* Player script
* Player API
* Flag Updater
* Web scoreboard

By design, all components except the player script, connect directly to the database as they are considered "trusted" and user privileges are restricted (see security below). This should be considered in your architecture. 


Install
=======

The procedure will describe a three(3) tier architecture but all these steps can be done on a single box. Let's say we have the following topology:

 * A web presentation server at 172.28.0.12, resolving to scoreboard.hf
 * A web application server at 172.28.0.11, resolving to web.hf
 * A database server at 172.28.0.10, resolving to db.hf.
 * Admins are in 192.168.1.0/24.

You can change DNS names and IPs at your will.


1. Install three(3) VMs on latest version of [OpenBSD][openbsd]. Default config with no GUI will do. Increase the `var` partition if you plan to have a lot of logs (a lot of players?, bruteforce?, etc.).

    _It will work with another OS as long as you are resourceful :)_

2. Create a low privilege user on all VMs. Let's call it scoreboard.
    
        adduser scoreboard
        

2. [On db.hf] Generate a CA certificate which will be used for authorizations to database. If you plan to use passwords instead, skip this step.

        cd /etc/ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout postgres-server.key -out postgres-server.crt (TODO: test this)

    Generate CSR for all components and sign them on db.hf

        [On db.hf] Generate a certificate for user flagupdater
    
        [On web.hf] Generate a certificate for user web and copy it to db.hf
    
        [On scoreboard.hf] Generate a certificate for user player and copy it to db.hf
    
        [On your PC] Generate a certificate for user hfowner and copy it to db.hf
    
        [On db.hf] Sign the certificates
    
        Move the crt file back on the machines

3. [On db.hf] Install and configure postgresql

        pkg_add postgresql-server
        pkg_add postgresql-contrib-9.3.2 # for pgcrypto
        mkdir -p /var/postgresql/data
        su - _postgresql
        postgres -D /var/postgresql/data
        /etc/rc.d/postgresql restart

    Initialize database

        -- DB Creation (owner role + schema + extension + db)
        CREATE ROLE hfowner LOGIN INHERIT;
        CREATE DATABASE scoreboard WITH OWNER hfowner ENCODING 'UTF-8' TEMPLATE template0;
        \c scoreboard;
        
        CREATE SCHEMA IF NOT EXISTS scoreboard AUTHORIZATION hfowner;
        CREATE SCHEMA IF NOT EXISTS pgcrypto AUTHORIZATION hfowner;
        CREATE SCHEMA IF NOT EXISTS tablefunc AUTHORIZATION hfowner;
        CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA pgcrypto;
        CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA tablefunc;
        GRANT CONNECT ON DATABASE scoreboard TO hfowner;
        
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
        
        GRANT hfadmins to hfowner;
        GRANT hfplayers to player;
        GRANT hfscore to web;
        GRANT hfflagupdater to flagupdater;

        -- Create yourself a role here. Replace admin by something else on both lines
        CREATE ROLE admin LOGIN INHERIT PASSWORD '<CHANGE_ME>';
        GRANT hfadmins to admin;

    Edit `/var/postgresql/data/pg_hba.conf` to configure database access. Don't forget to replace admin by your username. It should looks like this:

        hostssl scoreboard  hfowner     192.168.1.0/24         cert clientcert=1 
        hostssl scoreboard  admin       192.168.1.0/24         md5 
        hostssl scoreboard  flagupdater 172.28.0.10/32         cert clientcert=1
        hostssl scoreboard  web         172.28.0.11/32         cert clientcert=1 
        hostssl scoreboard  player      172.28.0.12/32         cert clientcert=1 

    Some useful rules for development purpose:

        hostssl scoreboard  flagupdater 192.168.1.0/24         cert clientcert=1
        hostssl scoreboard  player      192.168.1.0/24         cert clientcert=1 
        hostssl scoreboard  web         192.168.1.0/24         cert clientcert=1

    Then install ssh4py, needed for flagUpdater.py only, to push new flags on challenges box using SSH.

        git clone https://github.com/wallunit/ssh4py.git
        pkg_add libssh2-1.4.3
        cd /usr/local/include/python3.3m/
        ln -s ../libssh2_sftp.h libssh2_sftp.h 
        ln -s ../libssh2_sftp.h libssh2_sftp.h 
        cd /root/ssh4py; python3.2 ./setup.py build; python3.2 ./setup.py install

    Edit `/var/postgresql/data/postgresql.conf` and set the following variables.

        listen_addresses = '172.28.0.10'
        ...
        ssl = on
        ssl_ciphers = 'DEFAULT:!LOW:!EXP:!MD5:@STRENGTH'
        ...
        ssl_cert_file = '/etc/ssl/postgresql-server.crt'       # (change requires restart)
        ssl_key_file = '/etc/ssl/postgresql-server.key'        # (change requires restart)
        ssl_ca_file = '/etc/ssl/scoreboard-root-ca.crt'        # (change requires restart)
        ...
        search_path = 'scoreboard'
        ...

    Restart postgresql

        /etc/rc.d/postgresql restart
        

4. [On web.hf] Install python dependencies

        curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
        python3.3 get-pip.py
        pip install py-postgresql
        pip install tornado

    Download the code from git

        git clone https://github.com/hackfestca/hf2k14-scoreboard hf2k14-scoreboard

    Make a copy of config.default.py and customize the config.py file. Most important settings are `PLAYER_API_HOST` and `DB_HOST`

        cd hf2k14-scoreboard
        cp config.default.py config.py
        vim config.py

5. [On scoreboard.hf] Install nginx and python dependencies for player API

        pkg_add nginx-1.5.7
        curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
        python3.3 get-pip.py
        pip install py-postgresql

    Download the code from git

        git clone https://github.com/hackfestca/hf2k14-scoreboard hf2k14-scoreboard

    Make a copy of config.default.py and customize the config.py file. Most important settings are `PLAYER_API_HOST` and `DB_HOST`

        cd hf2k14-scoreboard
        cp config.default.py config.py
        vim config.py

    Then configure the web server to do reverse proxy to web.hf. You can also configure TLS, caching and static files handling (see below).

        upstream backends{
         server 172.28.0.11:5000;
        }
        
        # This should be on a ramfs
        proxy_cache_path /var/www/cache/responses levels=1:2 keys_zone=hf:10m;
        proxy_temp_path /var/www/cache/proxy_temp 1 2;

        # Remove comments to force redirect to https        
        #server {
        #    listen  80;
        #    return  301 https://$host$request_uri;
        #}
        
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
            
                # Remove comments to let nginx handle static files. Make sure you have a copy first.
                #location /static {
                #    alias /var/www/htdocs/static;
                #    proxy_cache hf;
                #    proxy_cache_lock on;
                #    proxy_cache_methods GET HEAD;
                #    proxy_cache_valid 200 60;
                #}
            
                # Remove comments to let nginx handle public files (challenges). Make sure you have a copy first.
                #location /public {
                #    alias /var/www/htdocs/public;
                #    autoindex on;
                #}
            
                location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico)$ {
                    access_log        off;
                    expires           max;
                    add_header Pragma public;
                    add_header Cache-Control "public, must-revalidate, proxy-revalidate";
                }
            
                location ~* \.(eot|ttf|woff)$ {
                        add_header Access-Control-Allow-Origin *;
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
            
                # Remove comments to enable TLS
                #add_header Strict-Transport-Security "max-age=2678400; includeSubdomains;";
                #ssl                  on;
                #ssl_certificate      /etc/ssl/scoreboard.crt;
                #ssl_certificate_key  /etc/ssl/scoreboard.key;
                #ssl_session_timeout  5m;
                #ssl_session_cache    shared:SSL:10m;
                #ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
                #ssl_ciphers "HIGH:!aNULL:!MD5 or HIGH:!aNULL:!MD5:!3DES";
        }


7. 


[openbsd]: http://www.openbsd.org






How to use
==========

Setting up the main config file
-------------------------------

First, go to */etc/cnb*/ folder and copy the *cnb.conf.default* to *cnb.conf*. This is the main config
file. Most of this should not be changed, except for the **connectors** and 
**smtp** sections. Here is an example of a *cnb.conf* file. Simply fill the
<...> fields.

    [global]
    #root-dir = <string>  (dynamically added)
    #bin-dir = <string>  (dynamically added)
    #config-dir = <string> (dynamically added)
    #log-dir = <string>  (dynamically added)
    #tp-dir = <string>  (dynamically added)
    pid-file = <string>  (dynamically added if started as a daemon)
    version = 0.20
    log-format = %(asctime)s - %(name)s - %(levelname)s - %(message)s

    [connectors]
    auto = [freenode.irc.conf, gmail.xmpp.conf]
 
    [smtp]
    smtp-user = <an email address>
    smtp-pass = <a password>
    smtp-host = <a smtp server>
    smtp-port = <a smtp port>

As you can see in the **connectors** section, there are two more config files. 
These files contain all necessary information to connect a chat server.
The next section explain how to setup a connection config file. 


Setting up a connection config file
-----------------------------------

The bot will import files specified in *cnb.conf* file. Here's
the syntax of an IRC connection file. Again, simply fill the <...> fields. 

    | [bot]
    | type = irc
    | log-file = freenode.irc.log
    | username = <an irc username>
    | password = <a password>
    | server = <an irc server>
    | channels = [<a list of chan to connect (Syntax: chan:[password],...)>]
    | auto-join = 1
    | auto-start = 1
    | auto-reconnect = 1
    | verbose = 0
    | admins = [<a list of admins (Syntax: nick1,...). WARNING: THIS IS NOT SECURE>]

And this is a XMPP connection file

    | [bot]
    | #id = <int> (dynamically added)
    | #config-file = <string> (dynamically added)
    | #monday-suck-room = <string> (dynamically added)
    | type = xmpp|xmpp-gtalk  //xmpp for custom xmpp, xmpp-gtalk for gmail chat
    | log-file = gmail.xmpp.log
    | username = <insert username here>
    | password = <insert password here>
    | server = <overwrite only if the server can't be resolved from SRV lookup.
    | See <http://tools.ietf.org/html/rfc6120#section-3.2.1> >
    | rooms = [<a list of default rooms to join (Syntax: room1,...)>]
    | nickname = <insert nick name here>
    | auto-join = 1
    | auto-start = 1
    | auto-reconnect = 1
    | verbose = 0
    | admins = [<a list of admins (Syntax: email1,...)>]
    |
    | muc-domain = <insert muc domain here>


Running the bot
-----------------

It is recommended to start it as a shell script first to see any errors
and then start it as a service

To run the bot as a shell script:

    [/usr/local/bin/]cnb-cli [--help]

To run as a service:

    sudo /etc/init.d/cnb start|stop|restart|status


Security
========

Some principle
--------------

* Never run the bot as root
* For long time use, jail it on a VM
* Set up admin list correctly
    * You don't want anybody to run nmaps from your home?


Bot Hardening
-----------------

By default, running Chuck as a service will run it as the user "cnb". It 
is always a good idea to run the bot as a user with limited privileges.

Disabling modules can also reduce attack vectors. Disable modules by removing 
symbolic links in the cnb/modEnabled folder (apache style).


Use user/pass authentication instead
------------------------------------

Most authentication are made using client certificates. To change authentication scheme, 
1.  Open `/var/postgresql/data/pg_hba.conf` on the database server
2.  Find line corresponding to the user you want to change. For example:
        hostssl scoreboard  player      172.28.71.11/32         cert clientcert=1 
3.  Replace `cert clientcert=1` to `md5` so it looks like:
        hostssl scoreboard  player      172.28.71.11/32         md5


Enable TLS
----------



Enable HSTS
-----------


Database replication
--------------------

        host    replication     all             172.28.70.19/32         trust



Optimization
============

On heavy load, this setup on OpenBSD raise "too many opened files" errors. This can be fixed by 

Docs
====

If you are interested to know more about the code, the documentation is in 
*docs/* folder, generated with epydoc.

It is also accessible here: http://htmlpreview.github.io/?https://github.com/hackfestca/cnb/blob/master/docs/index.html


Contributors
============
This bot was created by Martin Dubé as a Hackfest Project (See:
http://hackfest.ca). Martin is not a developper but still the main collaborator and reviser.
Furthermore, a lot of ideas came from Hackfest crew and community.

For any comment, questions, insult: martin d0t dube at hackfest d0t com. 

Thanks also to
--------------
Authors and maintainers of the following projects, which make this bot fun and
useful:

* findmyhash
* Urban Dictionary
* nmap
* Trivia Game (vn at hackfest d0t ca)
* Python
* And every project I forgot

License
=======

Modified BSD License
