# SharePoint Deep Migration Script (.ps1)

This PowerShell script performs file migration from a File Server to a SharePoint Online document library using the Microsoft Graph API. Unlike Microsoft's official SPMT tool, this script supports **deep folder-level navigation and migration**, overcoming the default two-level limitation.

## Features

- Authentication via Microsoft Graph (Client Credentials)
- Folder creation in the destination matching the original structure
- File uploads with duplication and size checks
- Detailed CSV log generation
- Support for filtering by file extension and last modified date
- Automatic token renewal on expiration

## Prerequisites

- Azure App Registration with Microsoft Graph permissions
- PowerShell 5.1+
- Read access to the File Server and write access to SharePoint

## User Input

At the beginning of the script, fill in the following fields:

```powershell
# Replace with your Azure-registered app values
$clientId = "<Your Client ID>"         # How to obtain: https://learn.microsoft.com/en-us/graph/auth-register-app-v2
$clientSecret = "<Your Secret ID>"     # How to generate: https://learn.microsoft.com/en-us/graph/auth-register-app-v2#configure-application-secrets
$tenantId = "<Your Tenant ID>"         # How to find: https://learn.microsoft.com/en-us/microsoft-365/admin/setup/find-your-office-365-tenant-id
$baseUrlPath = "<destination folder path in SharePoint>"

# Also, near the end of the script, adjust these values to match your environment:

$sourceFolder = "\\server\\folder_path\\subfolders\\" # Specify the folder path on your File Server
$driveId = "<SharePoint drive ID>"  # How to obtain: https://learn.microsoft.com/en-us/graph/api/resources/drive?view=graph-rest-1.0
