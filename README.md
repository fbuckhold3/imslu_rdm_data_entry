# REDCap Data Entry Shiny Application

A Shiny application for managing REDCap data entry with search, filtering, and validation features.

## Overview

This application provides a user-friendly interface to:
- Pull existing data from REDCap
- Search and filter records
- Fill in missing data with form validation
- Push updates back to REDCap
- Batch upload multiple records
- Password-protected access

## Files Included

### Main Application Files

1. **`redcap_data_entry_app.R`** - Basic version
   - Simple password authentication
   - Core data entry features
   - Recommended for: Quick setup, single-user scenarios

2. **`redcap_data_entry_app_enhanced.R`** - Enhanced version
   - Multi-user authentication with shinymanager
   - Form validation
   - Batch upload capability
   - Missing field highlighting
   - Audit logging
   - Recommended for: Production use, multiple users

### Supporting Files

- **`DEPLOYMENT_GUIDE.md`** - Complete deployment instructions
- **`requirements.txt`** - List of required R packages
- **`.Renviron.template`** - Template for configuration
- **`data_dict.csv`** - Your REDCap data dictionary
- **`test_redcap_connection.R`** - Script to test API connection

## Quick Start

### 1. Install Required Packages

```r
# For basic version
install.packages(c("shiny", "shinydashboard", "DT", "dplyr", "purrr", 
                   "tidyr", "REDCapR", "shinyjs", "shinyWidgets"))

# Additional for enhanced version
install.packages("shinymanager")
```

### 2. Configure Environment

Copy `.Renviron.template` to `.Renviron`:
```bash
cp .Renviron.template .Renviron
```

Edit `.Renviron` with your settings:
```
REDCAP_TOKEN=your_actual_token_here
REDCAP_URL=https://redcap.yourinstitution.edu/api/
APP_PASSWORD=your_secure_password
```

### 3. Test Connection

```r
source("test_redcap_connection.R")
```

### 4. Run the App

```r
# Basic version
shiny::runApp("redcap_data_entry_app.R")

# Enhanced version
shiny::runApp("redcap_data_entry_app_enhanced.R")
```

## Feature Comparison

| Feature | Basic Version | Enhanced Version |
|---------|--------------|------------------|
| REDCap Integration | ✓ | ✓ |
| Search & Filter | ✓ | ✓ |
| Data Entry Forms | ✓ | ✓ |
| Password Protection | ✓ (single) | ✓ (multi-user) |
| Form Validation | - | ✓ |
| Missing Field Highlighting | - | ✓ |
| Batch Upload | - | ✓ |
| Download Filtered Data | - | ✓ |
| Audit Logging | - | ✓ |
| User Management | - | ✓ |

## Which Version Should I Use?

### Use Basic Version if:
- You're the only user
- You want quick setup
- You don't need advanced features
- You're testing or developing

### Use Enhanced Version if:
- Multiple people will use the app
- You need audit trails
- You want form validation
- You need batch upload capabilities
- This is for production use

## Deployment to ShinyApps.io

See `DEPLOYMENT_GUIDE.md` for detailed instructions.

Quick deployment:
```r
library(rsconnect)

# Deploy basic version
rsconnect::deployApp(
  appFiles = c("redcap_data_entry_app.R", "data_dict.csv"),
  appName = "redcap-data-entry"
)

# Deploy enhanced version
rsconnect::deployApp(
  appFiles = c("redcap_data_entry_app_enhanced.R", "data_dict.csv"),
  appName = "redcap-data-entry-enhanced"
)
```

**Important:** Don't forget to set environment variables in ShinyApps.io dashboard!

## Security Best Practices

1. **Never commit sensitive data to Git:**
   ```bash
   echo ".Renviron" >> .gitignore
   echo "*.log" >> .gitignore
   ```

2. **Use strong passwords:**
   - At least 12 characters
   - Mix of letters, numbers, symbols

3. **Rotate API tokens regularly:**
   - Every 6 months recommended
   - After any security incident

4. **Limit token permissions:**
   - Only grant read/write access as needed
   - Consider separate tokens for different apps

5. **Monitor access logs:**
   - Review `audit_log.txt` regularly (enhanced version)
   - Check REDCap logging

## Customization

### Adding New Forms

Forms are automatically detected from your data dictionary. To customize the display:

1. Edit the `select_form` dropdown in the UI section
2. Add form-specific logic in the server section

### Modifying Field Types

Edit the `create_field_input()` function to customize how fields are displayed.

### Adding Custom Validation

Edit the `validate_field_input()` function (enhanced version) to add validation rules.

### Changing Color Scheme

Modify the dashboard colors in the UI section:
```r
dashboardHeader(title = "REDCap Data Entry", 
                skin = "blue")  # Options: blue, black, purple, green, red, yellow
```

## Troubleshooting

### "Could not load REDCap data"

**Check:**
1. Is `REDCAP_TOKEN` set correctly?
2. Is `REDCAP_URL` correct (should end with `/api/`)?
3. Does your token have read permissions?
4. Is your REDCap project accessible?

**Test:**
```r
source("test_redcap_connection.R")
```

### "Data dictionary not found"

**Fix:**
```r
# In the load_data_dictionary() function, update the path:
read.csv("path/to/your/data_dict.csv", stringsAsFactors = FALSE)
```

### "Package not found" errors

**Install missing packages:**
```r
# See requirements.txt for full list
install.packages("package_name")
```

### Authentication not working

**Basic version:**
- Check `APP_PASSWORD` environment variable
- Restart R session after setting environment variables

**Enhanced version:**
- Check credentials data frame in the code
- Default username: "admin", password: "admin123"
- Consider hashing passwords for production

## Support & Resources

- **REDCap API Documentation:** https://redcap.med.upenn.edu/api/help/
- **REDCapR Package:** https://ouhscbbmc.github.io/REDCapR/
- **Shiny Documentation:** https://shiny.rstudio.com/
- **ShinyApps.io Help:** https://docs.posit.co/shinyapps.io/

## Known Limitations

1. **Large datasets:** App may be slow with >10,000 records
2. **Repeating instruments:** Not fully supported in current version
3. **File uploads:** Not supported (REDCap limitation)
4. **Real-time sync:** Data only updates on refresh

## Future Enhancements

Potential additions for future versions:
- [ ] Real-time collaboration
- [ ] Advanced reporting
- [ ] Data quality checks
- [ ] Export to multiple formats
- [ ] Email notifications
- [ ] Mobile-responsive design improvements

## Contributing

To modify or extend this application:
1. Create a branch for your changes
2. Test thoroughly with test data
3. Document any new features
4. Submit changes for review

## License

[Your license here - update based on institutional requirements]

## Contact

For questions or support:
- **Developer:** Fred Buckhold
- **Institution:** SSM - Saint Louis University SOM
- **Email:** [your email]

## Acknowledgments

Built using:
- Shiny by RStudio
- REDCapR by Will Beasley
- DT by RStudio
- And many other excellent R packages

---

**Last Updated:** January 2026
