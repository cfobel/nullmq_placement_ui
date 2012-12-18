1. Start echo server: `python nullmq_echo_server.py`
1. Start NullMQ-ZeroMQ bridge: `python nullmq_zmq_bridge.py`
1. Start local webserver: `python -m SimpleHTTPServer <port>`
1. Navigate to `http://localhost:<port>` in your browser
1. Enter a string in the text box and click "Send request"
1. An alert should pop up in the browser and the message should be echoed in
   the terminal where `nullmq_echo_server.py` is running
