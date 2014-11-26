#!/bin/ksh
# Script to configure the scoreboard database

# Install postgresql
pkg_add postgresql-server
pkg_add postgresql-contrib-9.3.2 # for pgcrypto
mkdir -p /var/postgresql/data
su - _postgresql
postgres -D /var/postgresql/data
/etc/rc.d/postgresql restart

# Install pip 
curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
python3.3 get-pip.py

# Install postgresql
pip install py-postgresql

# Install tornado (needed for scoreboard.py only)
pip install tornado

# Install ascii_graph (needed for admin.py only)
pip install ascii_graph

# Install ssh4py (needed for flagUpdater.py only)
git clone https://github.com/wallunit/ssh4py.git
pkg_add libssh2-1.4.3
cd /usr/local/include/python3.3m/
ln -s ../libssh2_sftp.h libssh2_sftp.h 
ln -s ../libssh2_sftp.h libssh2_sftp.h 
cd /root/ssh4py; python3.2 ./setup.py build; python3.2 ./setup.py install

