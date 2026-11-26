package security

import (
	"encoding/base64"
	"encoding/hex"
	"errors"
	"strings"
	"testing"
	"time"
)

const secret = "unit-test-secret-unit-test-secret"

func TestIssueAndParseRoundTrip(t *testing.T) {
	tok, err := IssueToken(secret, 42, "LEARNER", "access", time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	c, err := ParseToken(secret, tok, "access")
	if err != nil {
		t.Fatalf("ParseToken: %v", err)
	}
	if c.Sub != 42 || c.Role != "LEARNER" || c.Typ != "access" || c.Exp <= c.Iat {
		t.Fatalf("unexpected claims: %+v", c)
	}
}

func TestParseTokenRejectsInvalidTokens(t *testing.T) {
	good, _ := IssueToken(secret, 1, "ADMIN", "access", time.Minute)
	expired, _ := IssueToken(secret, 1, "ADMIN", "access", -time.Second)
	refresh, _ := IssueToken(secret, 1, "ADMIN", "refresh", time.Minute)
	parts := strings.Split(good, ".")

	// Payload swapped for one claiming a different role, signature kept.
	forged := base64.RawURLEncoding.EncodeToString([]byte(`{"sub":1,"role":"SUPER_ADMIN","typ":"access","iat":1,"exp":99999999999}`))
	// "alg":"none" header with an empty signature.
	noneHeader := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"none","typ":"JWT"}`))

	cases := map[string]string{
		"empty":               "",
		"two parts":           parts[0] + "." + parts[1],
		"four parts":          good + ".x",
		"wrong secret":        mustIssue(t, "another-secret-another-secret-12345", "access"),
		"tampered payload":    parts[0] + "." + forged + "." + parts[2],
		"alg none":            noneHeader + "." + parts[1] + ".",
		"truncated signature": good[:len(good)-4],
		"expired":             expired,
		"wrong token type":    refresh,
	}
	for name, tok := range cases {
		if _, err := ParseToken(secret, tok, "access"); !errors.Is(err, ErrInvalidToken) {
			t.Errorf("%s: ParseToken = %v, want ErrInvalidToken", name, err)
		}
	}
}

func mustIssue(t *testing.T, sec, typ string) string {
	t.Helper()
	tok, err := IssueToken(sec, 1, "ADMIN", typ, time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	return tok
}

// Published PBKDF2-HMAC-SHA256 vectors prove the implementation matches the standard.
func TestPBKDF2KnownVectors(t *testing.T) {
	cases := []struct {
		password, salt string
		iter, keyLen   int
		want           string
	}{
		{"password", "salt", 1, 32, "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"},
		{"password", "salt", 2, 32, "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"},
		{"passwd", "salt", 1, 64, "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783"},
	}
	for _, c := range cases {
		got := hex.EncodeToString(pbkdf2SHA256([]byte(c.password), []byte(c.salt), c.iter, c.keyLen))
		if got != c.want {
			t.Errorf("pbkdf2(%q,%q,%d,%d) = %s, want %s", c.password, c.salt, c.iter, c.keyLen, got, c.want)
		}
	}
}

func TestHashAndVerifyPassword(t *testing.T) {
	hash, err := HashPassword("correct horse battery staple")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(hash, "pbkdf2$sha256$210000$") {
		t.Fatalf("unexpected hash format: %q", hash)
	}
	if !VerifyPassword("correct horse battery staple", hash) {
		t.Fatal("correct password must verify")
	}
	if VerifyPassword("wrong password", hash) {
		t.Fatal("wrong password must not verify")
	}
	again, _ := HashPassword("correct horse battery staple")
	if again == hash {
		t.Fatal("hashes of the same password must differ (random salt)")
	}
}

func TestVerifyPasswordRejectsMalformedHashes(t *testing.T) {
	for _, h := range []string{
		"", "plain-text", "pbkdf2$sha256$1$AAAA", "pbkdf2$sha1$1$AAAA$AAAA",
		"bcrypt$sha256$1$AAAA$AAAA", "pbkdf2$sha256$zero$AAAA$AAAA",
		"pbkdf2$sha256$0$AAAA$AAAA", "pbkdf2$sha256$1$!!!$AAAA", "pbkdf2$sha256$1$AAAA$!!!",
	} {
		if VerifyPassword("x", h) {
			t.Errorf("VerifyPassword accepted malformed hash %q", h)
		}
	}
}

func TestRandomTokenIsUniqueAndSized(t *testing.T) {
	a, err := RandomToken(32)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := RandomToken(32)
	if a == b || len(a) != 43 { // 32 bytes -> 43 chars of unpadded base64url
		t.Fatalf("RandomToken: %q / %q", a, b)
	}
}
