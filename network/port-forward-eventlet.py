#!/usr/bin/env python

import os
import sys
import errno
import eventlet

from eventlet.green import socket


class TCPProxyWorker(object):
    """TCP Proxy worker."""

    def __init__(self, listen_port, target_host, target_port):
        self.listen_port = listen_port
        self.target_host = target_host
        self.target_port = target_port

    def run(self):
        try:
            listen_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            listen_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listen_sock.bind(('0.0.0.0', self.listen_port))
            listen_sock.listen(50)
        except Exception as e:
            sys.exit(-1)

        def forward(source, target, cb=lambda: None):
            while True:
                close_channel = False
                data = source.recv(32384)
                if len(data) > 0:
                    target.sendall(data)
                else:
                    close_channel = True

                if close_channel:
                    source.close()
                    target.close()
                    break

        print "listening on port %d" % self.listen_port
        while True:
            income_sock, address = listen_sock.accept()
            target_sock = socket.socket(socket.AF_INET,
                                        socket.SOCK_STREAM)
            target_sock.connect((self.target_host,
                                 self.target_port))
            eventlet.spawn(forward, income_sock, target_sock)
            eventlet.spawn(forward, target_sock, income_sock)

        listen_sock.shutdown(socket.SHUT_RDWR)
        listen_sock.close()


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print "usage: %s <listen port> <target host> <target port>" % sys.argv[0]
        sys.exit(-1)

    listen_port = int(sys.argv[1])
    target_host = str(sys.argv[2])
    target_port = int(sys.argv[3])
    proxy = TCPProxyWorker(listen_port,
                           target_host,
                           target_port)
    proxy.run()
