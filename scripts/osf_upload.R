#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------
# Upload public exports to OSF (Open Science Framework)
# Reads from exports/ directory and uploads to configured OSF project
#
# Required environment variables:
#   OSF_TOKEN      - Personal access token from osf.io/settings/tokens
#   OSF_PROJECT_ID - Project ID (e.g., "abc12" from osf.io/abc12)
#
# Optional:
#   OSF_FOLDER     - Target folder name within project (default: "data")
#
# Usage:
#   Rscript scripts/osf_upload.R
# -----------------------------------------------------------------------------

source("R/config.R")

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})

cfg <- get_config(required = FALSE)

osf_token <- cfg$OSF_TOKEN
osf_project <- cfg$OSF_PROJECT_ID
osf_folder <- Sys.getenv("OSF_FOLDER", "data")

# -----------------------------------------------------------------------------
# Validate configuration
# -----------------------------------------------------------------------------
if (osf_token == "" || osf_project == "") {
  message("OSF upload requires the following environment variables:")
  message("  OSF_TOKEN      - Personal access token (get from osf.io/settings/tokens)")
  message("  OSF_PROJECT_ID - Project ID (e.g., 'abc12' from osf.io/abc12)")
  message("")
  message("Optional:")
  message("  OSF_FOLDER     - Target folder name (default: 'data')")
  message("")
  message("Set these in app/.Renviron and re-run.")
  quit(status = 1)
}

# SECURITY: Never log the token
message("OSF project: ", osf_project)
message("Target folder: ", osf_folder)

# -----------------------------------------------------------------------------
# Find files to upload
# -----------------------------------------------------------------------------
export_dir <- "exports"
if (!dir.exists(export_dir)) {
  message("Export directory not found: ", export_dir)
  message("Run scripts/export_public.R first to generate exports.")
  quit(status = 1)
}

# Upload these files
files_to_upload <- c(
  "axp_public_latest.csv",
  "codebook.csv",
  "README.md",
  "CHANGELOG.md"
)

# Also find dated exports
dated_exports <- list.files(export_dir, pattern = "^axp_public_\\d{8}\\.csv$", full.names = FALSE)
files_to_upload <- unique(c(files_to_upload, dated_exports))

# Filter to existing files
files_to_upload <- files_to_upload[file.exists(file.path(export_dir, files_to_upload))]

if (length(files_to_upload) == 0) {
  message("No export files found in ", export_dir)
  message("Run scripts/export_public.R first.")
  quit(status = 1)
}

message("Files to upload:")
for (f in files_to_upload) {
  message("  - ", f)
}

# -----------------------------------------------------------------------------
# OSF API helpers
# -----------------------------------------------------------------------------
osf_base_url <- "https://api.osf.io/v2"

osf_headers <- function(token) {
  add_headers(
    Authorization = paste("Bearer", token),
    `Content-Type` = "application/json"
  )
}

#' Get storage provider upload URL for a project
osf_get_upload_url <- function(project_id, token) {
  url <- paste0(osf_base_url, "/nodes/", project_id, "/files/osfstorage/")
  resp <- GET(url, osf_headers(token))
  
  if (status_code(resp) != 200) {
    stop("Failed to get OSF storage info: ", content(resp, "text", encoding = "UTF-8"))
  }
  
  data <- fromJSON(content(resp, "text", encoding = "UTF-8"))
  # The upload link is in the links section
  data$data$links$upload
}

#' Upload a single file to OSF
osf_upload_file <- function(local_path, filename, upload_base_url, token) {
  # Construct upload URL with query params
  upload_url <- paste0(upload_base_url, "?kind=file&name=", URLencode(filename, reserved = TRUE))
  
  # Read file content
  file_content <- readBin(local_path, "raw", file.info(local_path)$size)
  
  # Upload via PUT
  resp <- PUT(
    upload_url,
    add_headers(
      Authorization = paste("Bearer", token),
      `Content-Type` = "application/octet-stream"
    ),
    body = file_content
  )
  
  status <- status_code(resp)
  
  if (status %in% c(200, 201)) {
    return(list(success = TRUE, status = status, message = "Uploaded successfully"))
  } else if (status == 409) {
    # File exists, try to update it
    # For updates, we need to use the file's specific upload URL
    return(list(success = FALSE, status = status, message = "File exists (use update endpoint or delete first)"))
  } else {
    return(list(success = FALSE, status = status, message = content(resp, "text", encoding = "UTF-8")))
  }
}

# -----------------------------------------------------------------------------
# Perform uploads
# -----------------------------------------------------------------------------
message("\nStarting OSF upload...")

# Get the upload URL for the project's OSF storage
upload_url <- tryCatch({
  osf_get_upload_url(osf_project, osf_token)
}, error = function(e) {
  message("Failed to connect to OSF: ", conditionMessage(e))
  quit(status = 1)
})

message("Upload endpoint obtained")

results <- list()
for (filename in files_to_upload) {
  local_path <- file.path(export_dir, filename)
  message("Uploading: ", filename, " ... ", appendLF = FALSE)
  
  result <- tryCatch({
    osf_upload_file(local_path, filename, upload_url, osf_token)
  }, error = function(e) {
    list(success = FALSE, status = NA, message = conditionMessage(e))
  })
  
  results[[filename]] <- result
  
  if (result$success) {
    message("OK")
  } else {
    message("FAILED (", result$status, "): ", result$message)
  }
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
successes <- sum(sapply(results, function(r) r$success))
failures <- length(results) - successes

message("\n--- Upload Summary ---")
message("Successful: ", successes)
message("Failed: ", failures)
message("Project URL: https://osf.io/", osf_project, "/files/")

if (failures > 0) {
  message("\nNote: If files already exist, you may need to delete them on OSF first,")
  message("or use the OSF web interface to update them.")
  quit(status = 1)
}

message("\nUpload complete!")
