# TODO:

## Fri Mar  8 02:30:22 EST 2013

The Python `PlacementManager` should be updated to collect any available place
configurations.  One way this can be accomplished is in a similar fashion to how
placements are currently being collected, i.e., by listening for any responses
to `get_config`.  In addition, modifiers may choose to publish configuration
change updates, e.g., a published message with a type set to something like
`config_update`.  Configurations should be stored in an `OrderedDict`, using
`(outer_i, inner_i)` as the key for each configuration.

This update will permit the Coffeescript `PlacementComparator` class to update
the grids based on the configuration corresponding to the currently displayed
placement.  For instance, this functionality will allow for overlaying the area boundaries
from an iteration of a tile grouping modifier.


# DONE:

## Fri Mar  8 02:27:28 EST 2013

It looks like at least the `by_from_block_id` member is not filled in properly
for the swap context extended by the swap context returned from the remote
placement manager.

Potential issues to check:

 * `by_from_block_id`, etc. are not part of the remote swap context?
 * `by_from_block_id`, etc. are not being transferred as expected when
   extending the javascript `SwapContext` object

### Resolution

This was a red herring.  The issue was that during testing, a grid was being
passed to `apply_swaps`, where either no arg or a `block_positions` array must
be provided instead.
