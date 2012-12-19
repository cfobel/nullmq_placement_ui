import zmq


class EchoServer(object):
    def __init__(self, uri):
        self.uri = uri
        self.ctx = zmq.Context.instance()
        self.sock = self.get_sock()

    def get_sock(self):
        sock = zmq.Socket(self.ctx, zmq.REP)
        sock.bind(self.uri)
        return sock

    def run(self):
        while True:
            try:
                request = self.sock.recv_json()
                print type(request), request
                self.sock.send_json(request)
            except zmq.ZMQError:
                self.sock = self.get_sock()


if __name__ == '__main__':
    server = EchoServer('tcp://*:9001')
    server.run()
