#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------
# Export public dataset from MariaDB (or Postgres)
# Produces cleaned CSVs with NO free-text and anonymized session IDs
# Output: exports/axp_public_YYYYMMDD.csv + codebook + README + CHANGELOG
# -----------------------------------------------------------------------------

source("R/config.R")
source("R/db.R")

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(readr)
  library(digest)
})

cfg <- get_config(required = FALSE)
if (!has_db_config(cfg)) {
  stop("Database configuration is incomplete. Set DB_* environment variables.", call. = FALSE)
}

dialect <- get_db_dialect()
message("Connecting to ", dialect, " database...")

conn <- db_connect(cfg)
on.exit(DBI::dbDisconnect(conn), add = TRUE)

message("Reading submissions...")
submission <- db_read_submissions(conn)

message("Reading numeric responses...")
response_numeric <- db_read_responses_numeric(conn)

message("Reading scores...")
score <- db_read_scores(conn)

# NOTE: We intentionally do NOT read response_text (free-text)
# Free-text is stored only in raw DB and never exported to public datasets

if (nrow(submission) == 0) {
  message("No submissions found. Exiting.")
  quit(status = 0)
}

message("Found ", nrow(submission), " submissions")

# -----------------------------------------------------------------------------
# Anonymization: create hashed session IDs
# Uses a salted hash so original UUIDs cannot be reverse-engineered
# The salt should be kept secret and consistent across exports for longitudinal linking
# -----------------------------------------------------------------------------
anon_salt <- Sys.getenv("EXPORT_ANON_SALT", "axp-mvp-default-salt-change-in-prod")

anonymize_session_id <- function(session_id, salt = anon_salt) {
  digest::digest(paste0(salt, session_id), algo = "sha256", serialize = FALSE)
}

submission <- submission %>%
  mutate(
    # Create anonymized session ID
    session_anon = sapply(submission_id, anonymize_session_id),
    # Coarsen timestamp to date only
    created_date = as.Date(created_at)
  ) %>%
  select(-submission_id, -created_at)  # Remove original identifiers

response_numeric <- response_numeric %>%
  mutate(session_anon = sapply(submission_id, anonymize_session_id)) %>%
  select(-submission_id)

score <- score %>%
  mutate(session_anon = sapply(submission_id, anonymize_session_id)) %>%
  select(-submission_id)

# -----------------------------------------------------------------------------
# Build export dataframe
# Wide format: one row per session, columns for each item/scale
# -----------------------------------------------------------------------------
message("Building export dataset...")

# Pivot numeric responses to wide format
responses_wide <- response_numeric %>%
  tidyr::pivot_wider(
    id_cols = session_anon,
    names_from = item_id,
    values_from = value,
    names_prefix = "item_"
  )

# Pivot scores to wide format
scores_wide <- score %>%
  tidyr::pivot_wider(
    id_cols = session_anon,
    names_from = scale_id,
    values_from = score_value,
    names_prefix = "scale_"
  )

# Join everything
export_df <- submission %>%
  left_join(responses_wide, by = "session_anon") %>%
  left_join(scores_wide, by = "session_anon")

# Reorder columns: metadata first, then items, then scales
meta_cols <- c("session_anon", "created_date", "instrument_id", "instrument_version", "language", "definition_hash")
item_cols <- sort(grep("^item_", names(export_df), value = TRUE))
scale_cols <- sort(grep("^scale_", names(export_df), value = TRUE))
other_cols <- setdiff(names(export_df), c(meta_cols, item_cols, scale_cols))

export_df <- export_df[, c(intersect(meta_cols, names(export_df)), other_cols, item_cols, scale_cols)]

# -----------------------------------------------------------------------------
# Write export files
# -----------------------------------------------------------------------------
export_dir <- "exports"
if (!dir.exists(export_dir)) dir.create(export_dir, recursive = TRUE)

stamp <- format(Sys.Date(), "%Y%m%d")
export_path <- file.path(export_dir, paste0("axp_public_", stamp, ".csv"))

message("Writing export to: ", export_path)
write_csv(export_df, export_path, na = "")

# Also write a "latest" symlink-equivalent (just copy for Windows compatibility)
latest_path <- file.path(export_dir, "axp_public_latest.csv")
file.copy(export_path, latest_path, overwrite = TRUE)

# -----------------------------------------------------------------------------
# Generate codebook
# -----------------------------------------------------------------------------
codebook <- data.frame(
  field = names(export_df),
  description = sapply(names(export_df), function(nm) {
    if (nm == "session_anon") return("Anonymized session identifier (SHA-256 hash, not reversible)")
    if (nm == "created_date") return("Date of submission (time coarsened for privacy)")
    if (nm == "instrument_id") return("Questionnaire instrument identifier")
    if (nm == "instrument_version") return("Questionnaire version string")
    if (nm == "language") return("Language code (e.g., 'en', 'de')")
    if (nm == "definition_hash") return("Hash of questionnaire definition at time of submission")
    if (startsWith(nm, "item_")) return(paste("Numeric response for", sub("^item_", "", nm)))
    if (startsWith(nm, "scale_")) return(paste("Computed score for scale:", sub("^scale_", "", nm)))
    return("(undocumented field)")
  }),
  stringsAsFactors = FALSE
)

write_csv(codebook, file.path(export_dir, "codebook.csv"))

# -----------------------------------------------------------------------------
# Generate README
# -----------------------------------------------------------------------------
readme_text <- paste0(
  "# AXP MVP Survey Public Dataset\n\n",
  "**Generated:** ", Sys.Date(), "\n",
  "**Records:** ", nrow(export_df), "\n\n",
  "## Contents\n\n",
  "- `axp_public_", stamp, ".csv` - Main dataset\n",
  "- `axp_public_latest.csv` - Copy of latest export\n",
  "- `codebook.csv` - Field descriptions\n",
  "- `CHANGELOG.md` - Export history\n\n",
  "## Privacy Notes\n\n",
  "- Session IDs are anonymized using SHA-256 hash (not reversible)\n",
  "- Timestamps are coarsened to dates only\n",
  "- **Free-text responses are excluded** (stored only in raw database)\n",
  "- No IP addresses or user agents are included\n\n",
  "## Usage\n\n",
  "```r\n",
  "library(readr)\n",
  "df <- read_csv('axp_public_latest.csv')\n",
  "```\n\n",
  "## License\n\n",
  "See repository LICENSE file.\n"
)

writeLines(readme_text, con = file.path(export_dir, "README.md"))

# -----------------------------------------------------------------------------
# Update changelog
# -----------------------------------------------------------------------------
changelog_path <- file.path(export_dir, "CHANGELOG.md")
new_entry <- paste0(
  "## ", stamp, "\n",
  "- Exported ", nrow(export_df), " submissions\n",
  "- ", length(item_cols), " item columns, ", length(scale_cols), " scale columns\n\n"
)

if (file.exists(changelog_path)) {
  existing <- paste(readLines(changelog_path), collapse = "\n")
  writeLines(paste0(new_entry, existing), con = changelog_path)
} else {
  writeLines(paste0("# Export Changelog\n\n", new_entry), con = changelog_path)
}

message("Export complete!")
message("Files written to: ", normalizePath(export_dir))
message("  - ", basename(export_path))
message("  - axp_public_latest.csv")
message("  - codebook.csv")
message("  - README.md")
message("  - CHANGELOG.md")
