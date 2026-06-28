# Conceptual ER model
The conceptual ER model provides a high-level view of the database model without bothering too much about the nitty-gritty implementation and physical details of the database. Based on the analyzed business requirements, we have outlined the entities, attributes, relationships, cardinalities, and constraints of each element that comes into play. The diagram notation we use&mdash;Chen notation&mdash;visualize these facts.

As a quick refresher on how to read the diagram, this section provides a quick review on Chen diagram for one's perusal. We also outline custom notations we also devised that is not standard to Chen notation, but serves to be convenient for our purpose.
- Operational entities (referred to as entities) are represented by a red rectangle. Entities usually contain attributes which are notated by a silver oval with a line connecting to that entity. Underlined attributes are unique. A composite attribute is notated by "attributes of attributes", where silver ovals are connected to that attribute.
- Reference entities are represented by a cyan rounded rectangle. Technically, reference entities also contain attributes, but due to the fact that they are often easily obtained (see business requirements), they are trimmed in the diagram to reduce clutter.
- Associative entities are represented by a teal rhombus inscribed in a teal rectangle. Like operational entities, they have attributes. Because they are also functionally similar to a relationship, they can be connected to other entites. The endpoints of each participating entitiy and the associative entity itself is attached the entities' cardinalities.
- Relationships are representeed by a riverbed colored rhombus. Relationships link entities together, while displaying their cardinalities on their respective endpoints. A single line implies partial participation, while a double line implies total participation.

Now that we have established the notation, the diagram is given as follows:

![diagram](../assets/conceptual.svg)

The diagram was made in drawio.