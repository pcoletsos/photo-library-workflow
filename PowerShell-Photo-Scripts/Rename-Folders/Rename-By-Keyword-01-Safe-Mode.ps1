<#
.SYNOPSIS
    Previews the renaming of folders based on keywords, using parentheses `()` for the new format.

.DESCRIPTION
    This script renames folders that have a "YYYY-MM - " prefix into a more descriptive format.
    It keeps the original prefix and appends a keyword-based name like "(Christmas YYYY)".

.NOTES
    - MODE: Safe Mode (-WhatIf is enabled). No changes will be made.
    - CONVENTION: Uses parentheses `()` instead of square brackets `[]`.
    - CULTURE: Configured for Greek (el-GR) date formats.
    - LOCATION: Intended to be run from the parent folder.
#>

# Create a Shell Application object to access extended file properties.
$shell = New-Object -ComObject Shell.Application
# Cache for namespace objects to improve performance.
$namespaceCache = @{}
# Define the specific culture for parsing dates. 'el-GR' is for Greek.
$cultureInfo = [System.Globalization.CultureInfo]::new('el-GR')

# Get the directory where the script is located.
$parentFolder = $PSScriptRoot

Write-Host "Scanning folders within: $parentFolder" -ForegroundColor Cyan
Write-Host "Mode: Renaming based on keywords (SAFE MODE)." -ForegroundColor Yellow

# Get all immediate child directories of the parent folder.
Get-ChildItem -Path $parentFolder -Directory | ForEach-Object {
    $folder = $_
    
    # Safety check: if the folder already seems to be in the new format, skip it.
    if ($folder.Name -match '\((Christmas|Easter|BIRTHDAY)\s\d{4}\)') {
        Write-Host "Skipping already renamed folder: $($folder.Name)" -ForegroundColor Yellow
        return
    }

    $keywordPart = ""
    $nameToProcess = $folder.Name
    $yearToUse = $null
    $prefixToKeep = ""

    # Check for and KEEP the old YYYY-MM prefix.
    if ($folder.Name -match '^(\d{4}-\d{2}\s*-\s*)(.*)') {
        $prefixToKeep = $matches[1]
        $yearToUse = $matches[1] -replace '-.*'
        $nameToProcess = $matches[2]
    } else {
        # If there's no YYYY-MM prefix, this script should skip the folder.
        return
    }

    # Case 1: Christmas
    if ($nameToProcess -match 'Christmass?|Christmas') {
        if ($nameToProcess -match '(\d{4})') { $yearToUse = $matches[1] }
        $keywordPart = "(Christmas $yearToUse)"
    }
    # Case 2: Easter/Pasxa
    elseif ($nameToProcess -match 'Pasxa|Easter') {
        if ($nameToProcess -match '(\d{4})') { $yearToUse = $matches[1] }
        $keywordPart = "(Easter $yearToUse)"
    }
    # Case 3: Birthday (default)
    else {
        $cleanedName = $nameToProcess -replace '\s+\d{4}\s*$' -replace '\s*\(\d+\)\s*$' | ForEach-Object { $_.Trim() }
        $keywordPart = "(BIRTHDAY $yearToUse) - $cleanedName"
    }

    $newName = "$prefixToKeep$keywordPart"

    if ((-not [string]::IsNullOrEmpty($newName)) -and ($newName -ne $folder.Name)) {
        Write-Host "Preparing to rename '$($folder.Name)' to '$newName'" -ForegroundColor Green
        
        Rename-Item -LiteralPath $folder.FullName -NewName $newName -WhatIf
    }
}

# Clean up the COM object.
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
Remove-Variable shell
$namespaceCache.Clear()

Write-Host "Script finished." -ForegroundColor Cyan
