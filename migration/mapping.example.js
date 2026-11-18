// Copy to mapping.js and edit the SQL so each query returns the aliased columns
// listed in its comment. Table and column names below are ONLY EXAMPLES.
module.exports = {
  // id, email, display_name, role, created_at
  users: `SELECT id, email, display_name, role, created_at FROM users`,
  // id, title, description, category, price, status, instructor_id, instructor_name
  courses: `SELECT id, title, description, category, price, status, instructor_id, instructor_name FROM courses`,
  // user_id, course_id, enrolled_at
  enrollments: `SELECT user_id, course_id, enrolled_at FROM enrollments`,

  // Map your old role / status values to the app's values.
  roleMap: { student: 'learner', teacher: 'instructor', admin: 'admin' },
  courseStatusMap: { active: 'published', published: 'published', draft: 'draft', pending: 'pending_review' },
};
