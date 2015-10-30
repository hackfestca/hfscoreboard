#!/bin/ksh
# Script to configure the scoreboard database

# Install postgresql
pkg_add postgresql-server
pkg_add postgresql-contrib-9.3.2 # for pgcrypto
mkdir -p /var/postgresql/data
su - _postgresql
initdb -D /var/postgresql/data
/etc/rc.d/postgresql restart

# Install pip 
#curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
#python3.3 get-pip.py
pkg_add py3-pip
pip install --upgrade pip

# Install supervisor
pkg_add py-pip
pip2.7 install --upgrade pip
pkg_add supervisor

# Install postgresql
#pip install py-postgresql

# Install psycopg2
pkg_add py3-psycopg3

# Install tornado (needed for scoreboard.py only)
pip install tornado

# Install ascii_graph (needed for admin.py only)
pip install ascii_graph

# Install ssh4py (needed for flagUpdater.py only)
git clone https://github.com/wallunit/ssh4py.git
pkg_add libssh2-1.4.3
cd /usr/local/include/python3.4m/
ln -s ../libssh2.h libssh2.h 
ln -s ../libssh2_sftp.h libssh2_sftp.h 
ln -s ../libssh2_publickey.h libssh2_publickey.h 
cd /root/ssh4py; python3.4 ./setup.py build; python3.4 ./setup.py install

