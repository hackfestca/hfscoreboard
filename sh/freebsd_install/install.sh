#!/bin/sh

echo "This is currently just a command dump. Do not run blindly";
exit 1;

pkg install git-lite-2.12.1 python36 postgresql96-server-9.6.2 postgresql96-contrib-9.6.2 postgresql96-client-9.6.2

adduser sb
su - sb
git clone git@git.h0m3.lan:/scoreboard
cd scoreboard
pip3 install -r requirements.txt

# Edit postgresql to support unix sockets

# Edit the project to support unix socket

# Edit `sql/install.sql` with new passwords and run with
su - postgres
psql

# Add a symbolic link for python3
cd /usr/local/bin
ln -s python3.6 python3

# Then initialize the database
python3 ./initDB.py -a

mkdir /var/log/sb
chown root:sb /var/log/sb
chmod 770 /var/log/sb

# Install rc.d files
cp ./sh/freebsd_install/rc.d/sb* /etc/rc.d/
chmod 555 /etc/rc.d/sb*
