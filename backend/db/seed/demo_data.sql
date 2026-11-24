-- Demo / test data for LOCAL and TEST only (applied by `go run ./cmd/seed`).
-- Gives every module 20-30 realistic rows. All demo accounts use the shared
-- development password; the hash placeholder below is replaced by the seed tool.
-- The tool refuses staging/production and non-local database hosts, and skips
-- itself when demo.learner01@example.test already exists, so this file is
-- applied at most once per database. It runs inside one transaction.

START TRANSACTION;
SET @pw = '{{PASSWORD_HASH}}';

CREATE TEMPORARY TABLE seq30 (n INT PRIMARY KEY);
INSERT INTO seq30 VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30);
CREATE TEMPORARY TABLE seq3 (n INT PRIMARY KEY);
INSERT INTO seq3 VALUES (1),(2),(3);
CREATE TEMPORARY TABLE seq2 (n INT PRIMARY KEY);
INSERT INTO seq2 VALUES (1),(2);

-- ------------------------------------------------------------------ users
INSERT INTO users (role_id, email, password_hash, status, email_verified_at)
SELECT r.id, CONCAT('demo.learner', LPAD(s.n,2,'0'), '@example.test'), @pw, 'active', NOW()
FROM seq30 s JOIN roles r ON r.code = 'LEARNER' WHERE s.n <= 25;

INSERT INTO users (role_id, email, password_hash, status, email_verified_at)
SELECT r.id, CONCAT('demo.instructor', s.n, '@example.test'), @pw, 'active', NOW()
FROM seq30 s JOIN roles r ON r.code = 'INSTRUCTOR' WHERE s.n <= 5;

INSERT INTO users (role_id, email, password_hash, status, email_verified_at)
SELECT r.id, CONCAT('demo.employer', s.n, '@example.test'), @pw, 'active', NOW()
FROM seq30 s JOIN roles r ON r.code = 'EMPLOYER' WHERE s.n <= 3;

INSERT INTO users (role_id, email, password_hash, status, email_verified_at)
SELECT r.id, 'demo.corpadmin@example.test', @pw, 'active', NOW() FROM roles r WHERE r.code = 'CORP_ADMIN';
INSERT INTO users (role_id, email, password_hash, status, email_verified_at)
SELECT r.id, 'demo.corpmanager@example.test', @pw, 'active', NOW() FROM roles r WHERE r.code = 'CORP_MANAGER';
INSERT INTO users (role_id, email, password_hash, status, email_verified_at)
SELECT r.id, 'demo.admin@example.test', @pw, 'active', NOW() FROM roles r WHERE r.code = 'ADMIN';

INSERT INTO profiles (user_id, first_name, last_name, title, location)
SELECT u.id,
       CONCAT(UPPER(LEFT(SUBSTRING_INDEX(SUBSTRING_INDEX(u.email, '@', 1), '.', -1), 1)),
              SUBSTRING(SUBSTRING_INDEX(SUBSTRING_INDEX(u.email, '@', 1), '.', -1), 2)),
       'Demo', 'Demo account', 'Bangkok'
FROM users u WHERE u.email LIKE 'demo.%@example.test';

INSERT INTO instructors (user_id, headline, expertise, rating_avg, total_students, verified_at)
SELECT u.id, 'Demo instructor', JSON_ARRAY('Backend', 'Cloud'), 4.50, 0, NOW()
FROM users u WHERE u.email LIKE 'demo.instructor%@example.test';

INSERT INTO employers (user_id, company_name, website)
SELECT u.id, CONCAT('Demo Company ', RIGHT(SUBSTRING_INDEX(u.email, '@', 1), 1)), 'https://example.test'
FROM users u WHERE u.email LIKE 'demo.employer%@example.test';

INSERT INTO portfolios (user_id, headline, summary)
SELECT u.id, 'Demo learner portfolio', 'Sample portfolio used for job application tests.'
FROM users u WHERE u.email LIKE 'demo.learner%@example.test';

-- ------------------------------------------------------------- catalogue
INSERT IGNORE INTO categories (name_th, name_en, slug, icon)
SELECT CONCAT('หมวดหมู่ทดสอบ ', LPAD(s.n,2,'0')), CONCAT('Demo category ', LPAD(s.n,2,'0')),
       CONCAT('demo-category-', LPAD(s.n,2,'0')), 'folder'
FROM seq30 s WHERE s.n <= 15;

INSERT INTO courses (instructor_id, category_id, title, slug, description, level, language,
                     price, duration_minutes, status, published_at)
SELECT i.id, c.id, CONCAT('Demo Course ', LPAD(s.n,2,'0')), CONCAT('demo-course-', LPAD(s.n,2,'0')),
       CONCAT('Sample course number ', s.n, ' for testing catalogue, learning and checkout flows.'),
       ELT((s.n MOD 3) + 1, 'beginner', 'intermediate', 'advanced'), 'th',
       290 + (s.n MOD 7) * 100, 120,
       IF(s.n <= 25, 'published', 'pending_review'), IF(s.n <= 25, NOW(), NULL)
FROM seq30 s
JOIN users iu ON iu.email = CONCAT('demo.instructor', ((s.n - 1) MOD 5) + 1, '@example.test')
JOIN instructors i ON i.user_id = iu.id
JOIN categories c ON c.slug = CONCAT('demo-category-', LPAD(((s.n - 1) MOD 15) + 1, 2, '0'));

INSERT INTO course_sections (course_id, title, sort_order)
SELECT c.id, CONCAT('Section ', k.n), k.n
FROM courses c JOIN seq2 k WHERE c.slug LIKE 'demo-course-%';

INSERT INTO lessons (section_id, title, type, duration_seconds, sort_order, is_preview)
SELECT sec.id, CONCAT('Lesson ', sec.sort_order, '.', k.n), 'video', 600, k.n,
       IF(sec.sort_order = 1 AND k.n = 1, 1, 0)
FROM course_sections sec
JOIN courses c ON c.id = sec.course_id
JOIN seq3 k
WHERE c.slug LIKE 'demo-course-%';

INSERT INTO quizzes (course_id, title, pass_score_pct)
SELECT c.id, CONCAT('Quiz: ', c.title), 70 FROM courses c
WHERE c.slug LIKE 'demo-course-%' AND c.status = 'published';

INSERT INTO quiz_questions (quiz_id, question, choices, correct_choice, skill_tag, sort_order)
SELECT q.id, CONCAT('Question ', k.n, ' of ', q.title),
       JSON_ARRAY(JSON_OBJECT('id','a','text','Option A'), JSON_OBJECT('id','b','text','Option B'),
                  JSON_OBJECT('id','c','text','Option C')),
       ELT(k.n, 'a', 'b', 'c'), 'General', k.n
FROM quizzes q JOIN courses c ON c.id = q.course_id JOIN seq3 k
WHERE c.slug LIKE 'demo-course-%';

-- ------------------------------------------------ learning and commerce
-- Learner N enrolls in course N (completed) and course N+1 (in progress).
INSERT INTO enrollments (user_id, course_id, progress_pct, status, enrolled_at, completed_at)
SELECT u.id, c.id, IF(k.n = 1, 100, 40), IF(k.n = 1, 'completed', 'in_progress'),
       NOW() - INTERVAL s.n DAY, IF(k.n = 1, NOW(), NULL)
FROM seq30 s
JOIN seq2 k ON s.n <= 25
JOIN users u ON u.email = CONCAT('demo.learner', LPAD(s.n,2,'0'), '@example.test')
JOIN courses c ON c.slug = CONCAT('demo-course-', LPAD(IF(k.n = 1, s.n, (s.n MOD 25) + 1), 2, '0'));

INSERT INTO lesson_progress (enrollment_id, lesson_id, status, watched_seconds, completed_at)
SELECT e.id, fl.lid, 'completed', 600, NOW()
FROM enrollments e
JOIN users u ON u.id = e.user_id AND u.email LIKE 'demo.learner%@example.test'
JOIN (SELECT sec.course_id, MIN(l.id) AS lid
      FROM lessons l JOIN course_sections sec ON sec.id = l.section_id GROUP BY sec.course_id) fl
  ON fl.course_id = e.course_id;

INSERT INTO certificates (enrollment_id, certificate_code)
SELECT e.id, CONCAT('DEMO-CERT-', LPAD(e.id, 6, '0'))
FROM enrollments e JOIN users u ON u.id = e.user_id AND u.email LIKE 'demo.learner%@example.test'
WHERE e.status = 'completed';

INSERT INTO quiz_attempts (quiz_id, user_id, answers, score_pct, passed, skill_breakdown)
SELECT q.id, e.user_id, JSON_OBJECT('1','a','2','b','3','c'), 80, 1, JSON_OBJECT('General', 80)
FROM enrollments e
JOIN users u ON u.id = e.user_id AND u.email LIKE 'demo.learner%@example.test'
JOIN quizzes q ON q.course_id = e.course_id
WHERE e.status = 'completed';

INSERT INTO reviews (course_id, user_id, rating, comment)
SELECT e.course_id, e.user_id, 3 + (e.id MOD 3), 'Demo review: clear lessons and useful examples.'
FROM enrollments e JOIN users u ON u.id = e.user_id AND u.email LIKE 'demo.learner%@example.test'
WHERE e.status = 'completed';

INSERT INTO coupons (code, discount_type, discount_value, max_uses, expires_at)
SELECT CONCAT('DEMO-COUPON-', LPAD(s.n,2,'0')), IF(s.n MOD 2 = 0, 'percent', 'fixed'),
       5 + s.n, 100, NOW() + INTERVAL 365 DAY
FROM seq30 s WHERE s.n <= 20;

-- One paid SANDBOX order per demo enrollment. No real payment provider is involved.
INSERT INTO orders (order_code, user_id, subtotal, discount_total, grand_total, status)
SELECT CONCAT('DEMO-ORD-', LPAD(e.id, 6, '0')), e.user_id, c.price, 0, c.price, 'paid'
FROM enrollments e
JOIN users u ON u.id = e.user_id AND u.email LIKE 'demo.learner%@example.test'
JOIN courses c ON c.id = e.course_id;

INSERT INTO order_items (order_id, course_id, price)
SELECT o.id, e.course_id, c.price
FROM orders o
JOIN enrollments e ON o.order_code = CONCAT('DEMO-ORD-', LPAD(e.id, 6, '0'))
JOIN courses c ON c.id = e.course_id
WHERE o.order_code LIKE 'DEMO-ORD-%';

INSERT INTO payments (order_id, method, provider_ref, amount, status, paid_at)
SELECT o.id, ELT((o.id MOD 3) + 1, 'promptpay', 'card', 'stripe'),
       CONCAT('sandbox_', o.order_code), o.grand_total, 'success', NOW()
FROM orders o WHERE o.order_code LIKE 'DEMO-ORD-%';

INSERT INTO refunds (payment_id, amount, reason, status)
SELECT p.id, p.amount, 'Demo refund request', ELT((p.id MOD 3) + 1, 'requested', 'processed', 'rejected')
FROM payments p JOIN orders o ON o.id = p.order_id
WHERE o.order_code LIKE 'DEMO-ORD-%'
ORDER BY p.id LIMIT 20;

INSERT INTO creator_payouts (instructor_id, period_start, period_end, gross_amount, platform_fee, net_amount, status, paid_at)
SELECT i.id, CURDATE() - INTERVAL (k.n * 30) DAY, CURDATE() - INTERVAL ((k.n - 1) * 30) DAY,
       10000 * k.n, 2000 * k.n, 8000 * k.n, IF(k.n <= 3, 'paid', 'pending'), IF(k.n <= 3, NOW(), NULL)
FROM instructors i
JOIN users u ON u.id = i.user_id AND u.email LIKE 'demo.instructor%@example.test'
JOIN seq30 k ON k.n <= 4;

UPDATE courses c
SET c.student_count = (SELECT COUNT(*) FROM enrollments e WHERE e.course_id = c.id),
    c.rating_count  = (SELECT COUNT(*) FROM reviews r WHERE r.course_id = c.id),
    c.rating_avg    = COALESCE((SELECT AVG(r.rating) FROM reviews r WHERE r.course_id = c.id), 0)
WHERE c.slug LIKE 'demo-course-%';

-- ----------------------------------------------------------- engagement
INSERT INTO notifications (user_id, type, title, body)
SELECT u.id, 'demo_welcome', 'Welcome to AB Learning', 'Demo notification for testing the notification list.'
FROM users u WHERE u.email LIKE 'demo.learner%@example.test';

-- ------------------------------------------------------------ corporate
INSERT INTO organizations (name, employee_count, training_budget)
SELECT 'Demo Corp', 25, 500000 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM organizations WHERE name = 'Demo Corp');

INSERT INTO organization_users (organization_id, user_id, department, role_in_org)
SELECT o.id, u.id, ELT((u.id MOD 4) + 1, 'Engineering', 'Sales', 'Operations', 'HR'),
       CASE WHEN u.email = 'demo.corpadmin@example.test' THEN 'admin'
            WHEN u.email = 'demo.corpmanager@example.test' THEN 'manager' ELSE 'employee' END
FROM organizations o
JOIN users u ON u.email LIKE 'demo.learner%@example.test'
             OR u.email IN ('demo.corpadmin@example.test', 'demo.corpmanager@example.test')
WHERE o.name = 'Demo Corp';

INSERT INTO learning_paths (organization_id, name, goal, deadline)
SELECT o.id, CONCAT('Demo path ', LPAD(s.n,2,'0')), 'Upskill employees on a sample track',
       CURDATE() + INTERVAL (30 + s.n) DAY
FROM seq30 s JOIN organizations o ON o.name = 'Demo Corp' WHERE s.n <= 20;

INSERT INTO learning_path_courses (learning_path_id, course_id)
SELECT lp.id, c.id
FROM seq30 s
JOIN seq2 k ON s.n <= 20
JOIN learning_paths lp ON lp.name = CONCAT('Demo path ', LPAD(s.n,2,'0'))
JOIN courses c ON c.slug = CONCAT('demo-course-', LPAD(IF(k.n = 1, s.n, (s.n MOD 25) + 1), 2, '0'));

-- ------------------------------------------------------------- employer
INSERT INTO jobs (employer_id, title, description, requirements, skill_tags, location, is_remote,
                  salary_min, salary_max, employment_type, status)
SELECT e.id, CONCAT('Demo job ', LPAD(s.n,2,'0')), 'Sample job posting for testing.',
       'Sample requirements.', JSON_ARRAY('Flutter', 'Go', 'MySQL'),
       'Bangkok', s.n MOD 2, 30000 + s.n * 1000, 50000 + s.n * 1000,
       ELT((s.n MOD 4) + 1, 'full_time', 'part_time', 'contract', 'internship'), 'open'
FROM seq30 s
JOIN users eu ON eu.email = CONCAT('demo.employer', ((s.n - 1) MOD 3) + 1, '@example.test')
JOIN employers e ON e.user_id = eu.id
WHERE s.n <= 25;

INSERT INTO job_applications (job_id, user_id, portfolio_id, match_score, status)
SELECT j.id, u.id, p.id, 60 + s.n,
       ELT((s.n MOD 5) + 1, 'submitted', 'reviewed', 'shortlisted', 'rejected', 'hired')
FROM seq30 s
JOIN jobs j ON j.title = CONCAT('Demo job ', LPAD(s.n,2,'0'))
JOIN users u ON u.email = CONCAT('demo.learner', LPAD(s.n,2,'0'), '@example.test')
JOIN portfolios p ON p.user_id = u.id
WHERE s.n <= 25;

-- ---------------------------------------------------------------- admin
INSERT INTO audit_logs (actor_id, action, target_type, target_id, metadata)
SELECT a.id, ELT((s.n MOD 3) + 1, 'course.approve', 'user.suspend', 'payment.refund'),
       'course', c.id, JSON_OBJECT('demo', TRUE, 'n', s.n)
FROM seq30 s
JOIN users a ON a.email = 'demo.admin@example.test'
JOIN courses c ON c.slug = CONCAT('demo-course-', LPAD(s.n,2,'0'))
WHERE s.n <= 25;

COMMIT;
