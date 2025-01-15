# Define a list of packages with their Package IDs and target versions
$Packages = @(
    @{
        PackageID = "HEVC Video Extensions from Device Manufacturer";  # Example Package ID
        TargetVersion = "2.2.9.0";              # Desired version
        StoreUrl = "https://apps.microsoft.com/detail/9n4wgh0z6vhq?hl=en-US&gl=US"  # Store URL for download
    },
    @{
        PackageID = "HEIF Image Extensions";
        TargetVersion = "1.2.3.70";
        StoreUrl = "https://apps.microsoft.com/detail/9pmmsr1cgpwg"
    }
    # Add more packages as needed
)


# Define the Download-AppxPackage function
function Download-AppxPackage {
    [CmdletBinding()]
    param (
        [string]$Uri,
        [string]$Path = "."
    )
    process {
        $Path = (Resolve-Path $Path).Path
        # Get URLs to download
        $WebResponse = Invoke-WebRequest -UseBasicParsing -Method 'POST' -Uri 'https://store.rg-adguard.net/api/GetFiles' -Body "type=url&url=$Uri&ring=Retail" -ContentType 'application/x-www-form-urlencoded'
        $LinksMatch = $WebResponse.Links | where { $_ -like '*.appx*' -or $_ -like '*.appxbundle*' -or $_ -like '*.msix*' -or $_ -like '*.msixbundle*' } |
                      where { $_ -like '*_neutral_*' -or $_ -like "*_" + $env:PROCESSOR_ARCHITECTURE.Replace("AMD", "X").Replace("IA", "X") + "_*" } |
                      Select-String -Pattern '(?<=a href=").+(?=" r)'
        $DownloadLinks = $LinksMatch.matches.value

        function Resolve-NameConflict {
            # Accepts a path to a FILE and changes it so there are no name conflicts
            param(
                [string]$Path
            )
            $newPath = $Path
            if (Test-Path $Path) {
                $i = 0
                $item = (Get-Item $Path)
                while (Test-Path $newPath) {
                    $i += 1
                    $newPath = Join-Path $item.DirectoryName ($item.BaseName + "($i)" + $item.Extension)
                }
            }
            return $newPath
        }

        # Download URLs
        foreach ($url in $DownloadLinks) {
            $FileRequest = Invoke-WebRequest -Uri $url -UseBasicParsing
            $FileName = ($FileRequest.Headers["Content-Disposition"] | Select-String -Pattern '(?<=filename=).+').matches.value
            $FilePath = Join-Path $Path $FileName
            $FilePath = Resolve-NameConflict($FilePath)
            [System.IO.File]::WriteAllBytes($FilePath, $FileRequest.content)
            echo $FilePath
            Add-AppxPackage $FilePath
             # Delete the downloaded file after installation
             Remove-Item -Path $FilePath -Force -ErrorAction SilentlyContinue
             Write-Output "Deleted $FilePath after installation."
        }
    }
}

# Ensure the download directory exists
if (-Not (Test-Path "C:\Support\Store")) {
    Write-Host -ForegroundColor Green "Creating directory C:\Support\Store"
    New-Item -ItemType Directory -Force -Path "C:\Support\Store"
}



# Loop through each package
foreach ($Package in $Packages) {
    $PackageID = $Package.PackageID
    $TargetVersion = $Package.TargetVersion
    $StoreUrl = $Package.StoreUrl

    # Check if the app is installed
    $AppPackage = Get-AppxPackage | Where-Object { $_.PackageFullName -like "*$PackageID*" }

    if ($AppPackage) {
        # If installed, get the current version
        $InstalledVersion = $AppPackage.Version
        Write-Output "App Found: $PackageID"
        Write-Output "Installed Version: $InstalledVersion"

        # Compare installed version with the target version
        if ([version]$InstalledVersion -lt [version]$TargetVersion) {
            Write-Output "Update Required: Installed Version ($InstalledVersion) < Target Version ($TargetVersion)"
            Write-Output "Downloading and updating $PackageID..."
            Download-AppxPackage -Uri $StoreUrl -Path "C:\Support\Store"
        } else {
            Write-Output "The app $PackageID is up-to-date: Version $InstalledVersion"
        }
    } else {
        # If the app is not installed, download and install it
        Write-Output "App with Package ID '$PackageID' is not installed. Installing..."
        Download-AppxPackage -Uri $StoreUrl -Path "C:\Support\Store"
    }
}
