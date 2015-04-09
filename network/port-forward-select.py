#!/usr/bin/env python

import os
import sys
import socket
import select
import errno


class TCPProxyWorker(object):
    """TCP Proxy worker."""

    def __init__(self, listen_port, target_host, target_port):
        self.listen_port = listen_port
        self.target_host = target_host
        self.target_port = target_port

    def run(self):
        try:
            listen_sock = socket.socket(socket.AF_INET,
                                        socket.SOCK_STREAM)
            listen_sock.setblocking(0)
            listen_sock.setsockopt(socket.SOL_SOCKET,
                                   socket.SO_REUSEADDR, 1)
            listen_sock.bind(('0.0.0.0', self.listen_port))
            listen_sock.listen(50)
        except Exception as e:
            sys.exit(e.args[0])

        socket_channels = {}
        polling_sockets = [listen_sock]

        def add_channel(sock):
            income_sock, address = sock.accept()
            target_sock = socket.socket(socket.AF_INET,
                                        socket.SOCK_STREAM)
            target_sock.connect((self.target_host,
                                 self.target_port))
            income_sock.setblocking(0)
            target_sock.setblocking(0)
            polling_sockets.append(income_sock)
            polling_sockets.append(target_sock)
            socket_channels[income_sock] = target_sock
            socket_channels[target_sock] = income_sock

        def del_channel(recv_sock, send_sock):
            del socket_channels[recv_sock]
            del socket_channels[send_sock]
            polling_sockets.remove(recv_sock)
            polling_sockets.remove(send_sock)
            recv_sock.close()
            send_sock.close()

        print "listening on port %d" % self.listen_port
        while True:
            rsocks, wsocks, esocks = select.select(
                polling_sockets, [], [])

            if len(esocks) > 0:
                raise Exception()

            for recv_sock in rsocks:
                if recv_sock == listen_sock:
                    add_channel(listen_sock)
                    continue
                recv_buff = []
                channel_closed = False
                send_sock = socket_channels[recv_sock]
                while True:
                    try:
                        data = recv_sock.recv(8192)
                    except socket.error as e:
                        if errno.EAGAIN == e.args[0]:
                            break
                        elif errno.EBADF == e.args[0]:
                            channel_closed = True
                            break
                    except Exception as e:
                        raise

                    if len(data) > 0:
                        recv_buff.append(data)
                    else:
                        channel_closed = True
                        break
                if len(recv_buff) > 0:
                    send_sock.sendall(''.join(recv_buff))
                if channel_closed:
                    del_channel(recv_sock, send_sock)
            if len(polling_sockets) < 1:
                break
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
