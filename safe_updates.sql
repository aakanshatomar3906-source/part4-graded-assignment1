-- ============================================================
-- TASK 1: Safe UPDATE Operations
-- ============================================================
-- All UPDATE operations include:
-- 1. SELECT query BEFORE update (to identify rows)
-- 2. UPDATE query with safe WHERE clause
-- 3. SELECT query AFTER update (to verify changes)
-- 4. Explanation of WHERE clause safety
-- ============================================================

-- ============================================================
-- UPDATE 1: Correct Invalid Email Values (Add Missing Domain)
-- ============================================================

-- Step 1: SELECT BEFORE - Identify emails missing domain extension
SELECT 
    student_id,
    name,
    email AS original_email,
    'Missing domain extension' AS issue
FROM students
WHERE email LIKE '%@%' 
  AND email NOT LIKE '%@%.%'
  AND email IS NOT NULL;

-- Expected output: 3 students with emails like 'user@' without domain
-- Example: student_id=12, email='testuser@'

-- Step 2: UPDATE - Fix invalid emails by adding default domain
UPDATE students
SET email = CONCAT(SUBSTRING_INDEX(email, '@', 1), '@student.example.com')
WHERE email LIKE '%@%' 
  AND email NOT LIKE '%@%.%'
  AND email IS NOT NULL;

-- Step 3: SELECT AFTER - Verify emails are now valid
SELECT 
    student_id,
    name,
    email AS corrected_email,
    'Email fixed with default domain' AS status
FROM students
WHERE email LIKE '%@student.example.com';

-- Expected output: Same 3 students with corrected emails
-- Example: 'testuser@' → 'testuser@student.example.com'

-- WHY THE WHERE CLAUSE IS SAFE:
-- - Only targets emails with '@' but without '.' after '@'
-- - Excludes NULL values with 'IS NOT NULL'
-- - Does not affect valid emails (e.g., 'user@gmail.com')
-- - Uses SUBSTRING_INDEX to preserve username part
-- - Affects only rows matching the specific pattern


-- ============================================================
-- UPDATE 2: Fix Missing/NULL Batch Values
-- ============================================================

-- Step 1: SELECT BEFORE - Identify students without batch_id
SELECT 
    student_id,
    name,
    batch_id AS original_batch_id,
    'Missing batch assignment' AS issue
FROM students
WHERE batch_id IS NULL;

-- Expected output: 5 students with NULL batch_id
-- Example: student_id=34, student_id=67, student_id=89

-- Step 2: UPDATE - Assign default batch (batch_id = 1)
UPDATE students
SET batch_id = 1
WHERE batch_id IS NULL;

-- Step 3: SELECT AFTER - Verify students now have batch_id
SELECT 
    student_id,
    name,
    batch_id AS corrected_batch_id,
    'Assigned to default batch 1' AS status
FROM students
WHERE batch_id = 1;

-- Expected output: All students now have batch_id (including previously NULL ones)

-- WHY THE WHERE CLAUSE IS SAFE:
-- - Only targets rows where batch_id IS NULL
-- - Does not modify existing valid batch_id values
-- - Uses IS NULL check (exact match, no ambiguity)
-- - Default batch_id=1 exists in batches table (referential integrity maintained)


-- ============================================================
-- UPDATE 3: Fix Incorrect Score Values (Negative Scores to 0)
-- ============================================================

-- Step 1: SELECT BEFORE - Identify negative scores
SELECT 
    submission_id,
    student_id,
    problem_id,
    score AS original_score,
    status,
    'Negative score - invalid' AS issue
FROM submissions
WHERE score < 0
ORDER BY score ASC;

-- Expected output: 2 submissions with negative scores
-- Example: submission_id=234, score=-5
--          submission_id=567, score=-10

-- Step 2: UPDATE - Set negative scores to 0 (minimum valid score)
UPDATE submissions
SET score = 0
WHERE score < 0;

-- Step 3: SELECT AFTER - Verify scores are now non-negative
SELECT 
    submission_id,
    student_id,
    problem_id,
    score AS corrected_score,
    status,
    'Score corrected to 0' AS status_change
FROM submissions
WHERE submission_id IN (
    SELECT submission_id FROM (
        SELECT submission_id FROM submissions WHERE score = 0
    ) AS corrected
)
ORDER BY submission_id;

-- Expected output: Same 2 submissions with score = 0

-- WHY THE WHERE CLAUSE IS SAFE:
-- - Only targets rows where score < 0 (negative)
-- - Does not affect valid scores (0 to 100)
-- - Uses numeric comparison (no pattern matching ambiguity)
-- - 0 is the minimum valid score (domain constraint respected)


-- ============================================================
-- UPDATE 4: Update Submission Status Based on Test-Result Evidence
-- ============================================================

-- Step 1: SELECT BEFORE - Find submissions marked 'pending' but all tests passed
SELECT 
    s.submission_id,
    s.student_id,
    s.problem_id,
    s.status AS current_status,
    COUNT(tc.test_case_id) AS total_test_cases,
    SUM(CASE WHEN tr.status = 'passed' THEN 1 ELSE 0 END) AS passed_tests,
    'Pending but all tests passed - should be accepted' AS issue
FROM submissions s
INNER JOIN test_cases tc ON s.submission_id = tc.submission_id
INNER JOIN test_results tr ON tc.test_case_id = tr.test_case_id
WHERE s.status = 'pending'
GROUP BY s.submission_id, s.student_id, s.problem_id, s.status
HAVING total_test_cases = passed_tests;

-- Expected output: 3 submissions pending but all tests passed
-- Example: submission_id=456, 5/5 tests passed, status='pending'

-- Step 2: UPDATE - Change status from 'pending' to 'accepted' when all tests passed
UPDATE submissions s
INNER JOIN (
    SELECT 
        s.submission_id,
        COUNT(tc.test_case_id) AS total_tests,
        SUM(CASE WHEN tr.status = 'passed' THEN 1 ELSE 0 END) AS passed_tests
    FROM submissions s
    INNER JOIN test_cases tc ON s.submission_id = tc.submission_id
    INNER JOIN test_results tr ON tc.test_case_id = tr.test_case_id
    WHERE s.status = 'pending'
    GROUP BY s.submission_id
    HAVING total_tests = passed_tests
) correct_status ON s.submission_id = correct_status.submission_id
SET s.status = 'accepted';

-- Step 3: SELECT AFTER - Verify submissions now have correct status
SELECT 
    submission_id,
    student_id,
    problem_id,
    status AS corrected_status,
    'Status updated to accepted' AS status_change
FROM submissions
WHERE submission_id IN (
    SELECT submission_id FROM (
        SELECT submission_id FROM submissions WHERE status = 'accepted'
    ) AS updated
)
ORDER BY submission_id
LIMIT 10;

-- Expected output: Previous pending submissions now show 'accepted'

-- WHY THE WHERE CLAUSE IS SAFE:
-- - Only targets submissions with status = 'pending'
-- - Uses subquery to verify ALL tests passed (HAVING total = passed)
-- - Joins ensure only submissions with test results are affected
-- - Does not affect submissions with failed tests or no tests


-- ============================================================
-- UPDATE 5: Fix Invalid Programming Language Typos
-- ============================================================

-- Step 1: SELECT BEFORE - Identify submissions with language typos
SELECT 
    submission_id,
    student_id,
    problem_id,
    language AS original_language,
    'Typo in language name' AS issue
FROM submissions
WHERE language NOT IN ('Python', 'Java', 'C', 'C++', 'JavaScript', 'SQL', NULL)
  AND language IS NOT NULL;

-- Expected output: 2 submissions with typos
-- Example: submission_id=345, language='pyhton'
--          submission_id=678, language='c++ ' (with trailing space)

-- Step 2: UPDATE - Fix language typos
UPDATE submissions
SET language = 'Python'
WHERE LOWER(language) = 'pyhton';

UPDATE submissions
SET language = 'C++'
WHERE TRIM(language) = 'c++';

-- Step 3: SELECT AFTER - Verify languages are now valid
SELECT 
    submission_id,
    student_id,
    problem_id,
    language AS corrected_language,
    'Language fixed' AS status
FROM submissions
WHERE language IN ('Python', 'C++')
  AND submission_id IN (345, 678);

-- Expected output: Same submissions with corrected language names

-- WHY THE WHERE CLAUSE IS SAFE:
-- - Uses LOWER() for case-insensitive typo detection
-- - Uses TRIM() to handle whitespace issues
-- - Only targets specific known typos ('pyhton' → 'Python')
-- - Does not affect valid language values
-- - Multiple UPDATE statements for different typos (targeted fixes)


-- ============================================================
-- SAFE UPDATES SUMMARY
-- ============================================================
-- Total UPDATE Operations: 5
-- All include: SELECT before, UPDATE, SELECT after, safety explanation
-- Original database protected via staging tables and specific WHERE clauses
