<#
.SYNOPSIS
    Renames child folders by adding a "YYYY-MM" prefix based on the oldest file's date.

.DESCRIPTION
    This script inspects all files within each subfolder (including hidden files) to find the oldest date.
    It uses "Date Taken" first, falling back to the file's creation date if necessary. It then renames
    the folder with a "YYYY-MM - " prefix. It will not re-process folders that already have this prefix.

.NOTES
    - MODE: Live Mode. This script will make permanent changes.
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
Write-Host "Mode: Adding 'YYYY-MM -' prefix based on oldest file (LIVE MODE)." -ForegroundColor Green

# Get all immediate child directories of the parent folder.
Get-ChildItem -Path $parentFolder -Directory | ForEach-Object {
    $folder = $_
    
    # Safety check: if the folder already has the correct prefix, skip it.
    if ($folder.Name -match '^\d{4}-\d{2}') {
        Write-Host "Skipping already prefixed folder: $($folder.Name)" -ForegroundColor Yellow
        return
    }

    # Using -LiteralPath to handle special characters like [ and ] in folder names.
    $files = Get-ChildItem -LiteralPath $folder.FullName -File -Recurse -Force

    if (-not $files) {
        Write-Host "Skipping empty folder: $($folder.Name)" -ForegroundColor Gray
        return
    }

    $dateValues = [System.Collections.ArrayList]::new()

    foreach ($file in $files) {
        $fileDate = $null # Reset for each file
        
        $fileParentDir = $file.DirectoryName
        if (-not $namespaceCache.ContainsKey($fileParentDir)) {
            $namespaceCache[$fileParentDir] = $shell.Namespace($fileParentDir)
        }
        $namespace = $namespaceCache[$fileParentDir]

        if ($namespace) {
            $fileItem = $namespace.ParseName($file.Name)
            if ($fileItem) {
                $dateTakenStr = $namespace.GetDetailsOf($fileItem, 12)
                if (-not [string]::IsNullOrWhiteSpace($dateTakenStr)) {
                    try {
                        $sanitizedDateStr = $dateTakenStr -replace "[\u200e\u200f]"
                        $fileDate = [datetime]::Parse($sanitizedDateStr, $cultureInfo)
                    } catch {
                        # Parsing failed, $fileDate remains null, so we'll use the fallback.
                    }
                }
            }
        }
        
        # If we failed to get a valid "Date Taken", always fall back to the file's CreationTime.
        if ($null -eq $fileDate) {
            $fileDate = $file.CreationTime
        }
        $null = $dateValues.Add($fileDate)
    }
    
    if ($dateValues.Count -eq 0) {
        Write-Host "Could not determine a date for any files in folder '$($folder.Name)'. Skipping." -ForegroundColor Red
        return
    }

    # Sort the dates to find the earliest one.
    $earliestDate = ($dateValues | Sort-Object)[0]

    # Use the earliest date to create the prefix.
    $prefix = $earliestDate.ToString('yyyy-MM')

    # Construct the new name.
    $newName = "$prefix - $($folder.Name)"

    # Perform the rename if a new name was generated and it's different from the original
    if ((-not [string]::IsNullOrEmpty($newName)) -and ($newName -ne $folder.Name)) {
        Write-Host "Renaming '$($folder.Name)' to '$newName'" -ForegroundColor Green
        
        # --- RENAME COMMAND ---
        Rename-Item -LiteralPath $folder.FullName -NewName $newName
    }
}

# Clean up the COM object.
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
Remove-Variable shell
$namespaceCache.Clear()

Write-Host "Script finished." -ForegroundColor Cyan
