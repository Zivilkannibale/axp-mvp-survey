#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------
# Initialize MariaDB schema
# Run this once on the server to create tables
# Usage: Rscript scripts/init_mariadb.R
# -----------------------------------------------------------------------------

source("R/config.R")
source("R/db.R")

cat("Connecting to MariaDB...\n")
cfg <- get_config(required = FALSE)

if (!has_db_config(cfg)) {
  stop("Database not configured. Set DB_HOST, DB_NAME, DB_USER, DB_PASSWORD in app/.Renviron")
}

con <- db_connect(cfg)
cat("✅ Connected successfully\n")

cat("Initializing schema from sql/001_init_mariadb.sql...\n")
db_init_schema(con, "sql/001_init.sql")  # Will auto-select _mariadb.sql

cat("✅ Schema initialized\n")

# Verify tables exist
tables <- DBI::dbListTables(con)
cat("Tables in database:\n")
print(tables)

expected <- c("submission", "response_numeric", "response_text", "score", "aggregate_norms", "response_tracer")
missing <- setdiff(expected, tables)
if (length(missing) > 0) {
  warning("Missing tables: ", paste(missing, collapse = ", "))
} else {
  cat("✅ All expected tables present\n")
}

DBI::dbDisconnect(con)
cat("Done.\n")
