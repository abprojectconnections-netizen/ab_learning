package courses

import (
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestListTrimsQueryAndReturnsCatalogItems(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	query := courseSelect + " WHERE c.status = 'published' AND (c.title LIKE ? OR c.description LIKE ?) ORDER BY c.student_count DESC, c.id DESC LIMIT ? OFFSET ?"
	mock.ExpectQuery(regexp.QuoteMeta(query)).
		WithArgs("%Go%", "%Go%", 20, 0).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "title", "slug", "description", "thumbnail_url", "price", "discount_price",
			"rating_avg", "student_count", "level", "status", "category", "instructor_id", "instructor_name",
		}).AddRow(1, "Go Backend", "go-backend", "Course description", "", 25.0, nil, 4.8, 120, "beginner", "published", "engineering", 7, "Alex"))

	service := NewService(NewRepository(db))
	items, err := service.List(ListFilter{Query: " Go ", Limit: 20})
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].Title != "Go Backend" || items[0].Instructor.DisplayName != "Alex" {
		t.Fatalf("unexpected catalog response: %#v", items)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestGetReturnsNotFoundForMissingCourse(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	mock.ExpectQuery(regexp.QuoteMeta(courseSelect + " WHERE c.id = ? AND c.status = 'published'")).
		WithArgs(int64(404)).WillReturnRows(sqlmock.NewRows([]string{
		"id", "title", "slug", "description", "thumbnail_url", "price", "discount_price",
		"rating_avg", "student_count", "level", "status", "category", "instructor_id", "instructor_name",
	}))

	service := NewService(NewRepository(db))
	_, err = service.Get(404)
	if err != ErrNotFound {
		t.Fatalf("expected ErrNotFound, got %v", err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestPublicCurriculumOnlyExposesPreviewVideoURLs(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	mock.ExpectQuery("FROM course_sections s").WithArgs(int64(5)).
		WillReturnRows(sqlmock.NewRows([]string{"sid", "stitle", "lid", "ltitle", "ltype", "dur", "url", "preview"}).
			AddRow(int64(1), "Basics", int64(10), "Free intro", "video", 60, "/uploads/videos/free.mp4", true).
			AddRow(int64(1), "Basics", int64(11), "Paid lesson", "video", 120, "/uploads/videos/paid.mp4", false).
			AddRow(int64(2), "Empty", nil, nil, nil, nil, nil, nil))

	sections, err := NewRepository(db).Curriculum(5)
	if err != nil {
		t.Fatal(err)
	}
	if len(sections) != 2 || len(sections[0].Lessons) != 2 || len(sections[1].Lessons) != 0 {
		t.Fatalf("unexpected sections: %#v", sections)
	}
	free, paid := sections[0].Lessons[0], sections[0].Lessons[1]
	if free.VideoURL != "/uploads/videos/free.mp4" || !free.IsPreview {
		t.Errorf("preview lesson must keep its URL: %#v", free)
	}
	if paid.VideoURL != "" || paid.IsPreview {
		t.Errorf("non-preview lesson must not expose its URL: %#v", paid)
	}
}
