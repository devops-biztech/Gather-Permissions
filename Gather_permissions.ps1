<#
.SYNOPSIS
    gather_permissions.ps1 - Gather the open permissions and save the list as a json file.

.DESCRIPTION
    Gather the open permissions and save the list as a json file.

.EXAMPLE
    .\gather_permissions.ps1 "C:\Path\To\Folder"
#>
param (
    [string]$ParentFolderPath = $null,
    [string]$AlsoFiles = "no"
)

function GatherItems {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ParentFolderPath,
        [Parameter(Mandatory=$true)]
        [string]$AlsoFiles
    )
    if ($AlsoFiles -eq "no") {
        Write-Progress -Activity "Gathering Items (only folders) from $ParentFolderPath ..."
        $items = Get-ChildItem -LiteralPath $ParentFolderPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
    } else {
        Write-Progress -Activity "Gathering All Items from $ParentFolderPath ..."
        $items = Get-ChildItem -LiteralPath $ParentFolderPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    return $items
}

function ProcessThisItem {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Domain,
        [Parameter(Mandatory=$true)]
        [datetime]$currentDateTime,
        [Parameter(Mandatory=$true)]
        [System.IO.FileSystemInfo]$item
    )

    if (Test-Path -LiteralPath $item.FullName -ErrorAction SilentlyContinue) {
        try {
            # Get the ACL for the item
            $acl = Get-Acl -LiteralPath $item.FullName
            # Create a custom object with only the full path and the access rights
            New-Object PSObject -Property @{
                FullPath = $item.FullName;
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
                Write-Host "Access denied to $($item.FullName)"
                $global:accessDeniedItems += $item.FullName
            } else {
                throw $_
            }
        }
    } else {
        Write-Host "Item $($item.FullName) does not exist"
        $global:accessDeniedItems += $item.FullName
    }
}

function Get-ItemPermissions {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Domain,
        [Parameter(Mandatory=$true)]
        [datetime]$currentDateTime,
        [Parameter(Mandatory=$true)]
        [array]$items
    )

    if($items.Count -eq 0) {
        Write-Host "No Items were found!  Exiting"
        exit
    }
    $i = 0
    if ($items.Count -gt 0) {
        $global:processedItems = $items | ForEach-Object {
            Write-Progress -Activity "Processing Items..." -Status "$i out of $($items.Count)" -PercentComplete (($i / $items.Count) * 100)
            ProcessThisItem -Domain $Domain -currentDateTime $currentDateTime -item $_    
            $i++
        }
    } else {
        Write-Host "No Items were found...skipping!"
        $i++
    }
}
# Check PowerShell version
$isPS7OrLater = $PSVersionTable.PSVersion.Major -ge 7

# Get the current date and time
$currentDateTime = (Get-Date).ToString("yyyy-MM-dd HH:mm")

$RandomString = -join (48..57 + 65..90 + 97..122 | Get-Random -Count 4 | ForEach-Object { [char]$_ })
# Save the permissions as a JSON file on the desktop
$desktopPath = [Environment]::GetFolderPath("Desktop")

$Domain = Read-Host "Enter the domain the file server is in"

# Initialize an array to hold the access denied items in the global scope
$global:accessDeniedItems = @()

# If no folder path is provided, prompt the user to input one
if (-not $ParentFolderPath) {
    $ParentFolderPath = Read-Host "Enter the path to the folder"
}

# Validate that the folder path exists
if (-not (Test-Path -Path $ParentFolderPath -PathType Container)) {
    Write-Host "Folder path '$ParentFolderPath' does not exist."
    exit
}

$items = GatherItems -ParentFolderPath $ParentFolderPath -AlsoFiles $AlsoFiles
Write-Progress -Activity "Gathering Item Permissions..."
Get-ItemPermissions -Domain $Domain -currentDateTime $currentDateTime -items $items


$permissionsFilePath = Join-Path -Path $desktopPath -ChildPath "permissions_set_$currentDateTime_$RandomString.json"
$global:processedItems | ConvertTo-Json | Out-File -FilePath $permissionsFilePath

# Save the list of access denied items as a JSON file on the desktop
$accessDeniedFilePath = Join-Path -Path $desktopPath -ChildPath "access_denied_$currentDateTime_$RandomString.json"
$global:accessDeniedItems | ConvertTo-Json -Depth 4 | Out-File -FilePath $accessDeniedFilePath

Write-Host "Permissions saved to $permissionsFilePath"
Write-Host "List of access denied items saved to $accessDeniedFilePath"
