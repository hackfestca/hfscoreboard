#!/usr/local/bin/python3
# -*- coding: utf-8 -*-

'''
This script is the main interface for players to submit flags and display score

@author: _eko
@updatedBy: mdube
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

# Python version validation
import sys
if sys.version_info < (3, 2, 0):
    print('Python version 3.2 or later is needed for this script')
    exit(1)

sys.path.insert(0, 'lib')
del sys

# Project imports
from lib.WebController import WebController
import config

import tornado.web
import tornado.ioloop
import tornado.httpserver
import tornado.log 
from tornado import gen
from tornado.options import define, options


# System imports
import os
import logging
import re
import random
import psycopg2
from copy import deepcopy

WEB_ERROR_MESSAGE = 'Oops. Something wrong happened. :)'

define("ip", default="127.0.0.1", help="Run on any given IP", type=str)
define("port", default=5000, help="run on the given port", type=int)
define("debug", default=False, help="Enable debug mode", type=bool)

# Use True for Hackfest
# Use False for iHack
define("authByIP", default=False, help="When true, the scoreboard authenticate"\
                                    " by IP", type=bool)

class Logger(logging.getLoggerClass()):

    def __init__(self, name):
        super().__init__(name)
        self.logger = logging.getLogger("scoreboard_logger")
        self.logger.setLevel(logging.ERROR)

        error_file = logging.FileHandler("logs/errors.log", encoding="utf-8")
        error_file.setLevel(logging.ERROR)
        error_formatter = logging.Formatter('%(asctime)s - %(message)s')
        error_file.setFormatter(error_formatter)

        info_file = logging.FileHandler("logs/infos.log", encoding="utf-8")
        info_file.setLevel(logging.INFO)
        info_formatter = logging.Formatter('%(asctime)s - %(message)s')
        info_file.setFormatter(info_formatter)

        self.logger.addHandler(error_file)
        self.logger.addHandler(info_file)

    def error(self, msg):
        self.logger.error(msg)

    def info(self, msg):
        self.logger.info(msg)


class Application(tornado.web.Application):
    def __init__(self):
        # Prety stdout logs
        tornado.log.enable_pretty_logging()
    
        sponsors_imgs_path = os.path.join(os.path.dirname(__file__),
                                          "static/sponsors")
        self._sponsors = ["/static/sponsors/" +
                         f for f in sorted(os.listdir(sponsors_imgs_path))
                         if os.path.isfile(os.path.join(sponsors_imgs_path, f))]
    
        self._client = None
        self._team_name = None
        self._team_ip = None
        self._team_score = None
        self._insults = [
            "Just what do you think you're doing Dave?",
            "It can only be attributed to human error.",
            "That's something I cannot allow to happen.",
            "Take a stress pill and think things over.",
            "This mission is too important for me to allow you to jeopardize it.",
            "Wrong!  You cheating scum!",
            "Are you on drugs?",
            "You type like i drive.",
            "Listen, broccoli brains, I don't have time to listen to this trash.",
            "I've seen penguins that can type better than that.",
            "What, what, what, what, what, what, what, what, what, what?",
            "I think ... err ... I think ... I think I'll go home"
        ]
        self.logger = Logger("HF_Logger")

        handlers = [
            (r"/", IndexHandler),
            #(r"/rules/", RulesHandler),
            (r"/random/", RandomHandler),
            (r"/secrets/", SecretsHandler),
            (r"/challenges/", ChallengesHandler),
            (r"/scoreboard/", ScoreHandler),
            (r"/dashboard/", DashboardHandler),
#(r"/bmi/?", BlackMarketItemHandler, args),
            (r"/projector/1/?", IndexProjectorHandler),
            (r"/projector/2/?", DashboardProjectorHandler),
            (r"/projector/3/?", SponsorsProjectorHandler),
            (r"/auth/register", AuthRegisterHandler),
            (r"/auth/login", AuthLoginHandler),
            (r"/auth/logout", AuthLogoutHandler),
         ]

        settings = dict(
            blog_title=u"iHack 2017",
            template_path=os.path.join(os.path.dirname(__file__), "templates"),
            static_path=os.path.join(os.path.dirname(__file__), "static"),
            #ui_modules={"Entry": EntryModule},
            xsrf_cookies=True,
            cookie_secret="diNWeEcTATKoC4ZEL8wpz77SVmbdYR9Kj7ezbXDjoRw9Nj7koo",
            default_handler_class=Error404Handler,  # 404 Handling
            login_url="/auth/login",
            debug=options.debug,
            xheaders=True
        )
        super(Application, self).__init__(handlers, **settings)

class BaseHandler(tornado.web.RequestHandler):

    def initialize(self):
        self.remote_ip = self.request.headers.get('X-Forwarded-For', self.request.headers.get('X-Real-Ip', self.request.remote_ip))

    def write_error(self, status_code, **kwargs):
        # Handler for all the internals Error (500)
        # Handle every exception thrown by any BaseHadler
        #import traceback

        #if options.debug:
        #    exc_type, exc_obj, exc_tb = kwargs["exc_info"]
        #    msg = "{}".format(exc_obj)
        #else:
        #    msg = WEB_ERROR_MESSAGE

        # self.logger.error("{}:{}:{}".format(self.request.remote_ip,
        #                                    exc_type.__name__,
        #                                    exc_obj.message))
        self.renderCriticalFailure()

    def _connect(self):
        try:
            self.client = WebController()
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg="Error")

    def _getTeamInfo(self):
        try:
            if options.authByIP:
                team_info = list(self.client.getTeamInfoFromIp(self.remote_ip))
                self.team_name = team_info[1][1]
                self.team_ip = team_info[3][1]
                self.team_score = team_info[7][1]
            elif self.is_logged():
                team_id = int(self.get_secure_cookie("team_id"))
                team_info = self.client.getTeamInfo(team_id)
                self.team_name = team_info[1][1]
                self.team_ip = self.remote_ip
                self.team_score = team_info[7][1]
            else:
                self.team_name = "None"
                self.team_ip = "None"
                self.team_score = "None"
        except psycopg2.Error as e:
            self.logger.error(e)
            self.renderCriticalFailure()
        except Exception as e: 
            self.logger.error(e)
            self.team_name = "None"
            self.team_ip = "None"
            self.team_score = "None"

    def _disconnect(self):
        try:
            self.client.close()
        except Exception as e:
            self.logger.error('Could not close DB connection.')
            pass  # The connection was never established

    def prepare(self):
        self._connect()

    def on_finish(self):
        self._disconnect()

    def get_current_user(self):
        if options.authByIP:
            return self.team_name
        else:
            team_id = self.get_secure_cookie("team_id")
            if team_id is None: return None
            elif not team_id.isdigit(): return None
            return int(team_id.decode('UTF-8'))

    def get_pgsql_error(self, pgsql_error):
        if pgsql_error.pgcode == config.PGSQL_ERRCODE:
            message = pgsql_error.diag.message_primary
        else:
            message = WEB_ERROR_MESSAGE
        return message

    def renderCriticalFailure(self, **kwargs):
        template_name = 'error.html'
        super().render(template_name,
                       is_logged='None',
                       team_name='None',
                       team_ip='None',
                       team_score='None',
                       error_msg=WEB_ERROR_MESSAGE,
                       **kwargs)

    def render_pgsql_error(self, pgsql_error, **kwargs):
        self._getTeamInfo()
        template_name = 'error.html'
        message = self.get_pgsql_error(pgsql_error)
        super().render(template_name,
                       is_logged=self.is_logged(),
                       team_name=self.team_name,
                       team_ip=self.team_ip,
                       team_score=self.team_score,
                       error_msg=message,
                       **kwargs)

    def render(self, template_name, **kwargs):
        self._getTeamInfo()
        super().render(template_name,
                       is_logged=self.is_logged(),
                       team_name=self.team_name,
                       team_ip=self.team_ip,
                       team_score=self.team_score,
                       **kwargs)

    def getInsult(self, index):
        return self._insults[index]

    def is_logged(self):
        if options.authByIP:
            return True
        else:
            return bool(self.get_secure_cookie("team_id"))

    @property
    def sponsors(self):
        return self.application._sponsors

    @property
    def client(self):
        return self.application._client

    @client.setter
    def client(self, arg):
        self.application._client = arg

    @property
    def logger(self):
        return self.application.logger

    @logger.setter
    def logger(self, arg):
        self.application.logger = arg

    @property
    def team_name(self):
        return self.application._team_name

    @team_name.setter
    def team_name(self, arg):
        self.application._team_name = arg

    @property
    def team_ip(self):
        return self.application._team_ip

    @team_ip.setter
    def team_ip(self, arg):
        self.application._team_ip = arg

    @property
    def team_score(self):
        return self.application._team_score

    @team_score.setter
    def team_score(self, arg):
        self.application._team_score = arg 


class IndexHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        try:
            score = self.client.getScore(top=15)
            valid_news = self.client.getNewsList()
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.render('index.html',
                        table=score,
                        news=valid_news,
                        sponsors=self.sponsors)

    @tornado.web.authenticated
    def post(self):
        flag = self.get_argument("flag")
        valid_news = self.client.getNewsList()

        try:
            if options.authByIP:
                submit_message = self.client.submitFlagFromIp(flag,self.remote_ip)
            else:
                team_id = self.get_current_user()
                submit_message = self.client.submitFlag(flag,team_id,self.remote_ip)
        except psycopg2.Error as e:  # already submitted, invalid flag = insult
            self.logger.error(e)
            submit_message = self.get_pgsql_error(e)
            flag_is_valid = False
        except Exception as e:
            self.logger.error(e)
            self.set_status(500)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            flag_is_valid = True

        score = self.client.getScore(top=15)
        self.render('index.html',
                    table=score,
                    news=valid_news,
                    sponsors=self.sponsors,
                    flag_is_valid=flag_is_valid,
                    submit_message=submit_message)


class RulesHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self):
        self.render('rules.html')

class RandomHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self):
        self.render('random.html')


class SecretsHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        try:
            if options.authByIP:
                secrets = self.client.getTeamSecretsFromIp(self.remote_ip)
            else:
                team_id = self.get_current_user()
                secrets = self.client.getTeamSecrets(team_id)
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.render('secrets.html', secrets_table=list(secrets))


class ChallengesHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        try:
            if options.authByIP:
                categories = self.client.getCatProgressFromIp(self.remote_ip)
                challenges = self.client.getFlagProgressFromIp(self.remote_ip)
            else:
                categories = self.client.getCatProgress(self.get_current_user())
                challenges = self.client.getFlagProgress(self.get_current_user())
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.render('challenges.html',
                        cat=list(categories),
                        chal=list(challenges))


class ScoreHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        try:
            score = self.client.getScore(top=200)
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.render('score.html', score_table=list(score))


class DashboardHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        try:
            jsArray2 = ""
            jsArray = self.client.getCsvScoreProgress()
            # Formatting into javascript string.
            for i in jsArray.split("\r\n"):
                jsArray2 += "\"" + i + "\\n\" + \n"
            jsArray = jsArray2[:-12]
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.render('dashboard.html',
                        sponsors=self.sponsors,
                        jsArray=jsArray)


class BlackMarketItemHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        privateId = self.get_argument("privateId")

        try:
            bmItemData = self.client.getBMItemDataFromIp(privateId,
                                                         self.remote_ip
                                                         )
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.set_header('Content-Type', 'application/octet-stream')
            self.set_header('Content-Disposition',
                            'attachment; filename=' + privateId)
            # buf_size = 4096
            # while True:
            #     data = bmItemData.read(buf_size)        # to test
            #     if not data:
            #         break
            self.write(bmItemData)
            self.finish()


class Error404Handler(BaseHandler):

    def initialize(self):
        self._client = None
        self._team_name = None
        self._team_ip = None
        self._team_score = None

    def get(self):
        # Cedrick Chaput don't want me to tell you when you're wrong
        self.redirect('/')


class IndexProjectorHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        try:
            score = self.client.getScore(top=15)
            valid_news = self.client.getNewsList()
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.render('projector.html',
                        table=score,
                        news=valid_news)


class DashboardProjectorHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        try:
            jsArray2 = ""
            jsArray = self.client.getCsvScoreProgress()
            # Formatting into javascript string.
            for i in jsArray.split("\r\n"):
                jsArray2 += "\"" + i + "\\n\" + \n"
            jsArray = jsArray2[:-12]
        except psycopg2.Error as e:
            self.logger.error(e)
            self.render_pgsql_error(pgsql_error=e)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.render('projector_js.html',
                        jsArray=jsArray)


class SponsorsProjectorHandler(BaseHandler):
    @tornado.web.authenticated
    @tornado.web.addslash
    def get(self):
        self.render('projector_sponsors.html',
                    sponsors=self.sponsors)

class AuthRegisterHandler(BaseHandler):
    form = {'name': '',
            'pwd1': '',
            'pwd2': '',
            'loc': 0}

    def get(self):
        if options.authByIP:
            self.redirect("/")
        
        locations = self.client.getTeamLocations()

        self.render("register.html", form=self.form,
                                     submit_message='',
                                     locations=locations)

    @gen.coroutine
    def post(self):
        if options.authByIP:
            self.redirect("/")

        form = deepcopy(self.form)
        try:
            form['name'] = self.get_argument('team_name')
            form['pwd1'] = self.get_argument('team_pwd1')
            form['pwd2'] = self.get_argument('team_pwd2')
            form['loc'] = self.get_argument('team_loc',None)
            if form['loc'].isdigit():
                form['loc'] = int(form['loc'])
            else:
                form['loc'] = None
            team_id = self.client.registerTeam(form['name'],form['pwd1'],
                                               form['pwd2'],form['loc'])
        except psycopg2.Error as e:
            self.logger.error(e)
            error_msg = self.get_pgsql_error(e)
            form['pwd1'] = ''
            form['pwd2'] = ''
            self.render("register.html", form=form,
                                         submit_message=error_msg)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg="Error")
        else:
            self.logger.info('Team %s registered' % form['name'])
            self.set_secure_cookie("team_id", str(team_id))
            self.redirect(self.get_argument("next", "/"))

class AuthLoginHandler(BaseHandler):
    form = {'name': '',
            'pwd': ''}

    def get(self):
        # Cannot put self.redirect("/") because it makes an infinite loop. TODO: find why.
        self.render("login.html", form=self.form,
                                  submit_message='')

    @gen.coroutine
    def post(self):
        if options.authByIP:
            self.redirect("/")

        if self.is_logged():
            self.clear_cookie("team_id")

        try:
            form = deepcopy(self.form)
            form['name'] = self.get_argument('team_name')
            form['pwd'] = self.get_argument('team_pwd')
            team_id = self.client.loginTeam(form['name'],form['pwd'])
        except psycopg2.Error as e:
            self.logger.error(e)
            error_msg = self.get_pgsql_error(e)
            form['pwd'] = ''
            self.render("login.html", form=form,
                                         submit_message=error_msg)
        except Exception as e:
            self.set_status(500)
            self.logger.error(e)
            self.render('error.html', error_msg=WEB_ERROR_MESSAGE)
        else:
            self.logger.info('Team %s registered' % form['name'])
            self.set_secure_cookie("team_id", str(team_id))
            form['name'] = ''
            form['pwd'] = ''
            self.redirect(self.get_argument("next", "/"))

class AuthLogoutHandler(BaseHandler):
    def get(self):
        if options.authByIP:
            self.redirect("/")

        self.clear_cookie("team_id")
        self.redirect(self.get_argument("next", "/"))

if __name__ == '__main__':

    tornado.options.parse_command_line()
    server = tornado.httpserver.HTTPServer(Application())

    server.listen(options.port, options.ip)
    tornado.ioloop.IOLoop.instance().start()

if __name__ == "__main__":
    main()
