package platform

import "testing"

func TestParseID(t *testing.T) {
	if id, err := ParseID(" 12 ", "course"); err != nil || id != 12 {
		t.Fatalf("ParseID valid = %d, %v", id, err)
	}
	for _, raw := range []string{"", "  ", "0", "-1", "x", "1.5"} {
		if _, err := ParseID(raw, "course"); err == nil {
			t.Errorf("ParseID(%q) must fail", raw)
		}
	}
	_, err := ParseID("", "course")
	if ae, ok := err.(*AppError); !ok || ae.Status != 400 || ae.Message != "course id is required" {
		t.Fatalf("error must be a 400 AppError naming the resource, got %#v", err)
	}
}
