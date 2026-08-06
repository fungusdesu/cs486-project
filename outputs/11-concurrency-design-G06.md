# Concurrency design
As of now, the database is working as intended and accurately models the miniworld. However, as the user base grows, arises also the vulnerabilities that were not as apparent for small-scaled operations. These primarily stem from the fact that the database is not yet designed to handle concurrent events appropriately. This section is dedicated for just that.

# Stored procedures
The first step is to first group common operations into stored procedures. To this end, we shall design the procedures by declaring its name, parameters, purpose, and rough implementation.