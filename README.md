
## Query Categories

| Category | Queries |
|----------|---------|
| Basic Retrieval & Filtering | 1-5 |
| Joins | 6-10 |
| Aggregation & HAVING | 11-15 |
| Subqueries & Set Logic | 16-20 |

## How to Run

```bash
# MySQL
mysql -u username -p database_name < queries.sql

# PostgreSQL
psql -U username -d database_name -f queries.sql

# SQLite
sqlite3 database.db < queries.sql
```

## Validation Approach

Each query includes:
1. Purpose comment
2. SQL query
3. Sample output summary
4. Validation note

## Marks Breakdown

| Component | Marks | Location |
|-----------|-------|----------|
| Correct SQL queries | 8 | `queries.sql` |
| Joins, aggregation, subquery correctness | 5 | Queries 6-20 |
| Output documentation & validation | 3 | `query_outputs.md` |
| SQL reasoning explanations | 3 | `sql_reasoning.md` |
| Code organization & readability | 1 | Consistent formatting |

## Author
AAKANSHA TOMAR 
May 2026
