-- 003: RBAC permissions, central menu, refresh-token store, payment webhook
-- events, idempotency keys and system settings.
--
-- Additive only: no existing table is altered or dropped and no existing row is
-- modified. Reference rows use INSERT IGNORE so re-running or a partially
-- applied environment never overwrites administrator-managed data.

-- ---------------------------------------------------------------- roles
INSERT IGNORE INTO roles (code, name_th, name_en) VALUES
  ('SUPER_ADMIN', 'ผู้ดูแลระบบสูงสุด', 'Super Admin');

-- ---------------------------------------------------------- permissions
CREATE TABLE IF NOT EXISTS permissions (
  id            INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  code          VARCHAR(60) NOT NULL UNIQUE,   -- resource.action
  description   VARCHAR(200) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id       TINYINT UNSIGNED NOT NULL,
  permission_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO permissions (code, description) VALUES
  ('course.create',        'Create and edit own courses'),
  ('course.submit',        'Submit a course for approval'),
  ('course.approve',       'Approve or reject submitted courses'),
  ('instructor.approve',   'Approve instructor applications'),
  ('user.read',            'View users'),
  ('user.manage',          'Edit or suspend users'),
  ('payment.read',         'View payments and orders'),
  ('payment.refund',       'Process refunds'),
  ('payout.read',          'View instructor revenue and payouts'),
  ('org.manage',           'Manage organization employees and learning paths'),
  ('job.manage',           'Manage job postings and applications'),
  ('review.moderate',      'Moderate course reviews'),
  ('audit.read',           'View the audit log'),
  ('settings.manage',      'Change system settings'),
  ('role.manage',          'Change role permissions');

-- Instructors
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
WHERE r.code = 'INSTRUCTOR'
  AND p.code IN ('course.create', 'course.submit', 'payout.read');

-- Corporate roles
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
WHERE r.code IN ('CORP_ADMIN', 'CORP_MANAGER') AND p.code = 'org.manage';

-- Employers
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
WHERE r.code = 'EMPLOYER' AND p.code = 'job.manage';

-- Admin: operations, but not settings or role management
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
WHERE r.code = 'ADMIN'
  AND p.code IN ('course.approve', 'instructor.approve', 'user.read', 'user.manage',
                 'payment.read', 'payment.refund', 'review.moderate', 'audit.read');

-- Super admin: everything
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p WHERE r.code = 'SUPER_ADMIN';

-- --------------------------------------------------------- central menu
-- is_active = 0 means the destination screen/API is not built yet. Clients
-- must show only active items, so no menu entry ever leads to an empty page.
CREATE TABLE IF NOT EXISTS menu_items (
  id            INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  code          VARCHAR(60) NOT NULL UNIQUE,
  group_code    VARCHAR(40) NOT NULL,
  label_th      VARCHAR(120) NOT NULL,
  label_en      VARCHAR(120) NOT NULL,
  route         VARCHAR(200) NOT NULL,
  icon          VARCHAR(40),
  sort_order    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active     TINYINT(1) NOT NULL DEFAULT 0,
  INDEX idx_menu_group (group_code, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS menu_item_roles (
  menu_item_id  INT UNSIGNED NOT NULL,
  role_id       TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (menu_item_id, role_id),
  FOREIGN KEY (menu_item_id) REFERENCES menu_items(id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO menu_items (code, group_code, label_th, label_en, route, icon, sort_order, is_active) VALUES
  -- public
  ('home',                'public',     'หน้าแรก',            'Home',                  '/',                              'home',        10, 1),
  ('explore',             'public',     'สำรวจคอร์ส',         'Explore',               '/explore',                       'compass',     20, 1),
  ('search',              'public',     'ค้นหา',              'Search',                '/search',                        'search',      30, 1),
  ('certificate_verify',  'public',     'ตรวจสอบใบรับรอง',    'Verify certificate',    '/verify',                        'shield',      40, 1),
  ('jobs',                'public',     'ตำแหน่งงาน',         'Jobs',                  '/jobs',                          'briefcase',   50, 1),
  -- learner
  ('my_courses',          'learner',    'คอร์สของฉัน',        'My courses',            '/my-learning/courses',           'book',        10, 1),
  ('my_progress',         'learner',    'ความคืบหน้า',        'Progress',              '/my-learning/progress',          'chart',       20, 1),
  ('my_certificates',     'learner',    'ใบรับรองของฉัน',     'My certificates',       '/my-learning/certificates',      'award',       30, 1),
  ('my_learning_paths',   'learner',    'เส้นทางการเรียน',    'Learning paths',        '/my-learning/paths',             'route',       40, 1),
  ('my_orders',           'learner',    'คำสั่งซื้อ',          'Orders',                '/orders',                        'receipt',     50, 0),
  ('my_reviews',          'learner',    'รีวิวของฉัน',        'My reviews',            '/my-learning/reviews',           'star',        60, 0),
  ('notifications',       'learner',    'การแจ้งเตือน',       'Notifications',         '/notifications',                 'bell',        70, 0),
  ('profile',             'learner',    'โปรไฟล์',            'Profile',               '/profile',                       'user',        80, 1),
  -- instructor
  ('instructor_dashboard','instructor', 'แดชบอร์ดผู้สอน',     'Instructor dashboard',  '/instructor',                    'layout',      10, 1),
  ('course_create',       'instructor', 'สร้างคอร์ส',         'Create course',         '/instructor/courses/new',        'plus',        20, 1),
  ('instructor_sales',    'instructor', 'ยอดขาย',             'Sales',                 '/instructor/sales',              'trending',    30, 1),
  ('instructor_revenue',  'instructor', 'รายได้',              'Revenue',               '/instructor/revenue',            'wallet',      40, 1),
  ('instructor_payouts',  'instructor', 'ประวัติการจ่ายเงิน',  'Payout history',        '/instructor/revenue/history',    'history',     50, 1),
  -- corporate
  ('corporate_dashboard', 'corporate',  'แดชบอร์ดองค์กร',     'Corporate dashboard',   '/corporate',                     'building',    10, 1),
  ('corporate_employees', 'corporate',  'พนักงาน',            'Employees',             '/corporate/employees',           'users',       20, 0),
  ('corporate_paths',     'corporate',  'เส้นทางการเรียนองค์กร','Corporate learning paths','/corporate/learning-paths',   'route',       30, 0),
  -- employer
  ('employer_dashboard',  'employer',   'แดชบอร์ดนายจ้าง',    'Employer dashboard',    '/employer',                      'layout',      10, 1),
  ('employer_jobs',       'employer',   'ประกาศงาน',          'Job postings',          '/employer/jobs',                 'briefcase',   20, 0),
  ('employer_applicants', 'employer',   'ผู้สมัครงาน',         'Applicants',            '/employer/applications',         'users',       30, 0),
  -- admin
  ('admin_dashboard',     'admin',      'แดชบอร์ดผู้ดูแล',    'Admin dashboard',       '/admin',                         'layout',      10, 1),
  ('admin_users',         'admin',      'จัดการผู้ใช้',        'Users',                 '/admin/users',                   'users',       20, 0),
  ('admin_approvals',     'admin',      'อนุมัติคอร์ส/ผู้สอน', 'Approvals',             '/admin/approvals',               'check',       30, 0),
  ('admin_payments',      'admin',      'การชำระเงิน',         'Payments',              '/admin/payments',                'credit-card', 40, 0),
  ('admin_audit',         'admin',      'บันทึกการใช้งาน',     'Audit log',             '/admin/audit',                   'list',        50, 0),
  ('admin_settings',      'admin',      'ตั้งค่าระบบ',         'System settings',       '/admin/settings',                'settings',    60, 0),
  ('admin_roles',         'admin',      'บทบาทและสิทธิ์',      'Roles & permissions',   '/admin/roles',                   'lock',        70, 0),
  ('super_admin',         'admin',      'ผู้ดูแลระบบสูงสุด',   'Super admin',           '/super-admin',                   'shield',      80, 1);

-- Visibility by role. Public items: every role.
INSERT IGNORE INTO menu_item_roles (menu_item_id, role_id)
SELECT m.id, r.id FROM menu_items m JOIN roles r
WHERE m.group_code = 'public';

INSERT IGNORE INTO menu_item_roles (menu_item_id, role_id)
SELECT m.id, r.id FROM menu_items m JOIN roles r
WHERE m.group_code = 'learner'
  AND r.code IN ('LEARNER', 'INSTRUCTOR', 'CORP_ADMIN', 'CORP_MANAGER', 'EMPLOYER', 'ADMIN', 'SUPER_ADMIN');

INSERT IGNORE INTO menu_item_roles (menu_item_id, role_id)
SELECT m.id, r.id FROM menu_items m JOIN roles r
WHERE m.group_code = 'instructor' AND r.code IN ('INSTRUCTOR', 'SUPER_ADMIN');

INSERT IGNORE INTO menu_item_roles (menu_item_id, role_id)
SELECT m.id, r.id FROM menu_items m JOIN roles r
WHERE m.group_code = 'corporate' AND r.code IN ('CORP_ADMIN', 'CORP_MANAGER', 'SUPER_ADMIN');

INSERT IGNORE INTO menu_item_roles (menu_item_id, role_id)
SELECT m.id, r.id FROM menu_items m JOIN roles r
WHERE m.group_code = 'employer' AND r.code IN ('EMPLOYER', 'SUPER_ADMIN');

INSERT IGNORE INTO menu_item_roles (menu_item_id, role_id)
SELECT m.id, r.id FROM menu_items m JOIN roles r
WHERE m.group_code = 'admin' AND r.code IN ('ADMIN', 'SUPER_ADMIN');

-- ------------------------------------------------------- refresh tokens
-- Server-side store enabling rotation, reuse detection and logout. Only a
-- SHA-256 hash of the token is stored.
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id            BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NOT NULL,
  token_hash    CHAR(64) NOT NULL UNIQUE,
  family_id     CHAR(36) NOT NULL,             -- all rotations of one login share a family
  expires_at    DATETIME NOT NULL,
  revoked_at    DATETIME NULL,
  replaced_by   BIGINT UNSIGNED NULL,
  user_agent    VARCHAR(255),
  ip_address    VARCHAR(45),
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_refresh_user (user_id),
  INDEX idx_refresh_family (family_id),
  INDEX idx_refresh_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------ payment webhook events
CREATE TABLE IF NOT EXISTS payment_events (
  id            BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  provider      VARCHAR(30) NOT NULL,          -- e.g. stripe (sandbox/test mode only until approved)
  event_id      VARCHAR(150) NOT NULL,         -- provider event id: duplicate deliveries are ignored
  event_type    VARCHAR(100) NOT NULL,
  livemode      TINYINT(1) NOT NULL DEFAULT 0,
  signature_valid TINYINT(1) NOT NULL,
  payload       JSON NOT NULL,
  payment_id    BIGINT UNSIGNED NULL,
  processed_at  DATETIME NULL,
  error         VARCHAR(500) NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_payment_event (provider, event_id),
  FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL,
  INDEX idx_payment_events_type (event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------ idempotency keys
CREATE TABLE IF NOT EXISTS idempotency_keys (
  id            BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NOT NULL,
  endpoint      VARCHAR(150) NOT NULL,
  key_hash      CHAR(64) NOT NULL,
  request_hash  CHAR(64) NOT NULL,             -- same key + different body is rejected
  response_status SMALLINT UNSIGNED NULL,
  response_body JSON NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at    DATETIME NOT NULL,
  UNIQUE KEY uq_idempotency (user_id, endpoint, key_hash),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_idempotency_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------ system settings
CREATE TABLE IF NOT EXISTS app_settings (
  setting_key   VARCHAR(100) PRIMARY KEY,
  setting_value JSON NOT NULL,
  description   VARCHAR(300),
  updated_by    BIGINT UNSIGNED NULL,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO app_settings (setting_key, setting_value, description) VALUES
  ('platform.fee_percent',      '20',            'Platform commission on instructor sales (percent)'),
  ('payments.mode',             '"sandbox"',     'sandbox or live; live requires explicit authorization'),
  ('payments.currency',         '"THB"',         'ISO currency code for orders'),
  ('auth.access_token_minutes', '15',            'Access token lifetime'),
  ('auth.refresh_token_days',   '30',            'Refresh token lifetime'),
  ('uploads.max_video_mb',      '500',           'Maximum lesson video size'),
  ('uploads.max_image_mb',      '5',             'Maximum image size');
