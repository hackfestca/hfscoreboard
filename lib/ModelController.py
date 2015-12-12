
from Crypto.Cipher import AES
from time import sleep
import binascii
import quick2wire.i2c as i2c
import quick2wire.spi as spi
import curses
import logging
import sys

import ClientController
import config

class ModelController(ClientController.ClientController):
    def initLogging(self):
        self.logger = logging.getLogger("model_logger")
        self.logger.setLevel(logging.INFO)

        formatter = logging.Formatter('%(asctime)s - %(message)s')

        ch = logging.StreamHandler(sys.stdout)
        ch.setLevel(logging.INFO)
        ch.setFormatter(formatter)

        info_file = logging.FileHandler("model.log", encoding="utf-8")
        info_file.setLevel(logging.INFO)
        info_file.setFormatter(formatter)

        self.logger.addHandler(ch)
        self.logger.addHandler(info_file)

    def _send_i2c(self,msg):
        with i2c.I2CMaster() as master:
            master.transaction(
                i2c.writing(self.i2cAddr, msg))
    

class CasinoController(ModelController):
    i2cAddr = 0x04

    def __init__(self):
        self.initLogging()

        self._sUser = config.DB_RPI_USER
        self._sPass = config.DB_RPI_PASS
        self._sCrtFile = config.DB_RPI_CRT_FILE
        self._sKeyFile = config.DB_RPI_KEY_FILE
        super().__init__()

    def updateCountDown(self):
        self.logger.info('Updating count down')
        cd = self._exec('getModelCountDown').encode('utf-8')
        self.logger.info('Received from DB: %s' % cd)
        self._send_i2c(b'c'+cd)
    
    def updateNews(self):
        for i in range(0,6):
            self.logger.info('Updating news[%s]' % i)
            news = self._exec('getModelNews',i).encode('utf-8')
            self.logger.info('Received from DB: %s' % news)
            self._send_i2c(b'n'+bytes([ord('%s' % i)])+news)
            sleep(1)
    
    def updateTopTeams(self):
        for i in range(0,3):
            self.logger.info('Updating Top Teams[%s]' % i)
            topTeams = self._exec('getModelTeamsTop',i).encode('utf-8')
            self.logger.info('Received from DB: %s' % topTeams)
            self._send_i2c(b't'+bytes([ord('%s' % i)])+topTeams)
            sleep(1)

    def drawFlag(self):
        self.logger.info('Drawing flag')
        self._send_i2c(b'f')
    
    
class PipelineController(ModelController):
    i2cAddr = 0x05

    def __init__(self):
        self.initLogging()

        self._sUser = config.DB_RPI_USER
        self._sPass = config.DB_RPI_PASS
        self._sCrtFile = config.DB_RPI_CRT_FILE
        self._sKeyFile = config.DB_RPI_KEY_FILE
        super().__init__()

    def getFlag(self,key):
        self._send_i2c(b'f'+key)
        sleep(1)
        # Get flag
        with i2c.I2CMaster() as master:
            encFlag = master.transaction(
                    i2c.reading(self.i2cAddr,16))[0]
            print('Encrypted Flag: %s' % encFlag)
    
            # Decrypt
            IV = 16 * "\x00"
            mode = AES.MODE_CBC
            encryptor = AES.new(key,mode,IV=IV)
            flag = encryptor.decrypt(encFlag)
            print(b'Flag is: ' + flag)
    
class RoboticArmController(ModelController):
    def __init__(self):
        self.initLogging()
        self._sUser = config.DB_RPI_USER
        self._sPass = config.DB_RPI_PASS
        self._sCrtFile = config.DB_RPI_CRT_FILE
        self._sKeyFile = config.DB_RPI_KEY_FILE
        super().__init__()

    def send_spi_live(self):
        with spi.SPIDevice(0) as spi0:
            stdscr = curses.initscr()
            while(True):
                #c = input('>')
                c = stdscr.getch()
                if chr(c).startswith('q'):
                    break
                spi0.transaction(
                    spi.writing_bytes(c))
            curses.endwin()
    
    def getFlag(self):
        flag = b''
        with spi.SPIDevice(0) as spi0:
            # Get only first char
            spi0.transaction(
                spi.writing_bytes(ord('_')))
            sleep(0.5)
            while 1: 
                raw = spi0.transaction(spi.reading(1))
                #print(raw)
                c = raw[0]
                if c == b'\x00':
                    break
                flag += c
            print(flag)

