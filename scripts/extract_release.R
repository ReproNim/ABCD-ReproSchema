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

# Load required packages BEFORE loading the RDA file
# This is required for proper reconstruction of tibble objects from serialized format
if (requireNamespace("tibble", quietly = TRUE)) {
  library(tibble)
  cat("Loaded tibble package for proper tibble reconstruction\n")
} else {
  cat("WARNING: tibble package not available - tibble columns may not load correctly\n")
}

# Load vctrs if available (needed for some tibble unpacking operations)
if (requireNamespace("vctrs", quietly = TRUE)) {
  library(vctrs)
  cat("Loaded vctrs package\n")
}

# Load dplyr if available (for collect() to materialize lazy tibbles)
if (requireNamespace("dplyr", quietly = TRUE)) {
  library(dplyr)
  cat("Loaded dplyr package\n")
}

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
  cat(sprintf("  - Attributes: %s\n", paste(names(attributes(release_data)), collapse = ", ")))

  # Check first few column types
  for (i in seq_len(min(5, ncol(release_data)))) {
    col_name <- names(release_data)[i]
    col_data <- release_data[[col_name]]
    col_class <- class(col_data)
    col_len <- length(col_data)
    col_attrs <- names(attributes(col_data))
    cat(sprintf("  - Col '%s': class=%s, len=%d, attrs=%s\n",
                col_name, paste(col_class, collapse="/"), col_len,
                if (length(col_attrs) > 0) paste(col_attrs, collapse=",") else "none"))
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

# Get dimensions before conversion
n_rows <- nrow(release_data)
n_cols <- ncol(release_data)
col_names <- names(release_data)
cat(sprintf("Original dimensions: %d rows x %d cols\n", n_rows, n_cols))

# Check if columns have 0 length (ALTREP/lazy column issue)
first_col_len <- length(release_data[[1]])
cat(sprintf("First column length: %d (expected: %d)\n", first_col_len, n_rows))

# Try different materialization approaches
if (first_col_len == 0 && n_rows > 0) {
  cat("Detected 0-length columns - trying materialization approaches...\n")

  # Approach 1: Try dplyr::collect() to materialize lazy tibble
  if (requireNamespace("dplyr", quietly = TRUE)) {
    cat("Trying dplyr::collect()...\n")
    release_data <- tryCatch({
      collected <- dplyr::collect(release_data)
      if (length(collected[[1]]) > 0) {
        cat("dplyr::collect() succeeded\n")
        collected
      } else {
        stop("collect() did not materialize columns")
      }
    }, error = function(e) {
      cat(sprintf("dplyr::collect() failed: %s\n", e$message))
      release_data
    })
    first_col_len <- length(release_data[[1]])
  }

  # Approach 2: Try writing to tempfile and reading back
  if (first_col_len == 0 && n_rows > 0) {
    cat("Trying tempfile round-trip...\n")
    release_data <- tryCatch({
      tmp_file <- tempfile(fileext = ".rds")
      saveRDS(release_data, tmp_file)
      reloaded <- readRDS(tmp_file)
      unlink(tmp_file)
      if (length(reloaded[[1]]) > 0) {
        cat("Tempfile round-trip succeeded\n")
        reloaded
      } else {
        stop("Round-trip did not materialize columns")
      }
    }, error = function(e) {
      cat(sprintf("Tempfile round-trip failed: %s\n", e$message))
      release_data
    })
    first_col_len <- length(release_data[[1]])
  }

  # Approach 3: Force copy by modifying then reverting
  if (first_col_len == 0 && n_rows > 0) {
    cat("Trying force copy via modification...\n")
    release_data <- tryCatch({
      # Adding and removing a column forces a copy
      release_data[["__temp__"]] <- seq_len(n_rows)
      release_data[["__temp__"]] <- NULL
      if (length(release_data[[1]]) > 0) {
        cat("Force copy succeeded\n")
      }
      release_data
    }, error = function(e) {
      cat(sprintf("Force copy failed: %s\n", e$message))
      release_data
    })
    first_col_len <- length(release_data[[1]])
  }
}

# Re-check after materialization attempts
first_col_len <- length(release_data[[1]])
if (first_col_len == 0 && n_rows > 0) {
  cat("Detected 0-length columns in tibble - using row-by-row extraction\n")

  # Extract data row by row using tibble's [ indexing
  # This forces materialization of lazy columns
  result_list <- vector("list", n_cols)
  names(result_list) <- col_names

  # Initialize each column as the correct type
  for (j in seq_len(n_cols)) {
    result_list[[j]] <- vector("character", n_rows)
  }

  # Extract in chunks to avoid memory issues
  chunk_size <- 10000
  n_chunks <- ceiling(n_rows / chunk_size)

  for (chunk in seq_len(n_chunks)) {
    start_row <- (chunk - 1) * chunk_size + 1
    end_row <- min(chunk * chunk_size, n_rows)
    cat(sprintf("Processing rows %d-%d of %d...\n", start_row, end_row, n_rows))

    # Extract this chunk of rows - this forces materialization
    chunk_data <- release_data[start_row:end_row, , drop = FALSE]

    # Convert chunk to data.frame (should work on smaller subsets)
    chunk_df <- tryCatch({
      as.data.frame(chunk_data, stringsAsFactors = FALSE)
    }, error = function(e) {
      # If that fails, extract column by column from the chunk
      temp_list <- lapply(col_names, function(cn) {
        val <- chunk_data[[cn]]
        if (is.list(val)) {
          sapply(val, function(x) {
            if (is.null(x) || length(x) == 0) NA_character_
            else paste(as.character(x), collapse = "; ")
          })
        } else {
          as.character(val)
        }
      })
      names(temp_list) <- col_names
      as.data.frame(temp_list, stringsAsFactors = FALSE)
    })

    # Store in result
    for (j in seq_len(n_cols)) {
      result_list[[j]][start_row:end_row] <- as.character(chunk_df[[j]])
    }
  }

  release_data <- as.data.frame(result_list, stringsAsFactors = FALSE)
  cat(sprintf("Row-by-row extraction complete: %d x %d\n",
              nrow(release_data), ncol(release_data)))
} else {
  # Standard conversion
  release_data <- tryCatch({
    as.data.frame(release_data, stringsAsFactors = FALSE)
  }, error = function(e) {
    cat(sprintf("Standard conversion failed: %s\n", e$message))
    cat("Attempting column-by-column extraction...\n")

    result_list <- lapply(col_names, function(cn) {
      val <- release_data[[cn]]
      if (is.list(val)) {
        sapply(val, function(x) {
          if (is.null(x) || length(x) == 0) NA_character_
          else paste(as.character(x), collapse = "; ")
        })
      } else {
        as.character(val)
      }
    })
    names(result_list) <- col_names
    as.data.frame(result_list, stringsAsFactors = FALSE)
  })
}

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

# Verify the name column has data
name_col <- release_data[["name"]]
non_empty_names <- sum(!is.na(name_col) & nchar(as.character(name_col)) > 0)
cat(sprintf("Name column: %d non-empty values out of %d\n", non_empty_names, length(name_col)))
if (non_empty_names > 0) {
  cat(sprintf("Sample names: %s\n", paste(head(name_col[!is.na(name_col)], 3), collapse=", ")))
}

cat(sprintf("Done! Extracted %d rows, %d columns\n", nrow(release_data), ncol(release_data)))
