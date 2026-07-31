# Business requirements update & second validation
This section is reserved to discuss the changes to the business requirements in Phase 1, as well as a second validation of the current database design to ensure all tables satisfy at least third normal form (3NF). Naturally, the conceptual and logical ER diagrams are also adjusted accordingly to suit the modifications.

# Maintenance impact level
The update that is of most importance is the addition of a maintenance impact level. Previously, we assumed that all maintenance sessions render the space unusable and will thus put the space in a <code>SpaceStatus</code> of "under maintenance". From the new business requirements, we have devised modifications to the entities as follows:
- The addition of a new reference entity type <code>MaintenanceImpactLevel</code> to represent a maintenance's level of impact upon the usability of the space. Currently, there are two relevant entities this entity type will have: <code>ADVISORY</code> (indicating a maintenance that should not leave the space unbookable) and <code>OUT_OF_SERVICE</code> (indicating otherwise).
- An appended attribute <code>maintenance_imapct_level_id</code> to the entity type <code>Maintenance</code>. The attribute is referenceable via <code>MaintenanceImpactLevel</code>.
- A space may have several active maintenance records at the same time. In other words, different maintenance sessions on the same space may have overlapping <code>maintenance_time_slot</code>. In practice, this imposes no change on our design.

# Second validation
We perform a second validation in order to set the stage for our 3NF validation. Because of this, we have identified some problems that did not manifest as clearly in our first validation.
## Relationship decomposition
The relationship <code>books</code> and <code>maintains</code> are unnecessary. Because each booking request and maintenance uniquely identify user-space and technician-space pairs, respectively, separating them into their own table introduces redundancy. We thus decompose the former into two relationships <code>makes_request</code> and <code>requests_space</code>, and the latter into <code>carries_out</code> and <code>services</code>.
  - The binary <code>1:N</code> relationship <code>makes_request</code> has two participating entities <code>User</code> (with cardinality <code>(0, N)</code>) and <code>BookingRequest</code> (with cardinality <code>(1, 1)</code>).
  - The binary <code>N:1</code> relationship <code>requests_space</code> has two participating entities <code>BookingRequest</code> (with cardinality <code>(1, 1)</code>) and <code>Space</code> (with cardinality <code>(0, N)</code>).
  - The binary <code>1:N</code> relationship <code>carries_out</code> has two participating entities <code>User</code> (with cardinality <code>(0, N)</code>) and <code>Maintenance</code> (with cardinality <code>(1, 1)</code>).
  - The binary <code>N:1</code> relationship <code>services</code> has two participating entities <code>Maintenance</code> (with cardinality <code>(1, 1)</code>) and <code>Space</code> (with cardinality <code>(0, N)</code>).
In addition, the attribute <code>maintenance_time_slot</code> from the former relationship <code>maintains</code> is thus moves to the entity type <code>Maintenance</code> itself.