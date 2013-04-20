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
        @_do_request({uuid: @_uuid, command: 'available_handlers', args: [], kwargs: {}}, (response) ->
            obj._handler_methods = response.result
            for m in obj._handler_methods
                title = '' + m
                console.log('handler_method', m: m, title: title)
                method = (command, on_recv, args=null, kwargs=null) ->
                    console.log('handler', this.command)
                    data =
                        uuid: obj._uuid
                        args: args ? []
                        kwargs: kwargs ? {}
                        command: command
                    #_on_recv = (r) ->
                        #if r.error_str?
                            #throw 'Remote error:\n\n' + r.error_str
                        #if on_recv?
                            #on_recv(r.result)
                    console.log('handler_method', command: command)
                    obj._do_request($.extend({}, data), (r) ->
                        if r.error_str?
                            throw 'Remote error:\n\n' + r.error_str
                        if on_recv?
                            on_recv(r.result)
                    )
                obj[m] = coffee_helpers.partial(method, m)
            obj._initialized = true
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
