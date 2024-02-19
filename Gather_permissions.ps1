<#
.SYNOPSIS
    gather_permissions.ps1 - Gather the open permissions and save the list as a json file.

.DESCRIPTION
    Gather the open permissions and save the list as a json file.

.EXAMPLE
    .\gather_permissions.ps1 "C:\Path\To\Folder"
#>
param (
    [string]$FolderPath = $null
)
# Get the current date and time
$currentDateTime = (Get-Date).ToString("yyyy-MM-dd HH:mm")

# If no folder path is provided, prompt the user to input one
if (-not $FolderPath) {
    $FolderPath = Read-Host "Enter the path to the folder"
}

$Domain = Read-Host "Enter the domain the file server is in"

# Validate that the folder path exists
if (-not (Test-Path -Path $FolderPath -PathType Container)) {
    Write-Host "Folder path '$FolderPath' does not exist."
    exit
}

# Get all items in the specified folder and its subfolders
$items = Get-ChildItem -LiteralPath $FolderPath -Recurse -Force -ErrorAction SilentlyContinue

# Initialize a counter and an array to hold the access denied items
$i = 0
$accessDeniedItems = @()

# Process each item
$processedItems = $items | ForEach-Object {
    $i++
    Write-Progress -Activity "Processing Items" -Status "$i out of $($items.Count)" -PercentComplete (($i / $items.Count) * 100)
    if (Test-Path -LiteralPath $_.FullName -ErrorAction SilentlyContinue) {
        try {
            # Get the ACL for the item
            $acl = Get-Acl -LiteralPath $_.FullName

            # Create a custom object with only the full path and the access rights
            New-Object PSObject -Property @{
                FullPath = $_.FullName;
                Access = $acl.Access | ForEach-Object { 
                    $hash = @{
                        Domain = $Domain;
                        IdentityReference = $_.IdentityReference.ToString();
                        FileSystemRights = $_.FileSystemRights.ToString();
                        Current_Date = $currentDateTime
                    }
                    $hash.PSObject.TypeNames.Insert(0,'System.Management.Automation.PSCustomObject')
                    $hash
                } | ConvertTo-Json -Compress
            }
        } catch {
            if ($_.Exception -is [System.UnauthorizedAccessException]) {
                Write-Host "Access denied to $($_.FullName)"
                $accessDeniedItems += $_.FullName
            } else {
                throw $_
            }
        }
    } else {
        Write-Host "Item $($_.FullName) does not exist"
        $accessDeniedItems += $_.FullName
    }
}

$RandomString = -join (48..57 + 65..90 + 97..122 | Get-Random -Count 4 | ForEach-Object { [char]$_ })

# Save the permissions as a JSON file on the desktop
$desktopPath = [Environment]::GetFolderPath("Desktop")
$permissionsFilePath = Join-Path -Path $desktopPath -ChildPath "permissions_set_$currentDateTime_$RandomString.json"
$processedItems | ConvertTo-Json | Out-File -FilePath $permissionsFilePath

# Save the list of access denied items as a JSON file on the desktop
$accessDeniedFilePath = Join-Path -Path $desktopPath -ChildPath "access_denied_$currentDateTime_$RandomString.json"
$accessDeniedItems | ConvertTo-Json -Depth 4 | Out-File -FilePath $accessDeniedFilePath

Write-Host "Permissions saved to $permissionsFilePath"
Write-Host "List of access denied items saved to $accessDeniedFilePath"
