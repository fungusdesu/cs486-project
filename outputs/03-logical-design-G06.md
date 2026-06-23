# Logical ER model
The logical ER model lies at the intersection of the high-level view and the low-level view of the database. In other words, it provides the abstraction that appeals to nontechnical people while giving enough implementation details for the developers. A popular logical ER model notation is Crow's Foot notation.

The model is not too dissimilar to the conceptual model, except that all entities and relationships are modeled as tables. To abide by the relational schema conventions, we will need to clarify some relationships defined in the business requirements in terms of tables:
- The relationship <code>books</code> is represented by the table <code>Booking</code>.
- The relationship <code>checks_in</code> is represented by the table <code>ReservationCheckIn</code>
- The relationship <code>maintains</code> is represented by the table <code>Maintaining</code>.