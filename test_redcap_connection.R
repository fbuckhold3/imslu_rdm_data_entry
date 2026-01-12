# Test REDCap Connection
# This script helps verify your REDCap API configuration before running the app

library(REDCapR)
library(httr)
httr::set_config(httr::config(ssl_verifypeer = FALSE))

# Load configuration from environment
REDCAP_URL <- Sys.getenv("REDCAP_URL")
REDCAP_TOKEN <- Sys.getenv("REDCAP_TOKEN")

cat("\n=== REDCap Connection Test ===\n\n")

# Check if configuration is set
cat("1. Checking configuration...\n")

if (REDCAP_URL == "" || is.na(REDCAP_URL)) {
  cat("   ✗ REDCAP_URL not set\n")
  cat("   Please set REDCAP_URL in your .Renviron file\n\n")
  stop("Configuration error")
} else {
  cat("   ✓ REDCAP_URL:", REDCAP_URL, "\n")
}

if (REDCAP_TOKEN == "" || is.na(REDCAP_TOKEN)) {
  cat("   ✗ REDCAP_TOKEN not set\n")
  cat("   Please set REDCAP_TOKEN in your .Renviron file\n\n")
  stop("Configuration error")
} else {
  cat("   ✓ REDCAP_TOKEN: [hidden]\n")
}

cat("\n2. Testing API connection...\n")

# Test read access
result <- tryCatch({
  REDCapR::redcap_read_oneshot(
    redcap_uri = REDCAP_URL,
    token = REDCAP_TOKEN
  )
}, error = function(e) {
  list(success = FALSE, outcome_message = e$message)
})

if (!result$success) {
  cat("   ✗ Connection failed\n")
  cat("   Error:", result$outcome_message, "\n\n")
  cat("Common issues:\n")
  cat("   - Check that your API token is correct\n")
  cat("   - Verify the REDCap URL (should end with /api/)\n")
  cat("   - Ensure API access is enabled in REDCap\n")
  cat("   - Check that the project exists and you have access\n\n")
  stop("Connection test failed")
} else {
  cat("   ✓ Successfully connected to REDCap\n")
  cat("   Records retrieved:", nrow(result$data), "\n")
  cat("   Fields:", ncol(result$data), "\n")
  
  if (nrow(result$data) > 0) {
    cat("\n3. Sample data preview:\n")
    cat("   First 5 records:\n")
    print(head(result$data[, 1:min(5, ncol(result$data))], 5))
    
    cat("\n   Field names (first 10):\n")
    print(head(names(result$data), 10))
  }
}

cat("\n4. Testing write access...\n")

# Create a test record (we won't actually push it)
test_data <- data.frame(
  record_id = "TEST_RECORD",
  stringsAsFactors = FALSE
)

cat("   Note: Write test is simulated to avoid creating test records\n")
cat("   Your token should have write permissions for the app to work fully\n")

cat("\n=== Connection Test Complete ===\n")
cat("✓ Your REDCap configuration is working!\n")
cat("You can now run the Shiny app.\n\n")

# Test data dictionary loading
cat("\n5. Testing data dictionary loading...\n")

dd_paths <- c(
  "data_dict.csv",
  "/mnt/user-data/uploads/data_dict.csv"
)

dd_found <- FALSE
for (path in dd_paths) {
  if (file.exists(path)) {
    dd <- tryCatch({
      read.csv(path, stringsAsFactors = FALSE)
    }, error = function(e) NULL)
    
    if (!is.null(dd)) {
      cat("   ✓ Data dictionary found at:", path, "\n")
      cat("   Fields defined:", nrow(dd), "\n")
      
      # Show unique forms
      forms <- unique(dd$form_name)
      cat("   Forms:", length(forms), "\n")
      cat("   Form names:", paste(head(forms, 5), collapse = ", "), 
          if(length(forms) > 5) "..." else "", "\n")
      
      dd_found <- TRUE
      break
    }
  }
}

if (!dd_found) {
  cat("   ✗ Data dictionary not found\n")
  cat("   Please ensure data_dict.csv is in the correct location\n")
}

cat("\n=== All Tests Complete ===\n\n")

# Summary
cat("Summary:\n")
cat("  API Connection:     ✓\n")
cat("  Data Retrieved:     ✓ (", nrow(result$data), " records)\n", sep = "")
if (dd_found) {
  cat("  Data Dictionary:    ✓\n")
} else {
  cat("  Data Dictionary:    ✗ (needs attention)\n")
}

cat("\nNext steps:\n")
cat("  1. Review the configuration above\n")
cat("  2. If everything looks good, run the Shiny app\n")
if (!dd_found) {
  cat("  3. Fix the data dictionary path issue first\n")
}
cat("\n")
