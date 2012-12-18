# IPython log file

import zmq
ctx = zmq.Context.instance()
sock = zmq.Socket(ctx, zmq.REP)
uri = 'tcp://*:9001'

def get_sock(ctx, uri):
    sock = zmq.Socket(ctx, zmq.REP)
    sock.bind(uri)
    return sock

sock = get_sock(ctx, uri)

while True:
    try:
        request = sock.recv_string()
        print request
        sock.send_string(request)
    except zmq.ZMQError:
        sock = get_sock(ctx, uri)
