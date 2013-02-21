class ControllerFactoryProxy extends EchoJsonController
    constructor: (@context, @action_uri) ->
        super @context, @action_uri

    reset: () =>
        obj = @
        obj.do_request(command: "available_netlists", (value) =>
            @netlists = value.result
            obj.do_request(command: "available_architectures",
                (value) =>
                    @architectures = value.result
                    obj.do_request(command: "available_modifier_names", (value) =>
                        @modifier_names = value.result
                        console.log(netlists: @netlists, architectures: @architectures, modifier_names: @modifier_names)
                        $(obj).trigger(type: "reset_completed", controller_factory: obj)
                    )
            )
        )

    make_controller: (netlist, arch, modifier_class) =>
        kwargs =
            modifier_class: modifier_class
            netlist_path: netlist
            arch_path: arch
            auto_run: true
        this.do_request({command: "make_controller", kwargs: kwargs}, (value) =>
            if 'error' in value.result
                console.log(error: value.result.error, response: value)
            else
                console.log("made controller:", value.result.process_id,
                            value.result.uris)
        )

@ControllerFactoryProxy = ControllerFactoryProxy
