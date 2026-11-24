// Command seed loads demo/test data (db/seed/demo_data.sql) into a LOCAL or
// TEST database. It never runs against staging or production and refuses
// database hosts that are not local unless ALLOW_REMOTE_SEED=yes is set.
//
//	APP_ENV=dev DB_DSN=... go run ./cmd/seed
package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"

	"github.com/ablearning/api/internal/config"
	"github.com/ablearning/api/internal/database"
	"github.com/ablearning/api/internal/security"
)

const marker = "demo.learner01@example.test"

func main() {
	cfg := config.Load()
	if err := guard(cfg); err != nil {
		log.Fatalf("seed refused: %v", err)
	}

	if err := database.Migrate(cfg.DBDSN, cfg.MigrationsDir); err != nil {
		log.Fatalf("migrate: %v", err)
	}

	file := os.Getenv("DEMO_SEED_FILE")
	if file == "" {
		file = "db/seed/demo_data.sql"
	}
	body, err := os.ReadFile(file)
	if err != nil {
		log.Fatalf("read %s: %v", file, err)
	}

	hash, err := security.HashPassword(database.DevPassword)
	if err != nil {
		log.Fatalf("hash password: %v", err)
	}
	script := strings.ReplaceAll(string(body), "{{PASSWORD_HASH}}", sqlEscape(hash))

	dsn, err := mysql.ParseDSN(cfg.DBDSN)
	if err != nil {
		log.Fatalf("parse DB_DSN: %v", err)
	}
	dsn.MultiStatements = true
	dsn.ParseTime = true
	connector, err := mysql.NewConnector(dsn)
	if err != nil {
		log.Fatalf("connector: %v", err)
	}
	db := sql.OpenDB(connector)
	defer db.Close()
	// Temp tables and @pw live on one connection.
	db.SetMaxOpenConns(1)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	var n int
	if err := db.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE email = ?`, marker).Scan(&n); err != nil {
		log.Fatalf("check existing demo data: %v", err)
	}
	if n > 0 {
		fmt.Println("demo data already present; nothing to do")
		return
	}

	if _, err := db.ExecContext(ctx, script); err != nil {
		// An open transaction on the connection is discarded when it closes.
		log.Fatalf("seed failed (nothing was committed): %v", err)
	}
	fmt.Println("demo data loaded")
}

func guard(cfg config.Config) error {
	if cfg.Env == "staging" || cfg.Env == "production" {
		return fmt.Errorf("APP_ENV=%s", cfg.Env)
	}
	dsn, err := mysql.ParseDSN(cfg.DBDSN)
	if err != nil {
		return fmt.Errorf("parse DB_DSN: %w", err)
	}
	host := dsn.Addr
	local := strings.HasPrefix(host, "127.0.0.1") || strings.HasPrefix(host, "localhost") ||
		strings.HasPrefix(host, "[::1]") || strings.HasPrefix(host, "mysql:")
	if !local && os.Getenv("ALLOW_REMOTE_SEED") != "yes" {
		return fmt.Errorf("database host %q is not local (set ALLOW_REMOTE_SEED=yes only for a disposable test database)", host)
	}
	return nil
}

func sqlEscape(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	return strings.ReplaceAll(s, `'`, `\'`)
}
