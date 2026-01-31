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

# Debug: Print structure info
cat(sprintf("Structure overview:\n"))
cat(sprintf("  - Length: %d\n", length(release_data)))
cat(sprintf("  - Names: %s\n", paste(head(names(release_data), 10), collapse = ", ")))
if (is.data.frame(release_data)) {
  cat(sprintf("  - Dim: %d x %d\n", nrow(release_data), ncol(release_data)))
  # Check first few column types
  for (i in seq_len(min(5, ncol(release_data)))) {
    col_name <- names(release_data)[i]
    col_class <- class(release_data[[col_name]])
    col_len <- length(release_data[[col_name]])
    cat(sprintf("  - Col '%s': class=%s, len=%d\n", col_name, paste(col_class, collapse="/"), col_len))
  }
}

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

# Convert to plain data.frame
release_data <- as.data.frame(release_data, stringsAsFactors = FALSE)

# Diagnose structure
cat(sprintf("Dimensions: %d rows x %d cols\n", nrow(release_data), ncol(release_data)))

# Check for columns with inconsistent lengths
expected_len <- nrow(release_data)
problem_cols <- c()
for (col in names(release_data)) {
  col_len <- length(release_data[[col]])
  if (col_len != expected_len) {
    problem_cols <- c(problem_cols, col)
    cat(sprintf("WARNING: Column '%s' has length %d (expected %d)\n", col, col_len, expected_len))
  }
}

# Build a clean data frame column by column
clean_data <- data.frame(row_id = seq_len(expected_len))
for (col in names(release_data)) {
  col_data <- release_data[[col]]

  # Handle list columns
  if (is.list(col_data)) {
    cat(sprintf("Converting list column: %s\n", col))
    col_data <- sapply(col_data, function(x) {
      if (is.null(x) || length(x) == 0) {
        NA_character_
      } else {
        paste(as.character(x), collapse = "; ")
      }
    })
  }

  # Ensure correct length
  if (length(col_data) != expected_len) {
    cat(sprintf("Padding column '%s' from %d to %d\n", col, length(col_data), expected_len))
    col_data <- c(col_data, rep(NA, expected_len - length(col_data)))
  }

  clean_data[[col]] <- col_data
}

# Remove helper column
clean_data$row_id <- NULL
release_data <- clean_data

cat(sprintf("Clean dimensions: %d rows x %d cols\n", nrow(release_data), ncol(release_data)))

# Create output directory if needed
output_dir <- dirname(output_csv)
if (output_dir != "." && !dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Write to CSV
cat(sprintf("Writing to: %s\n", output_csv))
write.csv(release_data, output_csv, row.names = FALSE)

cat(sprintf("Done! Extracted %d rows, %d columns\n", nrow(release_data), ncol(release_data)))
