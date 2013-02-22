class ControllerProxy extends EchoJsonController
    constructor: (@context, @rep_uri, @pub_uri, @config) ->
        super @context, @rep_uri
        @socks =
            rep: @echo_fe
            sub: @context.socket(nullmq.SUB)
        @socks.sub.connect(@pub_uri)
        @socks.sub.setsockopt(nullmq.SUBSCRIBE, "")
        @socks.sub.recvall(@process_status_update)
        @pending_requests = {}
        @pending_iterations = {}
        @pending_config = {}
        @pending_outer_i = {}
        @pending_inner_i = {}
        @pending_block_positions = {}
        @outer_i = null
        @inner_i = null
        @_initialized = false
        @_initializing = false

        obj = @

        $(obj).on("async_response", (e) =>
            @process_async_response(e.response)
        )
        $(obj).on("iteration_completed", (e) =>
            obj.set_iteration_indexes(e.outer_i, e.inner_i)
            obj.update_iteration_count()
        )
        $(obj).on("iteration_update", (e) =>
            #console.log("iteration_update", e, e.response.outer_i, e.response.inner_i)
            obj.set_iteration_indexes(e.response.outer_i, e.response.inner_i)
            obj.update_iteration_count()
        )
        $(obj).on("config_updated", (e) =>
            if 'netlist_file' of e.config
                @config.netlist_path = e.config.netlist_file
            if 'arch_file' of e.config
                @config.arch_path = e.config.arch_file
            obj.update_config()
        )

        @do_request({"command": "config_dict"}, (value) =>
            # This will force initialization, if necessary
            @sync_iteration_indexes()
        )

    set_iteration_indexes: (outer_i, inner_i) =>
        if outer_i != null and not @_initialized
            console.log("initialized", @config.process_id)
            @_initialized = true
        @outer_i = outer_i
        @inner_i = inner_i

    sync_iteration_indexes: () =>
        obj = @
        obj.do_request({"command": "iter__outer_i"}, (value) =>
            obj.do_request({"command": "iter__inner_i"}, (value) =>)
        )

    initialize: (force=false) =>
        obj = @
        if force or not @_initialized and not @_initializing
            @_initializing = true
            #console.log("initialize")
            obj.do_request({"command": "initialize", "kwargs": {"depth": 2}}, (value) =>
                obj.do_request({"command": "iter__next"}, (value) =>
                    obj.do_request({"command": "iter__next"}, (value) =>
                        @_initializing = false
                    )
                )
            )

    update_config: () =>
        @row().find('td.netlist')
            .html(coffee_helpers.split_last(@config.netlist_path, '/'))
            .attr("title", @config.netlist_path)

    update_iteration_count: () =>
        remaining = Object.keys(@pending_iterations).length
        if remaining > 0
            remaining_text = " (" + remaining + ")"
        else
            remaining_text = ""
        class_ = "iteration" + (if remaining then " alert alert-info" else "")
        @row().find('td.iteration')
            .attr("class", class_)
            .html(
                if @outer_i? and @inner_i?
                    @outer_i + ", " + @inner_i + remaining_text
                else
                    "initializing..." + remaining_text
            )

    row: () => 
        $('#id_controllers_tbody > tr.controller_row[data-id="' + @config.process_id + '"]')

    process_async_response: (message) =>
        obj = @
        ###
        if not ('command' of message) or message.command != 'swap_info'
            console.log("process_async_response", message)
        ###
        if 'command' of message and message.command == 'iter__next'
            data =
                type: "iteration_completed"
                response: message
                outer_i: message.outer_i
                inner_i: message.inner_i
                next_outer_i: message.result[0]
                next_inner_i: message.result[1]
            $(obj).trigger(data)
        if 'command' of message and message.command in ['iter__outer_i', 'iter__inner_i']
            #console.log("process_async_response->outer/inner_i", message, ('error' of message))
            if ('error' of message) or message.outer_i == null
                @initialize()
            else
                data =
                    type: "iteration_update"
                    response: message
                    outer_i: message.outer_i
                    inner_i: message.inner_i
                $(obj).trigger(data)
        else if 'command' of message and message.command == 'config_dict'
            data =
                type: "config_updated"
                response: message
                config: message.result
            $(obj).trigger(data)

    process_status_update: (message) =>
        obj = @
        message = @deserialize(message)
        if 'async_id' of message
            if message.async_id of @pending_config
                delete @pending_config[message.async_id]
                # Manually override `command` field, since
                # `process_async_response` depends on it
                message.command = 'config_dict'
            if message.async_id of @pending_outer_i
                delete @pending_outer_i[message.async_id]
                message.command = 'iter__outer_i'
            if message.async_id of @pending_inner_i
                delete @pending_inner_i[message.async_id]
                message.command = 'iter__inner_i'
            if message.async_id of @pending_iterations
                delete @pending_iterations[message.async_id]
            if message.async_id of @pending_block_positions
                on_recv = @pending_block_positions[message.async_id]
                delete @pending_block_positions[message.async_id]
                on_recv(message.result)
            if message.async_id of @pending_requests
                delete @pending_requests[message.async_id]
                $(obj).trigger(type: "async_response", controller: obj, response: message)
            if message.async_id of @pending_outer_i
                delete @pending_outer_i[message.async_id]

    get_block_positions: (on_recv) =>
        @do_request({"command": "get_block_positions"}, (async_response) =>
            @pending_block_positions[async_response.async_id] = on_recv
        )

    do_request: (message, on_recv) =>
        _on_recv = (message) =>
            if 'async_id' of message
                @pending_requests[message.async_id] = message
                if 'command' of message and message.command == 'iter__next'
                    @pending_iterations[message.async_id] = message
                if 'command' of message and message.command == 'config_dict'
                    @pending_config[message.async_id] = message
                if message.command? and message.command == 'outer_i'
                    @pending_outer_i[message.async_id] = message
                if message.command? and message.command == 'inner_i'
                    @pending_inner_i[message.async_id] = message
            on_recv(message)
        super message, _on_recv

@ControllerProxy = ControllerProxy
