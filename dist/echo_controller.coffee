class @EchoController
    constructor: (@context, @uri) ->
        @echo_be = @context.socket(nullmq.REQ)
        @echo_be.connect(@uri)

    do_request: (message) ->
        if message.length > 0
            @echo_be.send(message)
            @echo_be.recv(alert)
