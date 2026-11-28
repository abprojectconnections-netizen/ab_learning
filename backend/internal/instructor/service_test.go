package instructor

import (
	"errors"
	"regexp"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
)

func fptr(f float64) *float64 { return &f }

func TestSlugify(t *testing.T) {
	re := regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*-[0-9a-f]{6}$`)
	for in, prefix := range map[string]string{
		"Intro to Go!":       "intro-to-go-",
		"  --Hello   World ": "hello-world-",
		"สวัสดี":             "course-", // no ASCII characters -> fallback
		"":                   "course-",
	} {
		got := slugify(in)
		if !strings.HasPrefix(got, prefix) || !re.MatchString(got) {
			t.Errorf("slugify(%q) = %q, want prefix %q and slug format", in, got, prefix)
		}
	}
	if long := slugify(strings.Repeat("a", 200)); len(long) > 60+1+6 {
		t.Errorf("slug too long: %d", len(long))
	}
	if slugify("same") == slugify("same") {
		t.Error("slugs must carry a random suffix")
	}
}

func TestValidateCourse(t *testing.T) {
	ok := CourseInput{Title: " Valid title ", CategoryID: 1}
	if err := validateCourse(&ok); err != nil || ok.Title != "Valid title" || ok.Level != "beginner" || ok.Language != "th" {
		t.Fatalf("defaults not applied: %v %+v", err, ok)
	}
	bad := map[string]CourseInput{
		"short title":       {Title: "ab", CategoryID: 1},
		"long title":        {Title: strings.Repeat("x", 201), CategoryID: 1},
		"no category":       {Title: "Valid title"},
		"bad level":         {Title: "Valid title", CategoryID: 1, Level: "expert"},
		"negative price":    {Title: "Valid title", CategoryID: 1, Price: -1},
		"huge price":        {Title: "Valid title", CategoryID: 1, Price: 1_000_001},
		"discount > price":  {Title: "Valid title", CategoryID: 1, Price: 100, DiscountPrice: fptr(150)},
		"negative discount": {Title: "Valid title", CategoryID: 1, Price: 100, DiscountPrice: fptr(-1)},
		"javascript thumb":  {Title: "Valid title", CategoryID: 1, ThumbnailURL: "javascript:alert(1)"},
	}
	for name, in := range bad {
		in := in
		if err := validateCourse(&in); !errors.Is(err, ErrValidation) {
			t.Errorf("%s: got %v, want ErrValidation", name, err)
		}
	}
	free := CourseInput{Title: "Free course", CategoryID: 1, Price: 100, DiscountPrice: fptr(100)}
	if err := validateCourse(&free); err != nil {
		t.Errorf("discount equal to price is allowed: %v", err)
	}
}

func TestValidateMediaURL(t *testing.T) {
	for _, u := range []string{"", "/uploads/images/a.png", "https://cdn.example.test/a.mp4", "http://localhost/a.png"} {
		if err := validateMediaURL(u); err != nil {
			t.Errorf("%q should be allowed: %v", u, err)
		}
	}
	for _, u := range []string{"javascript:alert(1)", "data:text/html,x", "file:///etc/passwd", "//evil.test/x", "ftp://x/y", "../uploads/x"} {
		if err := validateMediaURL(u); !errors.Is(err, ErrValidation) {
			t.Errorf("%q should be rejected, got %v", u, err)
		}
	}
}

func TestValidateLesson(t *testing.T) {
	l := LessonInput{Title: "  Intro "}
	if err := validateLesson(&l); err != nil || l.Type != "video" || l.Title != "Intro" {
		t.Fatalf("defaults: %v %+v", err, l)
	}
	for name, in := range map[string]LessonInput{
		"no title":      {},
		"long title":    {Title: strings.Repeat("x", 201)},
		"bad type":      {Title: "T", Type: "podcast"},
		"negative dur":  {Title: "T", DurationSeconds: -1},
		"dur > 24h":     {Title: "T", DurationSeconds: 24*3600 + 1},
		"bad video url": {Title: "T", VideoURL: "javascript:1"},
	} {
		in := in
		if err := validateLesson(&in); !errors.Is(err, ErrValidation) {
			t.Errorf("%s: got %v, want ErrValidation", name, err)
		}
	}
}

func TestEditable(t *testing.T) {
	for st, want := range map[string]bool{"draft": true, "rejected": true, "pending_review": false, "published": false, "": false} {
		if editable(st) != want {
			t.Errorf("editable(%q) = %v", st, !want)
		}
	}
}

func TestOwnedEditable(t *testing.T) {
	s := &Service{}
	if err := s.ownedEditable(1, CourseMeta{InstructorID: 1, Status: "draft"}, nil); err != nil {
		t.Errorf("owner of a draft: %v", err)
	}
	if err := s.ownedEditable(1, CourseMeta{InstructorID: 2, Status: "draft"}, nil); !errors.Is(err, ErrForbidden) {
		t.Errorf("another instructor's course: %v, want ErrForbidden", err)
	}
	if err := s.ownedEditable(1, CourseMeta{InstructorID: 1, Status: "published"}, nil); !errors.Is(err, ErrLocked) {
		t.Errorf("published course: %v, want ErrLocked", err)
	}
	if err := s.ownedEditable(1, CourseMeta{}, ErrNotFound); !errors.Is(err, ErrNotFound) {
		t.Errorf("lookup error must pass through: %v", err)
	}
}

func svcWithMock(t *testing.T) (*Service, sqlmock.Sqlmock) {
	t.Helper()
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return NewService(NewRepository(db)), mock
}

func expectInstructor(mock sqlmock.Sqlmock, userID, instrID int64) {
	mock.ExpectQuery("SELECT id FROM instructors").WithArgs(userID).
		WillReturnRows(sqlmock.NewRows([]string{"id"}).AddRow(instrID))
}

func expectMeta(mock sqlmock.Sqlmock, courseID, owner int64, status string) {
	mock.ExpectQuery("SELECT id, instructor_id, status FROM courses").WithArgs(courseID).
		WillReturnRows(sqlmock.NewRows([]string{"id", "instructor_id", "status"}).AddRow(courseID, owner, status))
}

func TestDeleteCourseRules(t *testing.T) {
	cases := []struct {
		name   string
		owner  int64
		status string
		want   error
	}{
		{"someone else's course", 99, "draft", ErrForbidden},
		{"published course", 7, "published", ErrLocked},
		{"pending course", 7, "pending_review", ErrLocked},
	}
	for _, c := range cases {
		s, mock := svcWithMock(t)
		expectInstructor(mock, 1, 7)
		expectMeta(mock, 10, c.owner, c.status)
		if err := s.DeleteCourse(1, 10); !errors.Is(err, c.want) {
			t.Errorf("%s: got %v, want %v", c.name, err, c.want)
		}
	}
}

func TestDeleteCourseUnknownCourse(t *testing.T) {
	s, mock := svcWithMock(t)
	expectInstructor(mock, 1, 7)
	mock.ExpectQuery("SELECT id, instructor_id, status FROM courses").WithArgs(int64(10)).
		WillReturnRows(sqlmock.NewRows([]string{"id", "instructor_id", "status"}))
	if err := s.DeleteCourse(1, 10); !errors.Is(err, ErrNotFound) {
		t.Fatalf("got %v, want ErrNotFound", err)
	}
}

func TestUpdateCourseInvalidInputSkipsDatabase(t *testing.T) {
	s, _ := svcWithMock(t) // no expectations: any query would fail the test
	if _, err := s.UpdateCourse(1, 10, CourseInput{Title: "x"}); !errors.Is(err, ErrValidation) {
		t.Fatalf("got %v, want ErrValidation", err)
	}
}

func TestUnapprovedInstructorCannotCreateCourse(t *testing.T) {
	s, mock := svcWithMock(t)
	mock.ExpectQuery("SELECT id FROM instructors").WithArgs(int64(1)).WillReturnRows(sqlmock.NewRows([]string{"id"}))
	if _, err := s.CreateCourse(1, CourseInput{Title: "Valid title", CategoryID: 1}); !errors.Is(err, ErrInstructorPending) {
		t.Fatalf("got %v, want ErrInstructorPending", err)
	}
}

func TestSectionAndLessonTitleValidation(t *testing.T) {
	s := &Service{}
	if _, err := s.CreateSection(1, SectionInput{CourseID: 1, Title: "  "}); !errors.Is(err, ErrValidation) {
		t.Errorf("CreateSection: %v", err)
	}
	if err := s.UpdateSection(1, 1, SectionInput{Title: strings.Repeat("x", 201)}); !errors.Is(err, ErrValidation) {
		t.Errorf("UpdateSection: %v", err)
	}
	if _, err := s.CreateLesson(1, LessonInput{SectionID: 1}); !errors.Is(err, ErrValidation) {
		t.Errorf("CreateLesson: %v", err)
	}
	if err := s.UpdateLesson(1, 1, LessonInput{Title: "T", Type: "x"}); !errors.Is(err, ErrValidation) {
		t.Errorf("UpdateLesson: %v", err)
	}
}
