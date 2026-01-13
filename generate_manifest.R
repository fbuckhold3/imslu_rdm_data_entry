# Generate manifest.json for Posit Connect deployment
# Run this script before deploying to Posit Connect

library(rsconnect)

# Generate manifest file
rsconnect::writeManifest(appDir = ".")

cat("manifest.json has been generated successfully!\n")
cat("\nTo deploy to Posit Connect:\n")
cat("1. Set environment variables on Posit Connect:\n")
cat("   - REDCAP_URL: https://redcapsurvey.slu.edu/api/\n")
cat("   - REDCAP_TOKEN: <your_redcap_api_token>\n")
cat("   - APP_PASSWORD: <your_chosen_password>\n")
cat("\n2. Deploy using rsconnect::deployApp() or the Posit Connect UI\n")
