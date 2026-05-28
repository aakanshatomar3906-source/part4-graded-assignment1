# Part 4 — Transactions, Safe Changes & DB Reliability

## Overview
This repository contains safe data-modification operations demonstrating DML, transaction control, rollback, commit, savepoints, and ACID properties for the Student Course Submission Database.

## Safety First
**IMPORTANT:** All operations are performed safely:
- Original database is NEVER modified directly
- UPDATE/DELETE operations include validation queries before and after
- All transactions use BEGIN/COMMIT/ROLLBACK
- Savepoints used for partial rollback scenarios

## Repository Structure

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `safe_updates.sql` | 4+ safe UPDATE operations with before/after validation |
| `safe_deletes.sql` | 2+ safe DELETE operations with validation |
| `transactions.sql` | 3+ transaction scenarios with COMMIT/ROLLBACK/SAVEPOINT |
| `acid_explanation.md` | ACID properties explanation using own transaction |
| `incident_note.md` | Reliability incident note for risky operation |

## Task Coverage

| Task | Description | File | Marks |
|------|-------------|------|-------|
| Task 1 | Safe UPDATE Operations (4+) | `safe_updates.sql` | 5 |
| Task 2 | Safe DELETE Operations (2+) | `safe_deletes.sql` | 3 |
| Task 3 | Transaction Scenarios (3+) | `transactions.sql` | 7 |
| Task 3b | COMMIT, ROLLBACK, SAVEPOINT | `transactions.sql` | 3 |
| Task 4 | ACID Explanation | `acid_explanation.md` | 4 |
| Task 5 | Reliability Incident Note | `incident_note.md` | 3 |

## How to Run

```bash
# MySQL
mysql -u username -p database_name < safe_updates.sql
mysql -u username -p database_name < safe_deletes.sql
mysql -u username -p database_name < transactions.sql
```

## Safety Measures Implemented

1. **Staging Tables** - All modifications tested on copies first
2. **Validation Queries** - SELECT before and after each operation
3. **Specific WHERE Clauses** - No blind updates/deletes
4. **Transaction Wrapping** - All operations in BEGIN/COMMIT/ROLLBACK
5. **Savepoints** - For partial rollback capability

## Author
AAKANSHA TOMAR
May 2026
