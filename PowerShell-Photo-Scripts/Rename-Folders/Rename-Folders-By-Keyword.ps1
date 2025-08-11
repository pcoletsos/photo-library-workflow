<#
.SYNOPSIS
    Renames folders based on keywords like "Christmas", "Pasxa", or as birthdays, correctly handling existing YYYY-MM prefixes.

.DESCRIPTION
    This script is designed for folders containing photos and videos. It should be placed and run within a parent directory.
    It iterates through each subdirectory and renames it based on its content.

    The new renaming rules are as follows:
    1. If the folder name contains "Christmas" or "Christmass", it is renamed to "[Christmas YYYY]".
    2. If the folder name contains "Pasxa" or "Easter", it is renamed to "[Easter YYYY]".
    3. For all other folders, they are assumed to be birthdays and renamed to "[BIRTHDAY YYYY] - Cleaned Name".

    The script is now smart about where it gets the year (YYYY):
    - First, it checks for an existing `YYYY-MM - ` prefix and uses that year.
    - If no prefix exists, it looks for a 4-digit year in the folder name itself.
    - If no year is found in either place, it falls back to the date of the OLDEST file inside the folder.

.NOTES
    - LOGIC CHANGE: The script now correctly KEEPS the old `YYYY-MM - ` prefix and appends the new name format.
    - CULTURE: This script is configured to handle date formats from the Greek (el-GR) culture.
    - FALLBACK: If "Date Taken" is unavailable, the file's creation date is used.
    - FINAL VERSION: This script will perform permanent renaming operations.
    - LOCATION: This script is intended to be run from the parent folder whose children you want to process.
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
Write-Host "Mode: Renaming based on keywords (Christmas, Easter, Birthday)." -ForegroundColor Yellow

# Get all immediate child directories of the parent folder.
Get-ChildItem -Path $parentFolder -Directory | ForEach-Object {
    $folder = $_
    
    # Safety check: if the folder already seems to be in the new format, skip it.
    if ($folder.Name -match '\[(Christmas|Easter|BIRTHDAY)\s\d{4}\]') {
        Write-Host "Skipping already renamed folder: $($folder.Name)" -ForegroundColor Yellow
        return
    }

    $files = Get-ChildItem -Path $folder.FullName -File -Recurse

    if (-not $files) {
        Write-Host "Skipping empty folder: $($folder.Name)" -ForegroundColor Gray
        return
    }

    $dateValues = [System.Collections.ArrayList]::new()

    foreach ($file in $files) {
        $fileParentDir = $file.DirectoryName
        
        if (-not $namespaceCache.ContainsKey($fileParentDir)) {
            $namespaceCache[$fileParentDir] = $shell.Namespace($fileParentDir)
        }
        $namespace = $namespaceCache[$fileParentDir]

        $fileDate = $null
        
        if ($namespace) {
            $fileItem = $namespace.ParseName($file.Name)
            if ($fileItem) {
                # Index 12 is "Date Taken".
                $dateTakenStr = $namespace.GetDetailsOf($fileItem, 12)

                if (-not [string]::IsNullOrWhiteSpace($dateTakenStr)) {
                    try {
                        $sanitizedDateStr = $dateTakenStr -replace "[\u200e\u200f]"
                        $fileDate = [datetime]::Parse($sanitizedDateStr, $cultureInfo)
                    } catch {
                        Write-Warning "Could not parse 'Date Taken' for '$($file.Name)'. Using file creation date as fallback."
                        $fileDate = $file.CreationTime
                    }
                } else {
                    $fileDate = $file.CreationTime
                }
            } else {
                $fileDate = $file.CreationTime
            }
        } else {
            $fileDate = $file.CreationTime
        }
        
        $null = $dateValues.Add($fileDate)
    }
    
    if ($dateValues.Count -eq 0) {
        Write-Host "Skipping folder '$($folder.Name)' - no valid dates could be determined." -ForegroundColor Gray
        return
    }

    # --- NEW RENAMING LOGIC ---

    # Find the earliest date from all the files to use as a final fallback year.
    $fileBasedYear = ($dateValues | Sort-Object)[0].Year
    
    $keywordPart = ""
    $nameToProcess = $folder.Name
    $yearToUse = $null
    $prefixToKeep = ""

    # UPDATED: Check for and KEEP the old YYYY-MM prefix.
    if ($folder.Name -match '^(\d{4}-\d{2}\s*-\s*)(.*)') {
        $prefixToKeep = $matches[1]    # Store the prefix (e.g., "2010-12 - ")
        $yearToUse = $matches[1] -replace '-.*' # Extract the year from the prefix
        $nameToProcess = $matches[2]   # Work with the rest of the name
    }

    # Case 1: Christmas
    if ($nameToProcess -match 'Christmass?|Christmas') {
        # Try to get year from the name itself, overriding the prefix year if it exists.
        if ($nameToProcess -match '(\d{4})') {
            $yearToUse = $matches[1]
        }
        if (-not $yearToUse) { $yearToUse = $fileBasedYear }
        $keywordPart = "[Christmas $yearToUse]"
    }
    # Case 2: Easter/Pasxa
    elseif ($nameToProcess -match 'Pasxa|Easter') {
        # Try to get year from the name itself first
        if ($nameToProcess -match '(\d{4})') {
            $yearToUse = $matches[1]
        }
        if (-not $yearToUse) { $yearToUse = $fileBasedYear }
        $keywordPart = "[Easter $yearToUse]"
    }
    # Case 3: Birthday (default)
    else {
        if (-not $yearToUse) { $yearToUse = $fileBasedYear }
        # Clean up the name to remove years, parenthetical numbers, and extra spaces.
        $cleanedName = $nameToProcess -replace '\s+\d{4}\s*$' -replace '\s*\(\d+\)\s*$' | ForEach-Object { $_.Trim() }
        $keywordPart = "[BIRTHDAY $yearToUse] - $cleanedName"
    }

    # Construct the new name by combining the original prefix (if any) with the new keyword part.
    $newName = "$prefixToKeep$keywordPart"

    # Perform the rename if a new name was generated and it's different from the original
    if ((-not [string]::IsNullOrEmpty($newName)) -and ($newName -ne $folder.Name)) {
        Write-Host "Renaming '$($folder.Name)' to '$newName'" -ForegroundColor Green
        
        # --- RENAME COMMAND ---
        # The -WhatIf parameter has been removed. This command will now execute.
        Rename-Item -Path $folder.FullName -NewName $newName
    }
}

# Clean up the COM object.
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
Remove-Variable shell
$namespaceCache.Clear()

Write-Host "Script finished." -ForegroundColor Cyan
