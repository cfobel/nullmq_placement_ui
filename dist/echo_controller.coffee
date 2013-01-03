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
    get_swap_context: () -> {
            'all': new Array()
            'participated': {},
            'not_participated': {},
            'accepted': {},
            'skipped': {},
        }
    constructor: (@context, @action_uri, @swap_uri) ->
        @swap_contexts = new Array()
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
    current_swap_context: () ->
        if @swap_contexts <= 0
            throw "There are currently no swap contexts"
        return @swap_contexts[@swap_contexts.length - 1]
    process_swap: (message) =>
        swap_context = @current_swap_context()
        swap_info = @deserialize(message)
        swap_context.all.push(swap_info)
        if swap_info.swap_config.participate
            swap_context.participated[swap_info.swap_i] = swap_info
            if swap_info.swap_result.swap_accepted
                swap_context.accepted[swap_info.swap_i] = swap_info
            else
                swap_context.skipped[swap_info.swap_i] = swap_info
        else
            swap_context.not_participated[swap_info.swap_i] = swap_info
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
            @swap_contexts.push(@get_swap_context())
            @_iterate_continue(on_recv)
