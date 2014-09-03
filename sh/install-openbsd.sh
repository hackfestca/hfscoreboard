#!/bin/ksh
# Script to configure mon2k14.hf

# Install postgresql
#pkg_add postgresql-server
#mkdir -p /var/postgresql/data
#su - _postgresql
#postgres -D /var/postgresql/data
#/etc/rc.d/postgresql restart

# Install pip 
curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
python3.3 get-pip.py

# Install flask (not used anymore)
#pip install Flask 

# Install tornado
pip install tornado

# Install postgresql
pip install py-postgresql

# Install ascii_graph (needed for admin.py only)
pip install ascii_graph

# Needed for updateFlag.py
# On debian: 
# git clone https://github.com/wallunit/ssh4py.git
# cd ssh4py; python3.2 ./setup.py build; python3.2 ./setup.py install
# aptitude install python3-pip
# aptitude install libssh2-1-dev
# pip install pylibssh2

# On OpenBSD
cd
git clone https://github.com/wallunit/ssh4py.git
pkg_add libssh2-1.4.3
cd /usr/local/include/python3.3m/
ln -s ../libssh2_sftp.h libssh2_sftp.h 
ln -s ../libssh2_sftp.h libssh2_sftp.h 
cd /root/ssh4py; python3.2 ./setup.py build; python3.2 ./setup.py install

