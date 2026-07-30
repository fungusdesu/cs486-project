# Business requirements update & second validation
This section is reserved to discuss the changes to the business requirements in Phase 1, as well as a second validation of the current database design to ensure all tables satisfy at least third normal form (3NF). Naturally, the conceptual and logical ER diagrams are also adjusted accordingly to suit the modifications.

# Maintenance impact level
The update that is of most importance is the addition of a maintenance impact level. Previously, we assumed that all maintenance sessions render the space unusable and will thus put the space in a <code>SpaceStatus</code> of "under maintenance". From the new business requirements, we have devised modifications to the entities as follows:
