#!/usr/bin/env Rscript

source("R/config.R")
source("R/db.R")

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(readr)
})

cfg <- get_config(required = TRUE)
if (!has_db_config(cfg)) {
  stop("Database configuration is incomplete.", call. = FALSE)
}

conn <- db_connect(cfg)
on.exit(DBI::dbDisconnect(conn), add = TRUE)

db_init_schema(conn)

submission <- DBI::dbGetQuery(conn, "SELECT submission_id, created_at, instrument_id, instrument_version, language, definition_hash FROM submission")
response_numeric <- DBI::dbGetQuery(conn, "SELECT submission_id, item_id, value FROM response_numeric")
score <- DBI::dbGetQuery(conn, "SELECT submission_id, scale_id, score_value FROM score")

export_df <- submission %>%
  left_join(response_numeric, by = "submission_id") %>%
  left_join(score, by = "submission_id") %>%
  mutate(created_date = as.Date(created_at)) %>%
  select(-created_at)

export_dir <- "exports"
if (!dir.exists(export_dir)) dir.create(export_dir, recursive = TRUE)

stamp <- format(Sys.Date(), "%Y%m%d")
export_path <- file.path(export_dir, paste0("axp_public_", stamp, ".csv"))

write_csv(export_df, export_path, na = "")

codebook <- data.frame(
  field = names(export_df),
  description = c(
    "Submission identifier",
    "Instrument identifier",
    "Instrument version",
    "Language",
    "Definition hash",
    "Item id",
    "Numeric response value",
    "Scale id",
    "Score value",
    "Submission date"
  ),
  stringsAsFactors = FALSE
)
write_csv(codebook, file.path(export_dir, "codebook.csv"))

readme_text <- paste(
  "AXP MVP Survey Export",
  "",
  "This bundle contains de-identified aggregate data for public release.",
  "Free-text responses are excluded by default.",
  "Timestamps are coarsened to dates.",
  sep = "\n"
)
writeLines(readme_text, con = file.path(export_dir, "README.md"))

changelog_text <- paste(
  paste0("## ", stamp),
  "- Initial export.",
  sep = "\n"
)
writeLines(changelog_text, con = file.path(export_dir, "CHANGELOG.md"))

message("Export written to ", export_path)
