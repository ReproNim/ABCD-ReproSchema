#!/usr/bin/env Rscript
# Extract a specific ABCD release from lst_dds.rda to CSV
#
# Usage: Rscript extract_release.R <rda_path> <release_version> <output_csv>
# Example: Rscript extract_release.R NBDCtoolsData/data/lst_dds.rda 6.0 data/abcd_6.0.csv

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  cat("Usage: Rscript extract_release.R <rda_path> <release_version> <output_csv>\n")
  cat("Example: Rscript extract_release.R NBDCtoolsData/data/lst_dds.rda 6.0 data/abcd_6.0.csv\n")
  quit(status = 1)
}

rda_path <- args[1]
release_version <- args[2]
output_csv <- args[3]

cat(sprintf("Loading: %s\n", rda_path))
load(rda_path)

# lst_dds has top-level keys: abcd, hbcd
cat(sprintf("Top-level objects: %s\n", paste(names(lst_dds), collapse = ", ")))

# Get ABCD data
if (!"abcd" %in% names(lst_dds)) {
  cat("Error: 'abcd' not found in lst_dds\n")
  quit(status = 1)
}

abcd_data <- lst_dds[["abcd"]]
cat(sprintf("ABCD releases available: %s\n", paste(names(abcd_data), collapse = ", ")))

# Find the matching release (try different key formats)
release_key <- release_version
if (!release_key %in% names(abcd_data)) {
  release_key <- paste0("abcd_", release_version)
}
if (!release_key %in% names(abcd_data)) {
  release_key <- paste0("v", release_version)
}

if (!release_key %in% names(abcd_data)) {
  cat(sprintf("Error: Release '%s' not found. Available: %s\n",
              release_version, paste(names(abcd_data), collapse = ", ")))
  quit(status = 1)
}

cat(sprintf("Extracting release: %s\n", release_key))
release_data <- abcd_data[[release_key]]

# Check what type of data we have
cat(sprintf("Data type: %s\n", class(release_data)))

# If it's a list, try to find the data dictionary
if (is.list(release_data) && !is.data.frame(release_data)) {
  cat(sprintf("Release contains: %s\n", paste(names(release_data), collapse = ", ")))
  # Look for data dictionary - common names: dd, data_dict, dictionary
  for (key in c("dd", "data_dict", "dictionary", names(release_data)[1])) {
    if (key %in% names(release_data)) {
      release_data <- release_data[[key]]
      cat(sprintf("Using nested key: %s\n", key))
      break
    }
  }
}

if (!is.data.frame(release_data)) {
  cat(sprintf("Error: Expected data.frame but got %s\n", class(release_data)))
  quit(status = 1)
}

# Convert to regular data.frame and handle list columns
release_data <- as.data.frame(release_data)

# Check for and flatten list columns (common in tibbles)
for (col in names(release_data)) {
  if (is.list(release_data[[col]])) {
    cat(sprintf("Converting list column to character: %s\n", col))
    release_data[[col]] <- sapply(release_data[[col]], function(x) {
      if (is.null(x) || length(x) == 0) {
        NA_character_
      } else {
        paste(x, collapse = "; ")
      }
    })
  }
}

# Create output directory if needed
output_dir <- dirname(output_csv)
if (output_dir != "." && !dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Write to CSV
cat(sprintf("Writing to: %s\n", output_csv))
write.csv(release_data, output_csv, row.names = FALSE)

cat(sprintf("Done! Extracted %d rows, %d columns\n", nrow(release_data), ncol(release_data)))
