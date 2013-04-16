class RpcProxy
    _deferred_command_class: null
    constructor: (context, rpc_uri, uuid) ->
        @_context = context
        @_uuid = uuid
        @_uris = rpc: rpc_uri
        @_initialized = false
        @_refresh_handler_methods()

    _refresh_handler_methods: () =>
        obj = @
        @_do_request({uuid: @_uuid, command: 'available_handlers', args: [], kwargs: {}}, (response) =>
            @_handler_methods = response.result
            for m in @_handler_methods
                obj[m] = (on_recv, args=null, kwargs=null) ->
                    data =
                        uuid: obj._uuid
                        args: args ? []
                        kwargs: kwargs ? {}
                        command: m
                    _on_recv = (r) ->
                        if r.error_str?
                            throw 'Remote error:\n\n' + r.error_str
                        if on_recv?
                            on_recv(r.result)
                    obj._do_request(data, _on_recv)
            @_initialized = true
        )

    _do_request: (message, on_recv) =>
        try
            console.log(message, on_recv)
            sock = @_context.socket(nullmq.REQ)
            sock.connect(@_uris.rpc)
            sock.send(JSON.stringify(message))
            obj = @
            _on_recv = (value) ->
                value = JSON.parse(value)
                on_recv(value)
                sock.close()
            sock.recv(_on_recv)
        catch error
            alert(error)


@RpcProxy = RpcProxy
