class @EchoController
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
    constructor: (@context, @action_uri, @swap_uri) ->
        @swaps = new Array()
        super @context, @action_uri
        @swap_fe = @context.socket(nullmq.SUB)
        @swap_fe.connect(@swap_uri)
        @swap_fe.setsockopt(nullmq.SUBSCRIBE, "")
        @swap_fe.recvall(@process_swap)

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
    process_swap: (message) =>
        @swaps.push(@deserialize(message))
    iterate_swap_eval: (on_recv, count) ->
        if count == undefined
            count = 1
        @_iterate_count = count
        @_iterate_i = 0
        if not @initialized
            @do_request({"command": "initialize", "kwargs": {"depth": 2}}, (message) =>
                @initialized = true
                @iterate_swap_eval(on_recv, count)
                console.log(message)
            )
        else
            @_iterate_continue(on_recv)
