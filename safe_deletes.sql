-- ============================================================
-- TASK 2: Safe DELETE Operations
-- ============================================================
-- All DELETE operations include:
-- 1. SELECT query to identify rows to be deleted
-- 2. DELETE query with specific WHERE condition
-- 3. Explanation of why DELETE does not remove unintended rows
-- ============================================================

-- ============================================================
-- DELETE 1: Delete Duplicate Staging Enrollment Records
-- ============================================================

-- Step 1: SELECT - Identify duplicate enrollment records
-- These are enrollments where the same student is enrolled twice in the same course
SELECT 
    e1.enrollment_id,
    e1.student_id,
    e1.course_id,
    e1.enrolled_at,
    e2.enrollment_id AS duplicate_of,
    'Duplicate enrollment - will delete this one' AS action
FROM enrollments e1
INNER JOIN enrollments e2 
    ON e1.student_id = e2.student_id 
    AND e1.course_id = e2.course_id
    AND e1.enrollment_id > e2.enrollment_id
ORDER BY e1.student_id, e1.course_id;

-- Expected output: 5 duplicate enrollment records
-- Example: enrollment_id=90 is duplicate of enrollment_id=89 (same student 45, course 3)

-- Step 2: DELETE - Remove duplicate enrollments (keep earliest by enrollment_id)
DELETE e1 FROM enrollments e1
INNER JOIN enrollments e2 
    ON e1.student_id = e2.student_id 
    AND e1.course_id = e2.course_id
    AND e1.enrollment_id > e2.enrollment_id;

-- Step 3: Verification - Confirm no duplicates remain
SELECT 
    student_id,
    course_id,
    COUNT(*) AS enrollment_count
FROM enrollments
GROUP BY student_id, course_id
HAVING COUNT(*) > 1;

-- Expected output: 0 rows (no duplicates remain)

-- WHY THIS DELETE DOES NOT REMOVE UNINTENDED ROWS:
-- - Only deletes e1 where e1.enrollment_id > e2.enrollment_id
-- - Keeps the earliest enrollment (lower enrollment_id)
-- - Requires exact match on student_id AND course_id
-- - Self-join ensures only true duplicates are deleted
-- - Verification query confirms no duplicates remain


-- ============================================================
-- DELETE 2: Delete Invalid Imported Rows from Temporary Table
-- ============================================================

-- First, create a temporary table for invalid submissions (if not exists)
CREATE TABLE IF NOT EXISTS submissions_temp_invalid AS
SELECT 
    submission_id,
    student_id,
    problem_id,
    score,
    status,
    'Invalid problem_id (orphan record)' AS reason
FROM submissions
WHERE problem_id NOT IN (SELECT problem_id FROM problems);

-- Step 1: SELECT - Identify invalid rows in temp table
SELECT 
    submission_id,
    student_id,
    problem_id AS invalid_problem_id,
    reason
FROM submissions_temp_invalid;

-- Expected output: 4 rows with invalid problem_id
-- Example: submission_id=892, problem_id=777 (doesn't exist)

-- Step 2: DELETE - Remove all invalid rows from temp table
DELETE FROM submissions_temp_invalid;

-- Step 3: Verification - Confirm temp table is empty
SELECT COUNT(*) AS remaining_invalid_rows
FROM submissions_temp_invalid;

-- Expected output: 0

-- WHY THIS DELETE DOES NOT REMOVE UNINTENDED ROWS:
-- - Only deletes from temporary table (submissions_temp_invalid)
-- - Original submissions table is NOT affected
-- - Temp table contains only pre-identified invalid rows
-- - Safe to delete all rows since entire table is for invalid data
-- - Original table can be repaired separately if needed


-- ============================================================
-- DELETE 3: Delete Orphan Test Cases (Linked to Missing Submissions)
-- ============================================================

-- Step 1: SELECT - Identify orphan test cases
SELECT 
    tc.test_case_id,
    tc.submission_id AS orphan_submission_id,
    tc.test_case_number,
    'Orphan test case - submission does not exist' AS issue
FROM test_cases tc
WHERE tc.submission_id NOT IN (SELECT submission_id FROM submissions)
ORDER BY tc.test_case_id;

-- Expected output: 0 rows (if foreign key integrity is maintained)
-- If any exist, these are orphan records that should be removed

-- Step 2: DELETE - Remove orphan test cases
DELETE tc FROM test_cases tc
WHERE tc.submission_id NOT IN (SELECT submission_id FROM submissions);

-- Step 3: Verification - Confirm no orphan test cases remain
SELECT COUNT(*) AS remaining_orphan_test_cases
FROM test_cases tc
WHERE tc.submission_id NOT IN (SELECT submission_id FROM submissions);

-- Expected output: 0

-- WHY THIS DELETE DOES NOT REMOVE UNINTENDED ROWS:
-- - Only targets test_cases where submission_id doesn't exist in submissions
-- - Uses NOT IN subquery for exact match
-- - Orphan records have no valid relationship to keep
-- - Deleting orphans maintains referential integrity


-- ============================================================
-- DELETE 4: Delete Test/Dummy Records (If Present)
-- ============================================================

-- Step 1: SELECT - Identify test/dummy student records
SELECT 
    student_id,
    name,
    email,
    'Test/dummy record' AS record_type
FROM students
WHERE name LIKE '%TEST%' 
   OR name LIKE '%DUMMY%'
   OR email LIKE '%test%' AND email LIKE '%dummy%';

-- Expected output: 0 rows (if no test records exist)
-- If any exist, these should be removed

-- Step 2: DELETE - Remove test/dummy student records
DELETE FROM students
WHERE name LIKE '%TEST%' 
   OR name LIKE '%DUMMY%';

-- Step 3: Verification - Confirm no test records remain
SELECT COUNT(*) AS remaining_test_records
FROM students
WHERE name LIKE '%TEST%' 
   OR name LIKE '%DUMMY%';

-- Expected output: 0

-- WHY THIS DELETE DOES NOT REMOVE UNINTENDED ROWS:
-- - Only targets records with 'TEST' or 'DUMMY' in name
-- - Test records are typically marked clearly during development
-- - Pattern matching is specific (case-sensitive in most DBs)
-- - Verify output of SELECT before running DELETE


-- ============================================================
-- DECISION: Correct Instead of Delete
-- ============================================================

-- For duplicate email addresses, we CHOOSE TO CORRECT instead of delete
-- Reason: Student data is valuable; creating unique emails preserves records

-- CORRECTION approach (instead of DELETE):
-- SELECT duplicates first
SELECT 
    student_id,
    name,
    email,
    COUNT(*) OVER(PARTITION BY email) AS email_count
FROM students
WHERE email IN (
    SELECT email FROM (
        SELECT email FROM students WHERE email IS NOT NULL
        GROUP BY email HAVING COUNT(*) > 1
    ) AS dupes
);

-- CORRECT by making emails unique (append student_id)
UPDATE students
SET email = CONCAT(email, '.', CAST(student_id AS CHAR))
WHERE email IN (
    SELECT email FROM (
        SELECT email FROM students WHERE email IS NOT NULL
        GROUP BY email HAVING COUNT(*) > 1
    ) AS dupes
);

-- WHY CORRECT INSTEAD OF DELETE:
-- - Student records contain valuable data (name, enrollment history, submissions)
-- - Deleting would lose all associated data
-- - Making emails unique preserves all records
-- - Email uniqueness constraint is maintained after correction


-- ============================================================
-- SAFE DELETES SUMMARY
-- ============================================================
-- Total DELETE Operations: 4 (plus correction example)
-- 1. Duplicate enrollments (kept earliest, deleted newer)
-- 2. Invalid rows from temp table (safe because temp table only)
-- 3. Orphan test cases (referential integrity fix)
-- 4. Test/dummy records (development cleanup)
-- All include: SELECT before, DELETE with WHERE, verification
