package database

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
)

var createTablePattern = regexp.MustCompile(
	"(?im)^\\s*CREATE\\s+TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?[`\"]?([A-Za-z0-9_]+)",
)

func Open(dsn string) (*sql.DB, error) {
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse DB_DSN: %w", err)
	}

	cfg.ParseTime = true
	cfg.Loc = time.UTC

	connector, err := mysql.NewConnector(cfg)
	if err != nil {
		return nil, err
	}

	db := sql.OpenDB(connector)
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	var lastErr error
	for i := 0; i < 15; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		lastErr = db.PingContext(ctx)
		cancel()

		if lastErr == nil {
			return db, nil
		}
		time.Sleep(time.Second)
	}

	db.Close()
	return nil, fmt.Errorf("database unreachable: %w", lastErr)
}

// Migrate applies SQL migrations in lexical order.
// Existing databases can baseline 001_init.sql only when their table names
// exactly match the CREATE TABLE list in that migration.
func Migrate(dsn, dir string) error {
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		return fmt.Errorf("parse migration DB_DSN: %w", err)
	}

	cfg.MultiStatements = true
	cfg.ParseTime = true
	cfg.Loc = time.UTC

	connector, err := mysql.NewConnector(cfg)
	if err != nil {
		return fmt.Errorf("create migration connector: %w", err)
	}

	db := sql.OpenDB(connector)
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		return fmt.Errorf("migration database ping: %w", err)
	}

	if _, err := db.ExecContext(ctx, `
        CREATE TABLE IF NOT EXISTS schema_migrations (
            name VARCHAR(190) PRIMARY KEY,
            applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	files, err := filepath.Glob(filepath.Join(dir, "*.sql"))
	if err != nil {
		return fmt.Errorf("read migration directory %q: %w", dir, err)
	}

	if len(files) == 0 {
		return fmt.Errorf(
			"no SQL migration files found in %q; refusing to start without migrations",
			dir,
		)
	}

	sort.Strings(files)

	for _, file := range files {
		name := filepath.Base(file)

		var exists int
		if err := db.QueryRowContext(
			ctx,
			`SELECT COUNT(*) FROM schema_migrations WHERE name = ?`,
			name,
		).Scan(&exists); err != nil {
			return fmt.Errorf("check migration %s: %w", name, err)
		}

		if exists > 0 {
			log.Printf("migration already applied: %s", name)
			continue
		}

		body, err := os.ReadFile(file)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", name, err)
		}

		// Never execute the initial CREATE TABLE migration against an
		// existing schema. Baseline only when all table names match exactly.
		if name == "001_init.sql" {
			baselined, err := baselineExistingSchema(ctx, db, name, string(body))
			if err != nil {
				return err
			}
			if baselined {
				continue
			}
		}

		log.Printf("applying migration %s", name)

		if _, err := db.ExecContext(ctx, string(body)); err != nil {
			return fmt.Errorf("migration %s failed: %w", name, err)
		}

		if _, err := db.ExecContext(
			ctx,
			`INSERT INTO schema_migrations (name) VALUES (?)`,
			name,
		); err != nil {
			return fmt.Errorf("record migration %s: %w", name, err)
		}

		log.Printf("migration applied: %s", name)
	}

	return nil
}

func baselineExistingSchema(
	ctx context.Context,
	db *sql.DB,
	migrationName string,
	migrationSQL string,
) (bool, error) {
	matches := createTablePattern.FindAllStringSubmatch(migrationSQL, -1)

	expected := make(map[string]struct{}, len(matches))
	for _, match := range matches {
		expected[strings.ToLower(match[1])] = struct{}{}
	}

	if len(expected) == 0 {
		return false, fmt.Errorf(
			"%s contains no CREATE TABLE statements; refusing automatic baseline",
			migrationName,
		)
	}

	rows, err := db.QueryContext(ctx, `
        SELECT TABLE_NAME
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_TYPE = 'BASE TABLE'
          AND TABLE_NAME <> 'schema_migrations'
    `)
	if err != nil {
		return false, fmt.Errorf("inspect existing database tables: %w", err)
	}
	defer rows.Close()

	actual := make(map[string]struct{})
	for rows.Next() {
		var table string
		if err := rows.Scan(&table); err != nil {
			return false, fmt.Errorf("read existing table name: %w", err)
		}
		actual[strings.ToLower(table)] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		return false, fmt.Errorf("iterate existing tables: %w", err)
	}

	if len(actual) == 0 {
		return false, nil
	}

	var missing, unexpected []string

	for table := range expected {
		if _, ok := actual[table]; !ok {
			missing = append(missing, table)
		}
	}

	for table := range actual {
		if _, ok := expected[table]; !ok {
			unexpected = append(unexpected, table)
		}
	}

	if len(missing) > 0 || len(unexpected) > 0 {
		sort.Strings(missing)
		sort.Strings(unexpected)

		return false, fmt.Errorf(
			"existing schema does not exactly match %s; missing tables=%v, unexpected tables=%v; refusing to run initial migration",
			migrationName,
			missing,
			unexpected,
		)
	}

	if _, err := db.ExecContext(
		ctx,
		`INSERT INTO schema_migrations (name) VALUES (?)`,
		migrationName,
	); err != nil {
		return false, fmt.Errorf("record baseline %s: %w", migrationName, err)
	}

	log.Printf(
		"baseline recorded: %s (%d existing table names matched; no CREATE TABLE executed)",
		migrationName,
		len(expected),
	)

	return true, nil
}

// Like escapes %, _ and backslash for LIKE patterns.
func Like(s string) string {
	r := strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`)
	return "%" + r.Replace(s) + "%"
}
