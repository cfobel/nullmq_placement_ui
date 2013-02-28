class ControllerTableView
    constructor: (@zmq_context, @controller_factory, @controller_manager, @placement_comparator) ->
        _.templateSettings =
          interpolate: /\{\{(.+?)\}\}/g

        @template_text = d3.select("#id_controller_row_template").html()
        @template = _.template(@template_text)

        obj = @

        # The remainder of this function connects to signals required to:
        #
        #   -Add a proxy for any controller newly created by the controller
        #    factory to the controller proxy manager.
        #
        #   -Add a row to the controller table for any controller added to the
        #    controller proxy manager.
        #
        #   -Remove row from the controller table for any controller removed
        #    from the controller proxy manager.

        $(obj.controller_factory).on("controller", (e) => 
            # Whenever the controller factory announces a new controller has
            # been created on the backend, create a new controller proxy to
            # interface with the new controller.  This newly created controller
            # proxy is added to the controller proxy manager.
            if not (e.process_id of @controller_manager.controllers)
                controller = new ControllerProxy(@zmq_context, e.uris.rep, e.uris.pub, e)
                @controller_manager.add(e.process_id, controller)
            else
                console.log("on controller", "ignoring existing controller:", e.process_id)
        )

        $(obj.controller_manager).on("controller_added", (e) => 
            # Whenever a new controller proxy is added to the controller proxy
            # manager, add a corresponding row to the controller table view.
            @update_controller_table()
        )

        $(obj.controller_manager).on("controller_removed", (e) => 
            # Whenever a new controller proxy is removed from the controller
            # proxy manager, remove the corresponding row from the controller
            # table view.
            @update_controller_table()
        )


    update_controller_table: () =>
        obj = @

        controllers = obj.controller_manager.controller_list()
        rows = d3.select('#id_controllers_tbody').selectAll('.controller_row')
          .data(controllers, (d) -> d.process_id)
        rows.exit().remove()
        # Add a row for any new controllers
        rows.enter()
          .append("tr")
            .attr("class", "controller_row")
            .attr("data-id", (d) -> d.process_id)
            .html((d) ->
                # Set the row's contents by evaluating the template using
                # the controller's attributes.
                h_ = coffee_helpers
                netlist_path = d.controller.config.netlist_path ? '(pending...)'
                arch_path = d.controller.config.arch_path ? '(pending...)'
                data =
                    process_id_short: h_.split_last(d.process_id, ' ')[0..7]
                    netlist_path_short: h_.split_last(netlist_path, '/')
                    arch_path_short: h_.split_last(arch_path, '/')
                    seed: if d.controller.config.placer_opts? then d.controller.config.placer_opts.seed else '-'
                data = $().extend(d, data)
                obj.template(data)
            )
            .each((d) ->
                # Attach `on_click` handlers for the buttons each
                # controller row, e.g., `iterate`, `kill`, etc.
                c = d.controller
                c.row().find('.action_iterate > button').click(() ->
                    c.do_iteration()
                )
                c.row().find('.action_kill > button').click(() ->
                    obj.controller_factory.terminate(d.process_id, (value) =>
                        if not ('error' of value)
                            obj.controller_manager.remove(d.process_id)
                    )
                )
                c.row().find('.action_placement_a > button').click(() ->
                    c.get_block_positions((block_positions) ->
                        previous_config = obj.controller_manager.last_a_config ? {}
                        if c.config.netlist_path != (previous_config.netlist_path ? null)
                            obj.placement_comparator.reset_grid_a(c.place_context)
                        obj.placement_comparator.set_block_positions_grid_a(block_positions)
                        obj.controller_manager.last_a_config = c.config
                    )
                )
                c.row().find('.action_placement_b > button').click(() ->
                    c.get_block_positions((block_positions) ->
                        previous_config = obj.controller_manager.last_b_config ? {}
                        if c.config.netlist_path != (previous_config.netlist_path ? null)
                            obj.placement_comparator.reset_grid_b(c.place_context)
                        obj.placement_comparator.set_block_positions_grid_b(block_positions)
                        obj.controller_manager.last_b_config = c.config
                    )
                )
            )

    selected_process_ids: () =>
        d.dataset.id for d in $("#id_controllers_tbody input[type='checkbox']:checked")

    all_process_ids: () =>
        d.dataset.id for d in $("#id_controllers_tbody input[type='checkbox']")

    selected_process_infos: () =>
        {process_id: id, controller: @controller_manager.controllers[id]} for id in @selected_process_ids()

    all_process_infos: () =>
        {process_id: id, controller: @controller_manager.controllers[id]} for id in @all_process_ids()

    apply_to_selected_placements: (on_recv) =>
        p = new PlacementCollector(@selected_process_infos())
        p.collect('get_block_positions', on_recv)


@ControllerTableView = ControllerTableView