#!/usr/bin/python3
"""Monkey patching standard xmlrpc.server.SimpleXMLRPCServer
to run over TLS (SSL)

Changes inspired on http://www.cs.technion.ac.il/~danken/SecureXMLRPCServer.py
"""
from xmlrpc.server import SimpleXMLRPCServer,SimpleXMLRPCDispatcher,SimpleXMLRPCRequestHandler

import socketserver
import http.server
#import SimpleHTTPServer

import socket, os
#from OpenSSL import SSL
import ssl
import socket
import socketserver
import ssl
from xmlrpc.server import SimpleXMLRPCServer, SimpleXMLRPCDispatcher, SimpleXMLRPCRequestHandler
try:
    import fcntl
except ImportError:
    fcntl = None

# Configure below
LISTEN_HOST='192.168.4.166' # You should not use '' here, unless you have a real FQDN.
LISTEN_PORT=8000

KEYFILE='certs/key.pem'    # Replace with your PEM formatted key file
CERTFILE='certs/cert.pem'  # Replace with your PEM formatted certificate file
# Configure above

class SimpleXMLRPCServerTLS(SimpleXMLRPCServer):
    def __init__(self, addr, requestHandler=SimpleXMLRPCRequestHandler,
                 logRequests=True, allow_none=False, encoding=None, bind_and_activate=True):
        """Overriding __init__ method of the SimpleXMLRPCServer

        The method is an exact copy, except the TCPServer __init__
        call, which is rewritten using TLS
        """
        self.logRequests = logRequests

        SimpleXMLRPCDispatcher.__init__(self, allow_none, encoding)

        """This is the modified part. Original code was:

            socketserver.TCPServer.__init__(self, addr, requestHandler, bind_and_activate)

        which executed:

            def __init__(self, server_address, RequestHandlerClass, bind_and_activate=True):
                BaseServer.__init__(self, server_address, RequestHandlerClass)
                self.socket = socket.socket(self.address_family,
                                            self.socket_type)
                if bind_and_activate:
                    self.server_bind()
                    self.server_activate()

        """
        socketserver.BaseServer.__init__(self, addr, requestHandler)
        self.socket = ssl.wrap_socket(
            socket.socket(self.address_family, self.socket_type),
            server_side=True,
            certfile='certs/certkey.pem',
            cert_reqs=ssl.CERT_NONE,
            ssl_version=ssl.PROTOCOL_SSLv23,
            )
        if bind_and_activate:
            self.server_bind()
            self.server_activate()

        """End of modified part"""

        # [Bug #1222790] If possible, set close-on-exec flag; if a
        # method spawns a subprocess, the subprocess shouldn't have
        # the listening socket open.
        if fcntl is not None and hasattr(fcntl, 'FD_CLOEXEC'):
            flags = fcntl.fcntl(self.fileno(), fcntl.F_GETFD)
            flags |= fcntl.FD_CLOEXEC
            fcntl.fcntl(self.fileno(), fcntl.F_SETFD, flags)

class SecureXMLRpcRequestHandler(SimpleXMLRPCRequestHandler):
    """Secure XML-RPC request handler class.

    It it very similar to SimpleXMLRPCRequestHandler but it uses HTTPS for transporting XML data.
    """
    def setup(self):
        self.connection = self.request
        self.rfile = socket._fileobject(self.request, "rb", self.rbufsize)
        self.wfile = socket._fileobject(self.request, "wb", self.wbufsize)
        
    def do_POST(self):
        """Handles the HTTPS POST request.

        It was copied out from SimpleXMLRPCServer.py and modified to shutdown the socket cleanly.
        """

        try:
            # get arguments
            data = self.rfile.read(int(self.headers["content-length"]))
            # In previous versions of SimpleXMLRPCServer, _dispatch
            # could be overridden in this class, instead of in
            # SimpleXMLRPCDispatcher. To maintain backwards compatibility,
            # check to see if a subclass implements _dispatch and dispatch
            # using that method if present.
            response = self.server._marshaled_dispatch(
                    data, getattr(self, '_dispatch', None)
                )
        except: # This should only happen if the module is buggy
            # internal error, report as HTTP server error
            self.send_response(500)
            self.end_headers()
        else:
            # got a valid XML RPC response
            self.send_response(200)
            self.send_header("Content-type", "text/xml")
            self.send_header("Content-length", str(len(response)))
            self.end_headers()
            self.wfile.write(response)

            # shut down the connection
            self.wfile.flush()
            self.connection.shutdown() # Modified here!

def test(HandlerClass = SecureXMLRpcRequestHandler,ServerClass = SimpleXMLRPCServerTLS):
    """Test xml rpc over https server"""
    class xmlrpc_registers:
        def __init__(self):
            import string
            self.python_string = string
            
        def add(self, x, y):
            return x + y
    
        def mult(self,x,y):
            return x*y
    
        def div(self,x,y):
            return x//y
        
    #cnc = cncServer()
    #cnc.serve_forever()

    server_address = (LISTEN_HOST, LISTEN_PORT) # (address, port)
    server = ServerClass(server_address, HandlerClass)    
    server.register_instance(xmlrpc_registers())    
    #ctx = ssl.SSLContext(ssl.SSLv23_METHOD)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
    #ctx.use_privatekey_file (KEYFILE)
    #ctx.use_certificate_file(CERTFILE)
    ctx.load_cert_chain(CERTFILE, KEYFILE)

    #server.socket = ssl.wrap_socket
    #sa = server.socket.getsockname()
    #print("Serving HTTPS on", sa[0], "port", sa[1])
    server.serve_forever()


if __name__ == '__main__':
    test()
