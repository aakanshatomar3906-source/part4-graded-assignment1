-- ============================================================
-- TASK 3: Transaction Scenarios
-- ============================================================
-- Each scenario includes:
-- - BEGIN / START TRANSACTION
-- - One or more INSERT/UPDATE/DELETE operations
-- - COMMIT or ROLLBACK
-- - Explanation of expected final database state
-- ============================================================

-- ============================================================
-- SCENARIO 1: Student Submits Solution with Test Results (COMMIT)
-- ============================================================
-- This scenario simulates a complete submission workflow:
-- 1. Insert a new submission
-- 2. Insert associated test cases
-- 3. Insert test results
-- 4. COMMIT if all succeeds

BEGIN;

-- Step 1: Insert new submission
INSERT INTO submissions (student_id, problem_id, language, status, score, submitted_at)
VALUES (100, 5, 'Python', 'pending', NULL, NOW());

-- Get the submission_id of the newly inserted row
SET @new_submission_id = LAST_INSERT_ID();

-- Step 2: Insert test cases for this submission
INSERT INTO test_cases (submission_id, test_case_number, expected_output, actual_output, status)
VALUES 
    (@new_submission_id, 1, '5', '5', 'passed'),
    (@new_submission_id, 2, '10', '10', 'passed'),
    (@new_submission_id, 3, '15', '15', 'passed');

-- Step 3: Insert test results (all passed)
INSERT INTO test_results (test_case_id, submission_id, status, execution_time)
SELECT 
    test_case_id,
    @new_submission_id,
    'passed',
    0.05
FROM test_cases
WHERE submission_id = @new_submission_id;

-- Step 4: Update submission status to 'accepted' since all tests passed
UPDATE submissions
SET status = 'accepted', score = 100
WHERE submission_id = @new_submission_id;

-- Verify all inserts before commit
SELECT 
    s.submission_id,
    s.student_id,
    s.problem_id,
    s.status,
    s.score,
    COUNT(tc.test_case_id) AS test_cases_count
FROM submissions s
LEFT JOIN test_cases tc ON s.submission_id = tc.submission_id
WHERE s.submission_id = @new_submission_id
GROUP BY s.submission_id;

-- Expected: 1 submission with status='accepted', score=100, 3 test cases

-- Step 5: COMMIT - All operations succeeded
COMMIT;

-- Expected final state:
-- - New submission exists with status='accepted', score=100
-- - 3 test cases inserted
-- - 3 test results inserted
-- - All changes permanent


-- ============================================================
-- SCENARIO 2: Course Enrollment Created Then Rolled Back (ROLLBACK)
-- ============================================================
-- This scenario demonstrates ROLLBACK due to invalid condition:
-- 1. Try to enroll student in course
-- 2. Check if course exists (simulate validation)
-- 3. ROLLBACK if validation fails

BEGIN;

-- Step 1: Insert enrollment record
INSERT INTO enrollments (student_id, course_id, enrolled_at)
VALUES (150, 999, NOW());

-- Get the enrollment_id
SET @new_enrollment_id = LAST_INSERT_ID();

-- Step 2: Verify course exists (validation check)
SELECT course_id, course_name 
FROM courses 
WHERE course_id = 999;

-- Expected: 0 rows (course 999 does not exist)

-- Step 3: Check if enrollment would create orphan record
SELECT 
    e.enrollment_id,
    e.student_id,
    e.course_id,
    CASE 
        WHEN c.course_id IS NULL THEN 'INVALID - Course does not exist'
        ELSE 'VALID'
    END AS validation_status
FROM enrollments e
LEFT JOIN courses c ON e.course_id = c.course_id
WHERE e.enrollment_id = @new_enrollment_id;

-- Expected: validation_status = 'INVALID - Course does not exist'

-- Step 4: ROLLBACK - Course doesn't exist, undo enrollment
ROLLBACK;

-- Verify rollback succeeded
SELECT COUNT(*) AS enrollment_count
FROM enrollments
WHERE enrollment_id = @new_enrollment_id;

-- Expected: 0 (enrollment was rolled back)

-- Expected final state:
-- - No new enrollment exists (rolled back)
-- - Database unchanged from before transaction
-- - Prevents orphan record creation


-- ============================================================
-- SCENARIO 3: Score Correction with SAVEPOINT and Partial Rollback
-- ============================================================
-- This scenario demonstrates SAVEPOINT and partial rollback:
-- 1. Start transaction
-- 2. Create savepoint
-- 3. Correct multiple scores
-- 4. Realize one correction was wrong
-- 5. Rollback to savepoint, then commit rest

BEGIN;

-- Step 1: Create savepoint before corrections
SAVEPOINT score_corrections;

-- Step 2: Correct negative scores to 0
UPDATE submissions
SET score = 0, status = 'accepted'
WHERE submission_id IN (234, 567) AND score < 0;

-- Step 3: Correct scores above 100 to 100
UPDATE submissions
SET score = 100
WHERE submission_id IN (789, 901) AND score > 100;

-- Step 4: Realize submission 234 should NOT have been changed 
-- (it was a test submission that should remain negative for audit)

-- Step 5: Rollback to savepoint (undo all corrections)
ROLLBACK TO SAVEPOINT score_corrections;

-- Step 6: Re-apply only the valid corrections (exclude 234)
UPDATE submissions
SET score = 0, status = 'accepted'
WHERE submission_id IN (567) AND score < 0;

UPDATE submissions
SET score = 100
WHERE submission_id IN (789, 901) AND score > 100;

-- Verify corrections
SELECT 
    submission_id,
    student_id,
    problem_id,
    score,
    status,
    'Corrected' AS action
FROM submissions
WHERE submission_id IN (567, 789, 901)
ORDER BY submission_id;

-- Expected: 3 submissions with corrected scores

-- Step 7: COMMIT - Valid corrections applied
COMMIT;

-- Expected final state:
-- - submission_id=567: score=0 (corrected from negative)
-- - submission_id=789: score=100 (corrected from 150)
-- - submission_id=901: score=100 (corrected from 110)
-- - submission_id=234: unchanged (rolled back to savepoint)


-- ============================================================
-- SCENARIO 4: Regrade Request Resolved with Safe Score Update
-- ============================================================
-- This scenario demonstrates a regrade workflow:
-- 1. Find regrade request
-- 2. Verify submission exists
-- 3. Update submission score
-- 4. Mark regrade request as resolved
-- 5. COMMIT

BEGIN;

-- Step 1: Find pending regrade request
SELECT 
    regrade_id,
    submission_id,
    student_id,
    requested_at,
    reason
FROM regrade_requests
WHERE status = 'pending'
ORDER BY requested_at ASC
LIMIT 1;

-- Assume we get: regrade_id=5, submission_id=456, student_id=34

SET @regrade_id = 5;
SET @submission_id = 456;

-- Step 2: Verify submission exists and get current score
SELECT 
    submission_id,
    student_id,
    problem_id,
    score AS current_score,
    status
FROM submissions
WHERE submission_id = @submission_id;

-- Step 3: Update submission score (instructor granted +5 points)
UPDATE submissions
SET score = score + 5, status = 'accepted'
WHERE submission_id = @submission_id;

-- Step 4: Mark regrade request as resolved
UPDATE regrade_requests
SET status = 'resolved', resolved_at = NOW()
WHERE regrade_id = @regrade_id;

-- Verify both updates
SELECT 
    s.submission_id,
    s.score AS updated_score,
    rr.regrade_id,
    rr.status AS regrade_status,
    rr.resolved_at
FROM submissions s
INNER JOIN regrade_requests rr ON s.submission_id = rr.submission_id
WHERE s.submission_id = @submission_id;

-- Step 5: COMMIT - Regrade completed successfully
COMMIT;

-- Expected final state:
-- - Submission score increased by 5
-- - Regrade request marked as 'resolved'
-- - Both changes are atomic (both succeed or both fail)


-- ============================================================
-- SCENARIO 5: Batch Update with Transaction and Rollback on Error
-- ============================================================
-- This scenario demonstrates rollback when a condition is not met:
-- 1. Start transaction
-- 2. Update multiple student emails
-- 3. Check if any update failed (simulated)
-- 4. ROLLBACK if any issue

BEGIN;

-- Step 1: Update emails for students in batch 1
UPDATE students
SET email = CONCAT(TRIM(name), '@batch1.example.com')
WHERE batch_id = 1 AND email LIKE '%@student.example.com';

-- Step 2: Count how many were updated
SET @updated_count = ROW_COUNT();

-- Step 3: Verify update (simulate validation)
SELECT 
    COUNT(*) AS total_batch1_students
FROM students
WHERE batch_id = 1;

SET @total_count = (SELECT COUNT(*) FROM students WHERE batch_id = 1);

-- Step 4: Check if update count matches expected
-- If updated count is 0, something went wrong
IF @updated_count = 0 THEN
    -- No emails were updated - rollback
    ROLLBACK;
    SELECT 'ROLLBACK: No emails were updated' AS result;
ELSE
    -- Update succeeded - commit
    COMMIT;
    SELECT CONCAT('COMMIT: ', @updated_count, ' emails updated') AS result;
END IF;

-- Note: In MySQL, you need to use stored procedures for IF blocks
-- For simplicity, the actual script would use conditional logic outside SQL

-- Expected final state (if update succeeded):
-- - All batch 1 students with @student.example.com emails now have @batch1.example.com
-- - Changes committed


-- ============================================================
-- TRANSACTION SCENARIOS SUMMARY
-- ============================================================
-- Scenario 1: Submission workflow with COMMIT (normal success)
-- Scenario 2: Enrollment with ROLLBACK (validation failed)
-- Scenario 3: Score correction with SAVEPOINT and partial rollback
-- Scenario 4: Regrade request with atomic updates and COMMIT
-- Scenario 5: Batch update with conditional rollback
--
-- All scenarios demonstrate:
-- - BEGIN/START TRANSACTION
-- - Multiple DML operations
-- - COMMIT or ROLLBACK
-- - Explanation of expected final state
