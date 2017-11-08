# HF 2017 Scoreboard

This is the scoreboard used for the Hackfest 2017 CTF.

This project supports simple (jeopardy) capture the flags (CTF) but could be updated to run King of the Hill or other kind of CTFs.

The objectives behind the project were performance and security. Ease of use was our last concern.

The project was first built to run on OpenBSD but Hackfest 2017 scoreboard ran on Arch Linux. The project uses the following technologies:

* Python 3
* Tornado (Python 3 web framework)
* Postgresql 9.6.5 (Database)
* nginx 1.12.2 (Web server)


## Components

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


## User Experience

The command line interface let players submit and display scores from a shell. 

```
$ ./admin.py score
[+] Displaying score (top 300)
+-----+----+-----------------------------------------------------------+-------+
| Pos | ID | TeamName                                                  | Flags |
+-----+----+-----------------------------------------------------------+-------+
|  1  | 23 | Full Stack Deep Learning AI Cloud Blockchain as a Service | 6425  |
|  2  | 66 | unicorn as a software                                     | 3675  |
|  3  | 27 | Gliderous Tigers                                          | 3545  |
|  4  | 20 | ÉTS qui fax                                               | 2770  |
|  5  | 29 | Golden Ticket or GTFO                                     | 2700  |
|  6  | 10 | Bro Security                                              | 2625  |
|  7  | 65 | Unicorn As A Service                                      | 2150  |
|  8  | 51 | Paumd                                                     | 2100  |
|  9  | 53 | PolyHx1                                                   | 1810  |
|  10 | 15 | Click here to remove your virus                           | 1800  |
|  11 | 67 | Unik                                                      | 1720  |
|  12 | 13 | Ced Chaput groupies                                       | 1655  |
|  13 | 31 | Hackfesse                                                 | 1650  |
|  14 | 14 | CFIni_on_a_tous_les_flags                                 | 1640  |
|  15 | 9  | BoisEnPlus                                                | 1630  |
|  16 | 45 | No C# Allowed                                             | 1370  |
|  17 | 52 | Police nationale                                          | 1360  |
|  18 | 42 | Magic brainstorm                                          | 1325  |
|  19 | 59 | sweet/sucré                                               | 1300  | 
...
```

The web interface let players submit and display scores but also shows live progression, which can be useful for projectors.

![dashboard](https://github.com/hackfestca/hfscoreboard/raw/master/docs/img/dashboard2017.png)


## Install

* [OpenBSD](https://github.com/hackfestca/hfscoreboard/tree/master/sh/openbsd_install)
* [Arch Linux](https://github.com/hackfestca/hfscoreboard/tree/master/sh/arch_install)


## How to use

### Initialize database

You might want to configure categories, authors, flags and other settings. 

To do so, edit `sql/data.sql`, update files in `import/` and run `initDB.py -d`. Important: This will delete all data.

```
./initDB.py -h
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

### Administer the CTF

Once data are initialized, several informations can be managed or displayed using `admin.py`. Note that every positional arguments have a sub-help page.

 ```
./admin.py -h
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

### Play the CTF

Players can interact with the scoreboard using `player.py` script.

```
./player.py -h
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


## Security

### Some principle

* Never run a service as root
* For long time use, jail or chroot it
* Certs > Passwords

### Use user/pass authentication

Most authentication are made using client certificates. To change authentication scheme:

1. Open `/var/postgresql/data/pg_hba.conf` on the database server.
2. Find line corresponding to the user you want to change. For example:
    ```
    hostssl scoreboard  player      172.28.70.21/32         cert clientcert=1 
    ```
3. Replace `cert clientcert=1` to `md5` so it looks like:
    ```
    hostssl scoreboard  player      172.28.70.21/32         md5
    ```
4. Restart database: `/etc/rc.d/postgresql restart`


### Enable TLS

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

### Database replication

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


## Optimization

### Login Class

On heavy load, this setup on OpenBSD for presentation and application tier may raise "too many opened files" errors. This can be fixed by creating a login class with specific properties in `/etc/login.conf`. Simply append the following lines:

    hfscoreboard:\
        :datasize=infinity:\
        :maxproc=infinity:\
        :maxproc-max=512:\
        :maxproc-cur=256:\
        :openfiles=20000:

Then, set the login class to the user.

    usermod -L hfscoreboard sb

### Kernel settings

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

### Static files caching

Ngninx handle much faster static files than a python application. To let nginx handle static files, create a location for URI `/static` by adding the following lines to nginx server configuration.

    location /static {
        alias /var/www/htdocs/static;
        proxy_cache hf;
        proxy_cache_lock on;
        proxy_cache_methods GET HEAD;
        proxy_cache_valid 200 60;
    }

### Flags & Teams management

The `initDB.py` script let database owner import flags and teams from CSV files. Use google spreadsheet to write flags at a central location so multiple admins can prepare their flags before the CTF. On a regular basis, export the spreadsheet in CSV format, move it to `import/flags.csv` and import flags by running `python3.3 ./initDB --flags`. The same procedure apply for teams.


## Benchmark

This is what it looks like in action. 1k requests, from 20 clients, are sent on the index page are sent in 50 seconds using `ab -n 1000 -c 20 https://scoreboard.hf/`. No cache was used.

![benchmark](https://github.com/hackfestca/hfscoreboard/raw/master/docs/img/benchmark2015.png)


## Docs

If you are interested to know more about the code, the documentation is in *docs/* folder, generated with epydoc.

It is also accessible [here][hfdoc].

[hfdoc]: http://htmlpreview.github.io/?https://github.com/hackfestca/hfscoreboard/blob/master/docs/index.html


Contributors
============

This scoreboard was written by Martin Dubé (mdube) and \_eko for Hackfest 2014 and was updated since. Hackfest 2017 used this scoreboard. It is worth mentionning that a lot of ideas and tests were made by the Hacking Games team. Special thanks to Corb3nik, FLR and Cechaput for the thorough testing every years. :)

For any comment, questions, insult: martin d0t dube at gmail d0t com. 


License
=======

Modified BSD License
