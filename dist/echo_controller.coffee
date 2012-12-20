class @EchoController
    constructor: (@context, @uri) ->
        @echo_be = @context.socket(nullmq.REQ)
        @echo_be.connect(@uri)
        @last_response = null

    send: (message) -> @echo_be.send(message)

    serialize: (message) -> message

    deserialize: (message) -> message

    do_request: (message, on_recv) ->
        try
            @send(@serialize(message))
            obj = @
            _on_recv = (value) ->
                value = obj.deserialize(value)
                on_recv(value)
            @echo_be.recv(_on_recv)
        catch error
            alert(error)


class @EchoJsonController extends @EchoController
    serialize: (javascript_obj) -> JSON.stringify(javascript_obj)

    deserialize: (json_string) ->
        try
            value = JSON.parse(json_string)
        catch error
            alert(error)
            value = null
        return value


class @PlacementController extends @EchoJsonController
    _iterate_count: 1
    _iterate_i: 0
    initialized: false
    _iterate_continue: (on_recv) ->
        if @_iterate_i < @_iterate_count - 1
            @do_request({"command": "iter.next"}, (value) =>
                @_iterate_i += 1
                @_iterate_continue(on_recv))
        else
            @do_request({"command": "iter.next"}, on_recv)
    iterate_swap_eval: (on_recv, count) ->
        if count == undefined
            count = 1
        @_iterate_count = count
        @_iterate_i = 0
        if not @initialized
            @do_request({"command": "initialize"}, (message) =>
                @initialized = true
                @iterate_swap_eval(on_recv, count)
            )
        else
            @_iterate_continue(on_recv)
