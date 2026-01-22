#!/usr/bin/env Rscript

source("R/config.R")

suppressPackageStartupMessages({
  library(httr)
})

cfg <- get_config(required = FALSE)
if (cfg$OSF_TOKEN == "" || cfg$OSF_PROJECT_ID == "") {
  message("OSF token or project id missing. Provide OSF_TOKEN and OSF_PROJECT_ID to enable uploads.")
  quit(status = 0)
}

message("OSF upload placeholder. Use OSF API with token to upload files in exports/.")
message("Project: ", cfg$OSF_PROJECT_ID)
message("Files ready: ", paste(list.files("exports", full.names = TRUE), collapse = ", "))
