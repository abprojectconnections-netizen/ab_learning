package instructor

import (
	"bytes"
	"errors"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Smallest valid PNG signature plus padding; DetectContentType only needs the header.
var pngBytes = append([]byte("\x89PNG\r\n\x1a\n"), make([]byte, 64)...)

func multipartReq(t *testing.T, field, filename string, content []byte) *http.Request {
	t.Helper()
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	fw, err := w.CreateFormFile(field, filename)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = fw.Write(content)
	_ = w.Close()
	req := httptest.NewRequest(http.MethodPost, "/upload", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	return req
}

func TestUploadAcceptsImageAndStoresUnderRandomName(t *testing.T) {
	dir := t.TempDir()
	u := Uploader{Dir: dir, MaxImage: 1 << 20, MaxVideo: 1 << 20}
	res, status, err := u.Save(httptest.NewRecorder(), multipartReq(t, "file", "../../evil name.png", pngBytes), "image")
	if err != nil || status != http.StatusCreated {
		t.Fatalf("Save = %d, %v", status, err)
	}
	if !strings.HasPrefix(res.URL, "/uploads/images/") || !strings.HasSuffix(res.URL, ".png") || res.ContentType != "image/png" {
		t.Fatalf("unexpected result: %+v", res)
	}
	if res.OriginalName != "evil name.png" {
		t.Fatalf("original name must be reduced to its base name, got %q", res.OriginalName)
	}
	if _, err := os.Stat(filepath.Join(dir, "images", filepath.Base(res.URL))); err != nil {
		t.Fatalf("file not stored: %v", err)
	}
}

func TestUploadRejectsDisguisedAndOversizedFiles(t *testing.T) {
	u := Uploader{Dir: t.TempDir(), MaxImage: 100, MaxVideo: 100}

	// HTML named .png must be rejected by content sniffing, not by extension.
	_, status, err := u.Save(httptest.NewRecorder(), multipartReq(t, "file", "a.png", []byte("<html><script>alert(1)</script></html>")), "image")
	if status != http.StatusUnsupportedMediaType || !errors.Is(err, errBadType) {
		t.Errorf("html as png: %d %v", status, err)
	}
	// An image is not a valid video.
	_, status, _ = u.Save(httptest.NewRecorder(), multipartReq(t, "file", "a.mp4", pngBytes), "video")
	if status != http.StatusUnsupportedMediaType {
		t.Errorf("png as video: %d", status)
	}
	// Over the size limit; the partial file must not be left behind.
	big := append([]byte("\x89PNG\r\n\x1a\n"), make([]byte, 500)...)
	_, status, _ = u.Save(httptest.NewRecorder(), multipartReq(t, "file", "a.png", big), "image")
	if status != http.StatusRequestEntityTooLarge {
		t.Errorf("oversized: %d", status)
	}
	entries, _ := os.ReadDir(filepath.Join(u.Dir, "images"))
	if len(entries) != 0 {
		t.Errorf("oversized upload left %d file(s) on disk", len(entries))
	}
}

func TestUploadRequiresMultipartFileField(t *testing.T) {
	u := Uploader{Dir: t.TempDir(), MaxImage: 1 << 20}
	req := httptest.NewRequest(http.MethodPost, "/upload", strings.NewReader("{}"))
	req.Header.Set("Content-Type", "application/json")
	if _, status, _ := u.Save(httptest.NewRecorder(), req, "image"); status != http.StatusBadRequest {
		t.Errorf("non-multipart: %d", status)
	}
	if _, status, _ := u.Save(httptest.NewRecorder(), multipartReq(t, "other", "a.png", pngBytes), "image"); status != http.StatusBadRequest {
		t.Errorf("wrong field name: %d", status)
	}
}

func TestNoListFSHidesDirectories(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	fs := NoListFS{FS: http.Dir(dir)}
	if f, err := fs.Open("/a.txt"); err != nil {
		t.Fatalf("file must open: %v", err)
	} else {
		f.Close()
	}
	if _, err := fs.Open("/"); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("directory must look missing, got %v", err)
	}
}
