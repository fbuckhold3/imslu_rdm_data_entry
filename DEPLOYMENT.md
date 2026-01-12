# Deployment Guide for IMSLU Resident Data Management Entry

## Deploying to Posit Connect / Posit Cloud

### Step 1: Generate Manifest File

Before deploying, run this command in R:

```r
source("generate_manifest.R")
```

This will create a `manifest.json` file needed for deployment.

### Step 2: Required Environment Variables

When deploying to Posit Connect, you MUST set these three environment variables:

1. **REDCAP_URL**
   - Value: `https://redcapsurvey.slu.edu/api/`
   - Description: The REDCap API endpoint URL

2. **REDCAP_TOKEN**
   - Value: Your REDCap API token (obtain from REDCap project)
   - Description: Authentication token for accessing REDCap data
   - **IMPORTANT**: Keep this secret and secure!

3. **APP_PASSWORD**
   - Value: Choose a secure password for app login
   - Description: Password users must enter to access the app
   - **IMPORTANT**: Share only with authorized IMSLU administrators

### Step 3: Set Environment Variables in Posit Connect

#### Option A: Via Posit Connect Web UI
1. After deploying the app, go to your app's settings
2. Navigate to "Vars" tab
3. Add each environment variable:
   - Click "+ Add"
   - Enter variable name (e.g., `REDCAP_URL`)
   - Enter variable value
   - Click "Save"
4. Repeat for all three variables

#### Option B: Via Command Line Deployment
```r
rsconnect::deployApp(
  appDir = ".",
  appFiles = c("app.R", "data_dict.csv"),
  appName = "imslu-resident-data-entry",
  envVars = c(
    "REDCAP_URL" = "https://redcapsurvey.slu.edu/api/",
    "REDCAP_TOKEN" = "YOUR_TOKEN_HERE",
    "APP_PASSWORD" = "YOUR_PASSWORD_HERE"
  )
)
```

### Step 4: Deploy

#### Using RStudio/Positron:
1. Open `app.R`
2. Click the "Publish" button (blue icon in top right)
3. Select "Posit Connect"
4. Follow the prompts

#### Using Command Line:
```r
library(rsconnect)

# First time: Add your Posit Connect account
connectApiUser(
  account = "your-account",
  server = "your-server.posit.co",
  apiKey = "your-api-key"
)

# Deploy the app
deployApp(
  appDir = ".",
  appFiles = c("app.R", "data_dict.csv")
)
```

### Step 5: Verify Deployment

1. Navigate to your deployed app URL
2. You should see the login screen with the disclaimer
3. Enter the APP_PASSWORD you configured
4. Verify data loads correctly from REDCap

## Security Notes

- **Never commit** your `.Renviron` file to Git
- **Never hardcode** tokens or passwords in `app.R`
- Always use environment variables for sensitive data
- Limit access to the app URL to authorized personnel only
- Regularly rotate your REDCAP_TOKEN and APP_PASSWORD

## Troubleshooting

### App won't load data
- Check that REDCAP_URL and REDCAP_TOKEN are set correctly
- Verify your REDCap token has appropriate permissions
- Check Posit Connect logs for error messages

### SSL Certificate Errors
- The app includes SSL verification bypass for SLU's REDCap server
- If issues persist, contact SLU IT support

### Can't log in
- Verify APP_PASSWORD environment variable is set
- Ensure you're using the correct password
- Check for typos or extra spaces in the password

## Required R Packages

The following packages must be available on Posit Connect:
- shiny
- shinydashboard
- DT
- dplyr
- REDCapR
- shinyjs
- httr
- readr

These are typically pre-installed on Posit Connect, but may need to be added to your package repository.
