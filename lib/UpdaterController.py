#!/usr/bin/python
# -*- coding: utf-8 -*-

'''
Flag updater controller class used by flagUpdater.py

@author: Martin Dubé
@organization: Hackfest Communications
@license: Modified BSD License
@contact: martin.dube@hackfest.ca

Copyright (c) 2015, Hackfest Communications
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'''

import config
import ClientController
import socket
import libssh2
import os
from subprocess import call

class UpdaterController(ClientController.ClientController):
    """
    Updater controller class used by FlagUpdaterController, InitController and more.
    """
    _sSSHUser = None
    _sSSHPubKey = None
    _sSSHPrivKey = None
    _sSSHPrivKeyPwd = None

    def __init__(self):
        super().__init__()

    def _localExec(self,cmd):
        print('[+] Executing: %s' % cmd)
        if cmd != '':
            return call(cmd.split())
        else:
            return -1

    def _remoteExec(self,host,cmd):
        try:
            if self._bDebug:
                print('[+] Connecting to %s' % host)
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((host, 22))
            
            session = libssh2.Session()
            session.startup(sock)

            #session.userauth_password('john', '******')
            session.userauth_publickey_fromfile(self._sSSHUser, \
                                                self._sSSHPubKey, \
                                                self._sSSHPrivKey, \
                                                self._sSSHPrivKeyPwd)
            channel = session.channel()
            channel.execute(cmd)
            if self._bDebug:
                print('[+] Debug: SSH cmd output: '+str(channel.read(1024)))
        except socket.error as e:
            return (1,e)
        except libssh2.Error as e:
            return (1,e)

        return (0,None)

    def _remoteGet(self,host,src,dst):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((host, 22))
        
        session = libssh2.Session()
        session.startup(sock)
        
        session.userauth_publickey_fromfile(self._sSSHUser, \
                                            self._sSSHPubKey, \
                                            self._sSSHPrivKey, \
                                            self._sSSHPrivKeyPwd)

        (channel, (st_size, _, _, _)) = session.scp_recv(src, True)
        fhDst = open(dst, 'wb')
        
        got = 0
        while got < st_size:
            data = channel.read(min(st_size - got, 1024))
            got += len(data)
            fhDst.write(data)
        
        exitStatus = channel.get_exit_status()
        channel.close()

    def _remotePut(self,host,src,dst):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((host, 22))
        
        session = libssh2.Session()
        session.startup(sock)
        
        session.userauth_publickey_fromfile(self._sSSHUser, \
                                            self._sSSHPubKey, \
                                            self._sSSHPrivKey, \
                                            self._sSSHPrivKeyPwd)

        fhSrc = open(src, 'rb')
        channel = session.scp_send(dst,0o660, os.stat(src).st_size)
       
        while True:
            data = fhSrc.read(4096)
            if not data:
                break
            channel.write(data)
 
        exitStatus = channel.get_exit_status()
        channel.close()

    def _uploadBMItemOnScoreboard(self,bmiImportName,privateId):
        bmiLocalPath = config.BMI_LOCAL_PATH + '/' + bmiImportName
        # Send on web servers
        bmiRemotePath = config.BMI_REMOTE_PATH + '/' + privateId
        for host in config.BMI_HOSTS:
            print('[+] Uploading %s on %s' % (privateId,host))
            self._remotePut(host,bmiLocalPath,bmiRemotePath)

    def _removeBMItemFromScoreboard(self,privateId):
        bmiRemotePath = config.BMI_REMOTE_PATH + '/' + privateId
        cmd = 'rm '+bmiRemotePath
        for host in config.BMI_HOSTS:
            self._remoteExec(host,cmd)
            print('[+] Removing %s on %s' % (privateId,host))

    def _updateBMItemStatus(self,bmItemId,statusCode):
        return self._exec('setBMItemStatus(integer,integer)',bmItemId,statusCode)

    def _getBMItemPrivateId(self,bmItemId):
        return self._exec('getBMItemPrivateId(integer)',bmItemId)

