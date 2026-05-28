
-- Create an isolated staging area for data scrubbing and repair
CREATE SCHEMA IF NOT EXISTS staging_repair;

-- Duplicate core tables along with their imported raw datasets
CREATE TABLE staging_repair.students AS SELECT * FROM public.students;
CREATE TABLE staging_repair.courses AS SELECT * FROM public.courses;
CREATE TABLE staging_repair.enrollments AS SELECT * FROM public.enrollments;
CREATE TABLE staging_repair.contests AS SELECT * FROM public.contests;
CREATE TABLE staging_repair.submissions AS SELECT * FROM public.submissions;
CREATE TABLE staging_repair.test_results AS SELECT * FROM public.test_results;
CREATE TABLE staging_repair.operation_requests AS SELECT * FROM public.operation_requests;
