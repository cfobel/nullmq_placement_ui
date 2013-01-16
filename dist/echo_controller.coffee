class EchoController
    constructor: (@context, @uri) ->
        @echo_fe = @context.socket(nullmq.REQ)
        @echo_fe.connect(@uri)
        @last_response = null

    send: (message) -> @echo_fe.send(message)

    serialize: (message) -> message

    deserialize: (message) -> message

    do_request: (message, on_recv) ->
        try
            @send(@serialize(message))
            obj = @
            _on_recv = (value) ->
                value = obj.deserialize(value)
                on_recv(value)
            @echo_fe.recv(_on_recv)
        catch error
            alert(error)


class EchoJsonController extends EchoController
    serialize: (javascript_obj) -> JSON.stringify(javascript_obj)

    deserialize: (json_string) ->
        try
            value = JSON.parse(json_string)
        catch error
            alert(error)
            value = null
        return value


@EchoController = EchoController
@EchoJsonController = EchoJsonController
