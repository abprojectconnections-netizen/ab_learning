package config

import "testing"

func TestValidateRequiresProductionSecretsAndOrigins(t *testing.T) {
	valid := Config{
		Env:                  "production",
		DBDSN:                "app:secret@tcp(db:3306)/ablearning?parseTime=true",
		JWTSecret:            "01234567890123456789012345678901",
		CORSAllowOrigin:      "https://app.example.com",
		MaxVideoMB:           500,
		RateLimitRequests:    120,
		RateLimitWindowSec:   60,
		PaymentMode:          "sandbox",
		PaymentWebhookSecret: "01234567890123456789012345678901",
	}
	if err := valid.Validate(); err != nil {
		t.Fatalf("valid production config rejected: %v", err)
	}

	tests := []struct {
		name   string
		update func(*Config)
	}{
		{"short JWT secret", func(c *Config) { c.JWTSecret = "short" }},
		{"missing database DSN", func(c *Config) { c.DBDSN = "" }},
		{"seed data enabled", func(c *Config) { c.SeedDev = true }},
		{"wildcard CORS", func(c *Config) { c.CORSAllowOrigin = "*" }},
		{"missing CORS origin", func(c *Config) { c.CORSAllowOrigin = "" }},
		{"live payment mode", func(c *Config) { c.PaymentMode = "live" }},
		{"short payment webhook secret", func(c *Config) { c.PaymentWebhookSecret = "short" }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			config := valid
			test.update(&config)
			if err := config.Validate(); err == nil {
				t.Fatal("expected invalid production config to be rejected")
			}
		})
	}
}

func TestValidateRejectsLivePaymentsInEveryEnvironment(t *testing.T) {
	for _, env := range []string{"dev", "test", "staging", "production"} {
		c := Config{Env: env, MaxVideoMB: 1, RateLimitRequests: 1, RateLimitWindowSec: 1, PaymentMode: "live"}
		if err := c.Validate(); err == nil {
			t.Errorf("%s: PAYMENT_MODE=live must be rejected", env)
		}
	}
}
