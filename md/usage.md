# Running the CS486 Database System on MS SQL Server

This guide explains how to set up the database, insert the sample data, and run queries using Microsoft SQL Server.

## Prerequisites

Ensure you have one of the following tools installed:
- **SQL Server Management Studio (SSMS)** (Recommended for Windows users)
- **Azure Data Studio** (Cross-platform GUI)
- **sqlcmd** command-line utility

---

## Step 1: Create the Database & Schema (DDL)

The database schema, lookup tables, and constraint triggers are defined in `outputs/05-db-definition-G06.sql`.

### Using SSMS / Azure Data Studio:
1. Open SSMS or Azure Data Studio and connect to your SQL Server instance.
2. Open the file `outputs/05-db-definition-G06.sql` (`File -> Open -> File...`).
3. Press **F5** (or click the **Execute** button).
4. This script will:
   - Create a database named `School`.
   - Create schemas `lookup_table` and `junction_table`.
   - Define all operational tables in their respective schemas.
   - Install data integrity checks and trigger rules.
   - Populate static lookup categories (roles, types, statuses, etc.).

---

## Step 2: Insert Sample Data (DML)

Realistic mock records are provided in `outputs/06-sample-data-G06.sql`.

### Using SSMS / Azure Data Studio:
1. Open the file `outputs/06-sample-data-G06.sql` in your SQL tool.
2. Make sure the active connection points to the `School` database (or verify the top of the file contains `USE School`).
3. Press **F5** (or click the **Execute** button).
4. This script will populate:
   - Space policies and rooms (`Space`).
   - Mock users, roles, and departments (`User`).
   - Booking requests, reviews, reservations, check-ins, and maintenance records.

---

## Step 3: Running Queries

To test or query the database:
1. Open `outputs/07-query-design-G06.sql` (once generated).
2. Select individual queries (or highlight specific sections of SQL) and execute them via **F5**.
3. View results in the bottom grid panel.

---

## Command Line Execution (Alternative)

If you prefer using the command line with `sqlcmd`:

```powershell
# 1. Initialize database, schema, and lookup values
sqlcmd -S localhost -E -i outputs\05-db-definition-G06.sql

# 2. Populate sample data
sqlcmd -S localhost -E -d School -i outputs\06-sample-data-G06.sql

# 3. (Optional) Run query designs
sqlcmd -S localhost -E -d School -i outputs\07-query-design-G06.sql
```
*(Note: Replace `-E` with `-U sa -P <your_password>` if you are not using Windows Authentication)*
