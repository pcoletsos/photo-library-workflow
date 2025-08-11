<#
.SYNOPSIS
    Renames child folders with a "YYYY-MM" prefix based on the "Date Taken" metadata or file creation date.

.DESCRIPTION
    This script is designed for folders containing photos and videos. It should be placed and run within a parent directory.
    It iterates through each subdirectory to determine the correct month for the prefix.

    The script inspects all files within a folder, determines the date for each (using "Date Taken" first, then the file's "CreationTime" as a fallback),
    and finds the single OLDEST date among all the files.

    It then uses this oldest date to prepend a "YYYY-MM" prefix to the folder's name.
    The script will not re-rename a folder that already has this prefix.

.NOTES
    - CULTURE: This script is configured to handle date formats from the Greek (el-GR) culture.
    - FALLBACK: If "Date Taken" is unavailable, the file's creation date is used instead. A warning will be displayed.
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
Write-Host "Mode: Reading 'Date Taken' (with fallback to File Creation Date)." -ForegroundColor Yellow

# Get all immediate child directories of the parent folder.
Get-ChildItem -Path $parentFolder -Directory | ForEach-Object {
    $folder = $_
    
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
                        # Aggressively remove invisible Unicode control characters (like Left-to-Right Mark)
                        # that often cause parsing issues with strings from the COM object.
                        $sanitizedDateStr = $dateTakenStr -replace "[\u200e\u200f]"
                        
                        # Use robust parsing with the specified culture.
                        $fileDate = [datetime]::Parse($sanitizedDateStr, $cultureInfo)
                    } catch {
                        # The warning now includes the raw string for better debugging.
                        Write-Warning "Could not parse 'Date Taken' for '$($file.Name)'. Raw value: '$dateTakenStr'. Using file creation date as fallback."
                        # Fallback to creation time if parsing fails.
                        $fileDate = $file.CreationTime
                    }
                } else {
                    # Fallback to creation time if "Date Taken" is empty.
                    $fileDate = $file.CreationTime
                }
            } else {
                # Fallback if the file item can't be parsed by the shell.
                $fileDate = $file.CreationTime
            }
        } else {
            # Fallback if the namespace can't be retrieved.
            $fileDate = $file.CreationTime
        }
        
        $null = $dateValues.Add($fileDate)
    }
    
    if ($dateValues.Count -eq 0) {
        Write-Host "Skipping folder '$($folder.Name)' - no valid dates could be determined." -ForegroundColor Gray
        return
    }

    # NEW LOGIC: Sort the dates to find the earliest one.
    $sortedDates = $dateValues | Sort-Object
    $earliestDate = $sortedDates[0]

    # Use the earliest date to create the prefix.
    $prefix = $earliestDate.ToString('yyyy-MM', [System.Globalization.CultureInfo]::InvariantCulture)

    # Check if the folder already has a prefix. If not, rename it.
    if ($folder.Name -notmatch '^\d{4}-\d{2}') {
        $newName = "$prefix - $($folder.Name)"
        Write-Host "Renaming '$($folder.Name)' to '$newName'" -ForegroundColor Green
        
        # --- RENAME COMMAND ---
        # The -WhatIf parameter has been removed. This command will now execute.
        Rename-Item -Path $folder.FullName -NewName $newName
        
    } else {
        Write-Host "Skipping already prefixed folder: $($folder.Name)" -ForegroundColor Yellow
    }
}

# Clean up the COM object.
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
Remove-Variable shell
$namespaceCache.Clear()

Write-Host "Script finished." -ForegroundColor Cyan
