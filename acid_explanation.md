# ACID Properties Explanation

## Overview
This document explains how ACID (Atomicity, Consistency, Isolation, Durability) properties apply to **Scenario 1: Student Submits Solution with Test Results** from our transaction scripts.

---

## Transaction Scenario: Student Submission Workflow

```sql
BEGIN;

-- Insert new submission
INSERT INTO submissions (student_id, problem_id, language, status, score, submitted_at)
VALUES (100, 5, 'Python', 'pending', NULL, NOW());

SET @new_submission_id = LAST_INSERT_ID();

-- Insert test cases
INSERT INTO test_cases (submission_id, test_case_number, expected_output, actual_output, status)
VALUES 
    (@new_submission_id, 1, '5', '5', 'passed'),
    (@new_submission_id, 2, '10', '10', 'passed'),
    (@new_submission_id, 3, '15', '15', 'passed');

-- Insert test results
INSERT INTO test_results (test_case_id, submission_id, status, execution_time)
SELECT test_case_id, @new_submission_id, 'passed', 0.05
FROM test_cases
WHERE submission_id = @new_submission_id;

-- Update submission status
UPDATE submissions
SET status = 'accepted', score = 100
WHERE submission_id = @new_submission_id;

COMMIT;
```

---

## 1. Atomicity

### Definition
**All operations in the transaction succeed, or all fail.** The transaction is treated as a single indivisible unit.

### How It Applies Here
This transaction performs 4 operations:
1. Insert submission record
2. Insert 3 test case records
3. Insert 3 test result records
4. Update submission status to 'accepted'

**With Atomicity:**
- If ALL 4 operations succeed → `COMMIT` makes all changes permanent
- If ANY operation fails (e.g., foreign key violation, constraint error) → `ROLLBACK` undoes all changes

**Example of Atomicity in Action:**
Scenario: Test results insert fails due to constraint violation

Before transaction:

submissions: 1,247 rows

test_cases: 6,235 rows

test_results: 31,175 rows

After failed transaction (rolled back):

submissions: 1,247 rows (unchanged)

test_cases: 6,235 rows (unchanged)

test_results: 31,175 rows (unchanged)

Result: Database is exactly as before - no partial changes


### Why It Matters
Without atomicity, we could end up with:
- Submission inserted but no test cases → orphaned submission
- Test cases inserted but no test results → incomplete data
- Test results inserted but submission marked 'pending' → inconsistent state

---

## 2. Consistency

### Definition
**The database moves from one valid state to another valid state.** All constraints (primary keys, foreign keys, checks) are maintained.

### How It Applies Here
This transaction maintains several constraints:

| Constraint | How It's Maintained |
|------------|---------------------|
| Primary Key (submission_id) | New submission gets unique auto-increment ID |
| Foreign Key (test_cases.submission_id) | Test cases reference valid submission_id |
| Foreign Key (test_results.test_case_id) | Test results reference valid test_case_id |
| Check (score 0-100) | Final score = 100 (within valid range) |
| Check (status values) | Status transitions: 'pending' → 'accepted' |

**Before Transaction:**
- submissions table: Consistent state (all constraints valid)

**After Transaction:**
- submissions table: Still consistent (new row satisfies all constraints)
- test_cases table: Consistent (all foreign keys valid)
- test_results table: Consistent (all foreign keys valid)

**Example of Consistency Violation (Prevented):**
Without transaction:

Insert submission ✓

Insert test case with invalid submission_id ✗

Result: Database in inconsistent state (orphan test case)

With transaction:

Insert submission ✓

Insert test case with invalid submission_id ✗

ROLLBACK (entire transaction undone)

Result: Database stays in consistent state

### Why It Matters
Consistency ensures:
- No orphan records (all foreign keys valid)
- No invalid scores (0-100 range maintained)
- No invalid statuses (only allowed values exist)
- Business rules are enforced (submission must have test cases)

---

## 3. Isolation

### Definition
**Concurrent transactions do not interfere with each other.** Each transaction sees a consistent snapshot of the database.

### How It Applies Here
Imagine two students submit solutions simultaneously:

**Transaction A (Student 100):**
```sql
BEGIN;
INSERT INTO submissions (student_id, ...) VALUES (100, ...);
-- Still running...
```

**Transaction B (Student 101):**
```sql
BEGIN;
INSERT INTO submissions (student_id, ...) VALUES (101, ...);
-- Completes and COMMITs
```

**With Isolation:**
- Transaction A sees the database as if Transaction B hasn't happened yet
- Transaction A gets its own unique submission_id (no conflict)
- Both transactions complete independently

**Isolation Levels:**
| Level | Dirty Read | Non-Repeatable Read | Phantom Read |
|-------|------------|---------------------|--------------|
| READ UNCOMMITTED | ✗ Possible | ✗ Possible | ✗ Possible |
| READ COMMITTED | ✓ Protected | ✗ Possible | ✗ Possible |
| REPEATABLE READ (MySQL default) | ✓ Protected | ✓ Protected | ✗ Possible |
| SERIALIZABLE | ✓ Protected | ✓ Protected | ✓ Protected |

**Example Without Isolation (Dirty Read):**
Transaction A: INSERT submission (not yet committed)
Transaction B: SELECT * FROM submissions (sees A's uncommitted row)
Transaction A: ROLLBACK (row never existed)

Result: Transaction B saw data that never existed → Dirty Read

### Why It Matters
Isolation prevents:
- Two submissions getting the same ID
- Reading uncommitted (possibly rolled back) data
- Counting rows that may be rolled back

---

## 4. Durability

### Definition
**Once committed, changes are permanent and survive system failures.**

### How It Applies Here
After `COMMIT` is executed:

```sql
COMMIT;
```

**Durability Guarantees:**
- Changes are written to disk (not just memory)
- Even if power fails immediately after COMMIT, data persists
- Database recovery will restore these changes

**Example of Durability:**
Timeline:
12:00:00 PM - Transaction starts
12:00:01 PM - All INSERTs and UPDATEs complete
12:00:02 PM - COMMIT executed ✓
12:00:03 PM - Power failure (server crashes)

After server restart:

Submission for student 100 EXISTS (committed before crash)

Test cases EXIST

Test results EXIST

Result: All changes survived the crash

**How Durability is Achieved:**
- Write-ahead logging (WAL) - changes logged before being applied
- Transaction log flushed to disk on COMMIT
- Recovery process replays log after crash

### Why It Matters
Durability ensures:
- Student's submission is not lost after crash
- Grades/scores are permanently recorded
- Test results are preserved
- No data loss after system failures

---

## Summary Table

| ACID Property | What It Guarantees | In Our Transaction |
|---------------|-------------------|-------------------|
| **Atomicity** | All or nothing | Either all 4 operations succeed, or none do |
| **Consistency** | Valid state to valid state | All constraints maintained (FK, PK, checks) |
| **Isolation** | No interference | Concurrent submissions don't conflict |
| **Durability** | Permanent after commit | Data survives power failures/crashes |

---

## Visual Representation
┌─────────────────────────────────────────────────────────────┐
│ TRANSACTION EXECUTION │
├─────────────────────────────────────────────────────────────┤
│ │
│ BEGIN │
│ │ │
│ ▼ │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ INSERT │───▶│ INSERT │───▶│ INSERT │ │
│ │ submission │ │ test_cases │ │ test_results │ │
│ └──────────────┘ └──────────────┘ └──────────────┘ │
│ │ │ │
│ └──────────────────────────────────────┘ │
│ │ │
│ ▼ │
│ ┌──────────────┐ │
│ │ UPDATE │ │
│ │ status=accepted│ │
│ └──────────────┘ │
│ │ │
│ ▼ │
│ ┌──────────────┐ │
│ │ COMMIT │◀─── Atomicity: All or │
│ └──────────────┘ nothing │
│ │ │
│ ┌────────────┴────────────┐ │
│ ▼ ▼ │
│ ┌─────────────┐ ┌─────────────┐ │
│ │ Consistency│ │ Isolation │ │
│ │ (constraints│ │ (no conflict│ │
│ │ maintained)│ │ with others)│ │
│ └─────────────┘ └─────────────┘ │
│ │ │
│ ▼ │
│ ┌──────────────┐ │
│ │ Durability │◀─── Permanent after │
│ │ (survives │ COMMIT │
│ │ crashes) │ │
│ └──────────────┘ │
│ │
└─────────────────────────────────────────────────────────────┘

text

---

## Conclusion

This submission transaction demonstrates all four ACID properties:

1. **Atomicity** ensures the entire submission workflow succeeds or fails together
2. **Consistency** ensures all database constraints are maintained
3. **Isolation** ensures concurrent submissions don't interfere
4. **Durability** ensures the submission is never lost after commit

Without ACID properties, the database would be prone to data corruption, inconsistencies, and loss of critical information like student submissions and grades.
File 6: incident_note.md
text
# Reliability Incident Note

## Incident: Accidental UPDATE Without WHERE Clause

---

## Date
May 28, 2026

## Affected Database
CodeJudge Database (Student Course Submission System)

---

## What Went Wrong

A developer ran the following SQL command during a code review session:

```sql
UPDATE submissions
SET status = 'accepted', score = 100;
```

**Critical Error:** The statement is missing a `WHERE` clause.

---

## What Data Could Be Affected

### Scope of Impact
| Table | Total Rows | Potentially Affected |
|-------|------------|---------------------|
| submissions | 1,247 | **ALL 1,247 rows** |

### Specific Impact
1. **All submissions** would be marked as 'accepted' regardless of actual test results
2. **All scores** would be set to 100 regardless of actual performance
3. **Students who failed** would appear to have passed
4. **Leaderboard/ranking** would be completely inaccurate
5. **Success rate calculations** would show 100% (false data)

### Real Consequences
- Student 234 (score=-5, status='wrong_answer') → score=100, status='accepted'
- Student 456 (score=45, 3/5 tests passed) → score=100, status='accepted'
- Student 789 (score=150, status='accepted') → score=100, status='accepted'
- **All 234 unsuccessful submissions** would appear successful

---

## How the Issue Could Be Detected

### Immediate Detection (Before Execution)
1. **Code Review** - Another developer spots missing WHERE clause
2. **SQL Linter** - Tool flags UPDATE without WHERE as warning
3. **Dry Run** - Running `SELECT * FROM submissions WHERE 1=1` first shows scope

### After Execution (If Not Caught)
1. **Row Count Mismatch** - All rows show same status unexpectedly
2. **Anomaly Detection** - Success rate jumps from 42% to 100%
3. **Student Complaints** - Students report incorrect grades
4. **Dashboard Alert** - Grade distribution looks suspicious

### Detection Query
```sql
-- Suspicious pattern: All submissions have same status
SELECT status, COUNT(*) 
FROM submissions 
GROUP BY status;
-- If only 'accepted' exists with 1,247 count → problem detected
```

---

## How Rollback, Backups, or Transactions Could Help

### 1. Transaction Wrapping (Prevention)
```sql
-- Wrap in transaction FIRST
START TRANSACTION;

UPDATE submissions
SET status = 'accepted', score = 100;

-- Check effect before committing
SELECT COUNT(*) FROM submissions WHERE status = 'accepted';

-- If something looks wrong:
ROLLBACK;

-- If correct:
COMMIT;
```

**Benefit:** Even if the wrong query runs, `ROLLBACK` undoes all changes.

### 2. Backup Before Bulk Operations
```sql
-- Create backup before any bulk update
CREATE TABLE submissions_backup_20260528 AS
SELECT * FROM submissions;

-- Then run the update
UPDATE submissions
SET status = 'accepted', score = 100
WHERE student_id = 100;  -- Now with WHERE

-- If something goes wrong:
UPDATE submissions s
INNER JOIN submissions_backup_20260528 b ON s.submission_id = b.submission_id
SET s.status = b.status, s.score = b.score;
```

**Benefit:** Can restore from backup if update goes wrong.

### 3. Automatic Rollback on Error
```sql
SET SQL_MODE = 'STRICT_ALL_TABLES';

-- This will cause error on invalid data, triggering rollback
START TRANSACTION;
UPDATE submissions SET status = 'invalid_status';  -- Invalid value
-- Error: Check constraint fails
ROLLBACK;  -- Automatic or manual
```

**Benefit:** Database rejects invalid data, preventing corruption.

---

## Preventive Measures for Future

### 1. **Always Use Transactions for DML**
```sql
-- GOOD PRACTICE
START TRANSACTION;

-- Step 1: Verify what will be affected
SELECT * FROM submissions 
WHERE [your_condition]
LIMIT 10;

-- Step 2: Run UPDATE
UPDATE submissions 
SET status = 'accepted'
WHERE [SPECIFIC_CONDITION];  -- ALWAYS include WHERE

-- Step 3: Verify changes
SELECT * FROM submissions 
WHERE [your_condition];

-- Step 4: Commit or rollback
COMMIT;  -- or ROLLBACK if something wrong
```

### 2. **Use SQL Safe Mode**
```sql
-- Enable safe update mode (MySQL)
SET SQL_SAFE_UPDATES = 1;

-- This prevents UPDATE/DELETE without WHERE or LIMIT
-- Query will fail with error instead of executing
```

### 3. **Always SELECT First**
```sql
-- Step 1: SELECT to see what will be affected
SELECT submission_id, status, score
FROM submissions
WHERE student_id = 100;

-- Step 2: Then UPDATE with same WHERE
UPDATE submissions
SET status = 'accepted', score = 100
WHERE student_id = 100;
```

### 4. **Code Review Checklist**
Before executing any DML:
- [ ] Is there a WHERE clause?
- [ ] Was the query tested on a staging table?
- [ ] Is a backup created?
- [ ] Is the query wrapped in a transaction?
- [ ] Can I rollback if needed?

### 5. **Use Staging Tables**
```sql
-- Create staging table
CREATE TABLE submissions_staging AS
SELECT * FROM submissions WHERE [condition];

-- Test updates on staging
UPDATE submissions_staging SET status = 'accepted';

-- Verify results
SELECT * FROM submissions_staging;

-- Then apply to production
UPDATE submissions 
SET status = 'accepted'
WHERE [same_condition];
```

### 6. **Automated Testing**
```sql
-- Create a test database
CREATE DATABASE codejudge_test;
-- Import subset of data
-- Test all DML operations
-- Then deploy to production
```

---

## Lessons Learned

| Lesson | Action |
|--------|--------|
| Never run DML without WHERE | Always double-check queries |
| Always use transactions | Wraps operations, enables rollback |
| Test on staging first | Use copy of database for testing |
| Create backups |Backup before any bulk operation |
| Enable safe mode | SQL_SAFE_UPDATES prevents accidents |
| Code review | Another pair of eyes catches errors |

---

## Incident Resolution (If This Happened)

### Immediate Actions
1. **STOP** - Do not execute more queries
2. **ROLLBACK** - If still in transaction: `ROLLBACK;`
3. **RESTORE** - If committed, restore from backup:
```sql
-- Restore from backup
UPDATE submissions s
INNER JOIN submissions_backup_20260528 b 
ON s.submission_id = b.submission_id
SET s.status = b.status, s.score = b.score;
```

4. **VERIFY** - Check data integrity after restoration
5. **DOCUMENT** - Record what happened and prevent recurrence

---

## Contact
If you find suspicious data patterns, contact:
- Database Administrator
- Development Team Lead
- Review the transaction logs

---

**Remember:** A single missing `WHERE` clause can corrupt thousands of records. Always code carefully, use transactions, and maintain backups.

