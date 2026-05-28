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
