# REDCap Data Entry App - Deployment Guide

## Overview
This Shiny application connects to REDCap to pull existing data, allows users to fill in missing information, and pushes updates back to REDCap.

## Prerequisites

### Required R Packages
```r
install.packages(c(
  "shiny",
  "shinydashboard", 
  "DT",
  "dplyr",
  "purrr",
  "tidyr",
  "REDCapR",
  "shinyjs",
  "shinyWidgets"
))
```

### REDCap Requirements
- REDCap API access enabled for your project
- API token with read/write permissions
- REDCap API URL for your institution

## Local Setup

### 1. Configure Environment Variables

Create a `.Renviron` file in your project directory:

```bash
# Copy the template
cp .Renviron.template .Renviron
```

Edit `.Renviron` with your credentials:
```
REDCAP_TOKEN=YOUR_ACTUAL_TOKEN_HERE
REDCAP_URL=https://redcap.yourinstitution.edu/api/
APP_PASSWORD=your_secure_password
```

### 2. Place Data Dictionary

Ensure your REDCap data dictionary CSV is at:
```
/path/to/data_dict.csv
```

Update the path in the app if needed (line with `load_data_dictionary()`).

### 3. Run Locally

In RStudio or R console:
```r
shiny::runApp("redcap_data_entry_app.R")
```

The app should open in your browser. Login with the password you set in `.Renviron`.

## Deployment to ShinyApps.io

### 1. Install rsconnect Package

```r
install.packages("rsconnect")
```

### 2. Configure ShinyApps.io Account

```r
library(rsconnect)

# Get your token and secret from shinyapps.io account settings
rsconnect::setAccountInfo(
  name = "your-account-name",
  token = "your-token",
  secret = "your-secret"
)
```

### 3. Set Environment Variables on ShinyApps.io

Since you can't deploy `.Renviron` files, you need to set environment variables through the ShinyApps.io dashboard:

1. Go to https://www.shinyapps.io/admin/#/applications
2. Click on your app after deployment
3. Go to Settings → Vars
4. Add these variables:
   - `REDCAP_TOKEN`: Your REDCap API token
   - `REDCAP_URL`: Your REDCap API URL  
   - `APP_PASSWORD`: Your app password

### 4. Deploy the App

#### Option A: Using RStudio IDE

1. Open `redcap_data_entry_app.R` in RStudio
2. Click the "Publish" button (blue icon in top right)
3. Select ShinyApps.io
4. Choose which files to include (make sure to include `data_dict.csv`)
5. Click Publish

#### Option B: Using R Console

```r
library(rsconnect)

# Deploy to ShinyApps.io
rsconnect::deployApp(
  appDir = ".",
  appFiles = c("redcap_data_entry_app.R", "data_dict.csv"),
  appName = "redcap-data-entry",
  account = "your-account-name"
)
```

### 5. Configure Data Dictionary Path for Deployment

You may need to update the data dictionary loading function to use a relative path:

```r
load_data_dictionary <- function() {
  read.csv("data_dict.csv", stringsAsFactors = FALSE)
}
```

## Security Considerations

### For Production Use:

1. **Enhanced Authentication**: Consider using `shinymanager` package for better user management:
   ```r
   install.packages("shinymanager")
   ```

2. **HTTPS Only**: Ensure ShinyApps.io uses HTTPS (it does by default)

3. **Token Security**: 
   - Never commit tokens to Git
   - Use environment variables only
   - Rotate tokens regularly

4. **Access Logging**: Add logging to track who accesses and modifies data

5. **Input Validation**: Add validation to ensure data integrity

## Troubleshooting

### "Could not load REDCap data"
- Check that `REDCAP_TOKEN` is set correctly
- Verify `REDCAP_URL` is correct
- Ensure your token has read/write permissions
- Test API connection directly:
  ```r
  REDCapR::redcap_read_oneshot(
    redcap_uri = "your_url",
    token = "your_token"
  )
  ```

### "Data dictionary not found"
- Ensure `data_dict.csv` is in the correct location
- For ShinyApps.io, make sure the file is included in deployment

### Authentication Issues
- Verify `APP_PASSWORD` environment variable is set
- On ShinyApps.io, check the Vars settings

### Package Installation Errors
- Make sure all packages are installed with correct versions
- Some packages may require system dependencies

## Customization

### Adding New Forms
Forms are automatically loaded from the data dictionary. To add a new form:
1. Add it to REDCap
2. Update the data dictionary
3. Add the form to the `select_form` choices in the UI

### Modifying Field Display
Edit the `create_field_input()` function to customize how fields are displayed.

### Adding Filters
Add new filter inputs in the "Search and Filter Records" section of the UI.

## Support

For REDCap API documentation:
- https://redcap.med.upenn.edu/api/help/

For ShinyApps.io help:
- https://docs.posit.co/shinyapps.io/

For R package documentation:
- REDCapR: https://ouhscbbmc.github.io/REDCapR/
- Shiny: https://shiny.rstudio.com/

## License

Customize this section based on your institution's requirements.
