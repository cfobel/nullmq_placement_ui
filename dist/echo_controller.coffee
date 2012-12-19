class @EchoController
    constructor: (@context, @uri) ->
        @echo_be = @context.socket(nullmq.REQ)
        @echo_be.connect(@uri)

    on_recv: alert

    send: (message) -> @echo_be.send(message)

    do_request: (message) ->
        try
            @send(message)
            @echo_be.recv(@on_recv)
        catch error
            alert(error)


class @EchoJsonController extends @EchoController
    on_recv: (json_v) ->
        try
            v = JSON.parse(json_v)
            alert('"' + json_v + '" -> ' + v)
        catch error
            alert(error)

    send: (message) ->
        value = JSON.parse(message)
        @echo_be.send(JSON.stringify(value))
