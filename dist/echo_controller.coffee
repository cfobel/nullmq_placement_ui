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
            'by_from_block_id': {},
            'by_to_block_id': {},
        }
    constructor: (@placement_grid, @context, @action_uri, @swap_uri) ->
        @swap_contexts = new Array()
        super @context, @action_uri
        @swap_fe = @context.socket(nullmq.SUB)
        @swap_fe.connect(@swap_uri)
        @swap_fe.setsockopt(nullmq.SUBSCRIBE, "")
        @swap_fe.recvall(@process_swap)
        @initialized = false
    initialize: (callback) ->
        if not @initialized
            console.log("initialize")
            @do_request({"command": "initialize", "kwargs": {"depth": 2}}, callback)
            @initialized = true
    _iterate_count: 1
    _iterate_i: 0
    _iterate_continue: (on_recv) ->
        if @_iterate_i < @_iterate_count - 1
            @do_request({"command": "iter.next"}, (value) =>
                @_iterate_i += 1
                @_iterate_continue(on_recv))
        else
            @do_request({"command": "iter.next"}, on_recv)
    current_swap_context: () ->
        if @swap_contexts <= 0
            error = 
                message: "There are currently no swap contexts"
                code: -100
            throw error
        return @swap_contexts[@swap_contexts.length - 1]
    process_swap: (message) =>
        swap_context = @current_swap_context()
        swap_info = @deserialize(message)
        swap_context.all.push(swap_info)
        if swap_info.swap_config.participate
            if swap_info.swap_config.ids.from_ >= 0
                swap_context.by_from_block_id[swap_info.swap_config.ids.from_] = swap_info
            if swap_info.swap_config.ids.to >= 0
                swap_context.by_to_block_id[swap_info.swap_config.ids.to] = swap_info
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
        @swap_contexts.push(@get_swap_context())
        @_iterate_continue(on_recv)
