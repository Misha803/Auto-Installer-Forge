# Set up directories
$driveLetter = (Get-Location).Drive.Name + ":"
$autoinstallerDir = "$driveLetter\Auto-Installer-Forge"
$toolsDir = Join-Path $autoinstallerDir "Tools"
$busyboxPath = "$toolsDir\busybox.exe"
$payloadDumperPath = "$toolsDir\payload-dumper-go.exe"
$lpmake = "$toolsDir\lpmake.exe"
$lpunpack = "$toolsDir\lpunpack.exe"
$magiskboot = "$toolsDir\magiskboot.exe"

# Create directories if they don't exist
foreach ($dir in @($toolsDir, $autoinstallerDir)) {
    if (-not (Test-Path $dir -PathType Container)) {
        Write-Host "Creating directory: $dir"
        
        try {
            # Attempt to create the directory
			$null = New-Item -Path $dir -ItemType Directory -ErrorAction SilentlyContinue
        } catch {
            # Display the error message if directory creation fails
            Write-Host "Error creating directory: $dir`n$($_.Exception.Message)" 
        }
    }
}

# Define the file to download
#$autoinstallerfiles = @{
#}

# Define the additional file to download
$requiredtools = @{
    "busybox.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/busybox.exe"
    "payload-dumper-go.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/payload-dumper-go.exe"
    "magiskboot.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/magiskboot.exe"
    "lpunpack.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/lpunpack.exe"
    "lpmake.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/lpmake.exe"
    "cygwin1.dll" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/cygwin1.dll"
    "checksum.arkt" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main//bin/checksum.arkt"
}

# Modern progress bar function
function Show-Progress {
    param (
        [Parameter(Mandatory)]
        [Single]$TotalValue,
        
        [Parameter(Mandatory)]
        [Single]$CurrentValue,
        
        [Parameter(Mandatory)]
        [string]$ProgressText,
        
        [Parameter()]
        [string]$ValueSuffix,
        
        [Parameter()]
        [int]$BarSize = 40,

        [Parameter()]
        [switch]$Complete
    )
    
    $percent = $CurrentValue / $TotalValue
    $percentComplete = $percent * 100
    if ($ValueSuffix) {
        $ValueSuffix = " $ValueSuffix"
    }
    if ($psISE) {
        Write-Progress "$ProgressText $CurrentValue$ValueSuffix of $TotalValue$ValueSuffix" -id 0 -percentComplete $percentComplete            
    }
    else {
        $curBarSize = $BarSize * $percent
        $progbar = ""
        $progbar = $progbar.PadRight($curBarSize,[char]9608)
        $progbar = $progbar.PadRight($BarSize,[char]9617)
        
        if (!$Complete.IsPresent) {
            Write-Host -NoNewLine "`r$ProgressText $progbar [ $($CurrentValue.ToString("#.###").PadLeft($TotalValue.ToString("#.###").Length))$ValueSuffix / $($TotalValue.ToString("#.###"))$ValueSuffix ] $($percentComplete.ToString("##0.00").PadLeft(6)) % complete"
        }
        else {
            Write-Host -NoNewLine "`r$ProgressText $progbar [ $($TotalValue.ToString("#.###").PadLeft($TotalValue.ToString("#.###").Length))$ValueSuffix / $($TotalValue.ToString("#.###"))$ValueSuffix ] $($percentComplete.ToString("##0.00").PadLeft(6)) % complete"                    
        }                
    }   
}

# Download files with progress and size display
function Download-Files($files, $destinationDir) {
    $totalFiles = $files.Count
    $currentFile = 0

    foreach ($file in $files.Keys) {
        $currentFile++
        $destinationPath = Join-Path $destinationDir $file
        $url = $files[$file]

        try {
            $storeEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'

            $response = Invoke-WebRequest -Uri $url -Method Head
            [long]$fileSizeBytes = [int]$response.Headers['Content-Length']
            $fileSizeMB = $fileSizeBytes / 1MB

            if ($fileSizeBytes -eq $null) {
                $fileSize = "Unknown"
            } else {
                $fileSize = [math]::Round($fileSizeBytes / 1MB, 2)
            }
			
           Write-Host "" 
          #Write-Host "Downloading $file ($fileSize MB)..." 
		   Write-Host "" 

            # Start downloading the file and display progress
            $request = [System.Net.HttpWebRequest]::Create($url)
            $webResponse = $request.GetResponse()
            $responseStream = $webResponse.GetResponseStream()

            $fileStream = New-Object System.IO.FileStream($destinationPath, [System.IO.FileMode]::Create)
            $buffer = New-Object byte[] 4096
            [long]$totalBytesRead = 0
            [long]$bytesRead = 0

            $finalBarCount = 0

            do {
                $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
                $fileStream.Write($buffer, 0, $bytesRead)
                $totalBytesRead += $bytesRead
                $totalMB = $totalBytesRead / 1MB
                
                if ($fileSizeBytes -gt 0) {
                    Show-Progress -TotalValue $fileSizeMB -CurrentValue $totalMB -ProgressText "Downloading $file" -ValueSuffix "MB"
                }
                
                if ($totalBytesRead -eq $fileSizeBytes -and $bytesRead -eq 0 -and $finalBarCount -eq 0) {
                    Show-Progress -TotalValue $fileSizeMB -CurrentValue $totalMB -ProgressText "Downloading $file" -ValueSuffix "MB" -Complete
                    $finalBarCount++
                }
            } while ($bytesRead -gt 0)

            $fileStream.Close()
            $responseStream.Close()
            $webResponse.Close()
            $ErrorActionPreference = $storeEAP
            [GC]::Collect()
        }
        catch {
            $ExeptionMsg = $_.Exception.Message
            Write-Host "Download breaks with error : $ExeptionMsg"
        }
    }
}

function Get-PayloadZipPath {
    Write-Host ""
    Write-Host "Please enter the full path to an AOSP ROM ZIP file or a folder containing multiple ROM ZIPs:"
    Write-Host ""
    $inputPath = Read-Host "Path"

    # Trim and remove surrounding quotes or whitespace
    $inputPath = $inputPath.Trim('"').Trim()

    # Exit if input is empty
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        Write-Host ""
        Write-Host "No input provided. Exiting..." 
        exit
    }

    $candidateZips = @()

    if (Test-Path $inputPath -PathType Container) {
        Write-Host ""
        Write-Host "Searching for payload-containing ZIP files in the specified folder..."
        $zips = Get-ChildItem -Path $inputPath -Filter *.zip -Recurse

        foreach ($zip in $zips) {
            $result = & "$busyboxPath" unzip -l "$($zip.FullName)" 2>&1
            if ($result -split "`n" | Where-Object { $_ -match "payload\.bin" }) {
                $candidateZips += $zip.FullName
            }
        }
    }
    elseif (Test-Path $inputPath -PathType Leaf) {
        if (-not $inputPath.ToLower().EndsWith(".zip")) {
            Write-Host ""
            Write-Host "The specified file is not a .zip file. Please provide a valid ZIP archive." 
            return $null
        }

        Write-Host ""
        Write-Host "Checking the specified ZIP file for payload.bin..."
        $result = & "$busyboxPath" unzip -l "$inputPath" 2>&1
        if ($result -split "`n" | Where-Object { $_ -match "payload\.bin" }) {
            $candidateZips += $inputPath
        }
    }
    else {
        Write-Host ""
        Write-Host "The specified path is invalid. Please try again." 
        return $null
    }

    if ($candidateZips.Count -eq 0) {
        Write-Host ""
        Write-Host "No valid ZIP files containing payload.bin were found." 
        return $null
    }
    elseif ($candidateZips.Count -eq 1) {
        Write-Host ""
        Write-Host "One matching ZIP file found." 
        return $candidateZips[0]
    }
    else {
        Write-Host ""
        Write-Host "Multiple ZIP files containing payload.bin were found:"
        for ($i = 0; $i -lt $candidateZips.Count; $i++) {
            $displayIndex = $i + 1
            Write-Host "  [$displayIndex] $($candidateZips[$i])"
        }

        $valid = $false
        do {
            Write-Host ""
            $selection = Read-Host "Please enter the number corresponding to the ZIP file to use (1 - $($candidateZips.Count))"
            if ($selection -match '^\d+$') {
                $index = [int]$selection - 1
                if ($index -ge 0 -and $index -lt $candidateZips.Count) {
                    $valid = $true
                    return $candidateZips[$index]
                }
            }
            Write-Host ""
            Write-Host "Invalid selection. Please enter a valid number between 1 and $($candidateZips.Count)." 
        } while (-not $valid)
    }
}

Write-Host ""
Write-Host "Automating ROM conversion for easy Fastboot/Recovery flashing for Xiaomi Pad 5 (more devices planned)"
Write-Host ""
Write-Host "This script is Written and Made By ArKT, Telegram - '@ArKT_7', Github - 'ArKT-7'"
Write-Host ""
Write-Host ""
Write-Host "Downloading Required Tools"
Download-Files -files $requiredtools -destinationDir $toolsDir
Write-Host ""
Write-Host ""
Write-Host "Download complete." 

$payloadZipPath = Get-PayloadZipPath

if ($payloadZipPath) {
    Write-Host "`nUsing payload ZIP: $payloadZipPath"
    # Save to global variable for next processing
    $Global:SelectedPayloadZip = $payloadZipPath
} else {
    Write-Host "No valid payload zip selected. Exiting." 
    exit 1
}


$zipFileName = [System.IO.Path]::GetFileNameWithoutExtension($payloadZipPath)
$targetFolderName = "${zipFileName}_FASTBOOT_RECOVERY"
$targetFolderPath = Join-Path -Path $autoinstallerDir -ChildPath $targetFolderName

if (Test-Path $targetFolderPath) {
    $folderContents = Get-ChildItem -Path $targetFolderPath -Recurse -Force -ErrorAction SilentlyContinue
    if ($folderContents.Count -eq 0) {
        # Folder is empty, delete without prompt
        Remove-Item -Path $targetFolderPath -Recurse -Force
        Write-Host "Existing folder was empty and has been deleted." 
    }
    else {
        Write-Host ""
        Write-Host "A folder named '$targetFolderName' already exists in:" 
        Write-Host "  $targetFolderPath"
        Write-Host ""
        Write-Host "Choose an action:"
        Write-Host "  [1] Delete existing folder and continue"
        Write-Host "  [2] Backup existing folder and continue"

        do {
            $action = Read-Host "Enter your choice (1 or 2)"
            if ($action -eq "1") {
                Remove-Item -Path $targetFolderPath -Recurse -Force
                Write-Host "Existing folder deleted." 
                break
            }
            elseif ($action -eq "2") {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $backupFolderName = "BACKUP_${timestamp}_$targetFolderName"
                $backupFolderPath = Join-Path -Path $autoinstallerDir -ChildPath $backupFolderName
                Rename-Item -Path $targetFolderPath -NewName $backupFolderName
                Write-Host "Existing folder backed up as '$backupFolderName'." 
                break
            }
            else {
                Write-Host "Invalid input. Please enter 1 or 2." 
            }
        } while ($true)
    }
}

# Create the new folder fresh
New-Item -Path $targetFolderPath -ItemType Directory | Out-Null
Write-Host ""
Write-Host "Created folder: $targetFolderPath" 

# Extract only payload.bin into the target folder
Write-Host ""
Write-Host "Extracting payload.bin to folder:"
Write-Host "  $targetFolderPath"


$job = Start-Job -ScriptBlock {
    param($bbPath, $zip, $dest)
    & "$bbPath" unzip -j -o "$zip" "payload.bin" -d "$dest" | Out-Null
} -ArgumentList $busyboxPath, $payloadZipPath, $targetFolderPath

# Spinner while runs
$spinner = @('|','/','-','\')
$i = 0
while ($job.State -eq 'Running') {
    Write-Host -NoNewline ("Extracting payload.bin... " + $spinner[$i % $spinner.Length])
    Start-Sleep -Milliseconds 200
    Write-Host -NoNewline "`r"
    $i++
}

# Clear the spinner line before printing final status
Write-Host (" " * 40) -NoNewline  # overwrite spinner line with spaces
Write-Host "`r"                   # return cursor to line start

Wait-Job $job | Out-Null
Remove-Job $job

Write-Host ""

if ($job.State -eq 'Completed' -and (Test-Path (Join-Path $targetFolderPath "payload.bin"))) {
    Write-Host "Extraction completed successfully." 
} elseif ($job.State -ne 'Completed') {
    Write-Host "Extraction failed or was interrupted." 
} else {
    Write-Host "Failed to extract payload.bin from the ZIP file." 
}


$imagesFolderPath = Join-Path $targetFolderPath "images"

Write-Host ""
Write-Host "Running payload-dumper-go to extract images from payload.bin..."

if (-not (Test-Path $imagesFolderPath)) {
    New-Item -Path $imagesFolderPath -ItemType Directory | Out-Null
}

& "$payloadDumperPath" -o $imagesFolderPath (Join-Path $targetFolderPath "payload.bin")

if ($LASTEXITCODE -eq 0) {
    Write-Host "Payload dumped successfully to folder:" 
    Write-Host "  $imagesFolderPath"
} else {
    Write-Host "Payload dumping failed." 
}

$images = @("system", "vendor", "odm", "system_ext", "product")
foreach ($img in $images) {
    & "$busyboxPath" mv "$imagesFolderPath\$img.img" "$imagesFolderPath\${img}_a.img"
}

& "$busyboxPath" sha256sum `
    "$imagesFolderPath/system_a.img" `
    "$imagesFolderPath/vendor_a.img" `
    "$imagesFolderPath/odm_a.img" `
    "$imagesFolderPath/system_ext_a.img" `
    "$imagesFolderPath/product_a.img" `
    > "$imagesFolderPath/original_checksums.txt"

Write-Host "[SUCCESS] Checksums generated."

$l1 = (Get-Item "$imagesFolderPath/odm_a.img").Length
$l2 = (Get-Item "$imagesFolderPath/product_a.img").Length
$l3 = (Get-Item "$imagesFolderPath/system_a.img").Length
$l4 = (Get-Item "$imagesFolderPath/system_ext_a.img").Length
$l5 = (Get-Item "$imagesFolderPath/vendor_a.img").Length

$totalSize = $l1 + $l2 + $l3 + $l4 + $l5 + 25165824

& "$lpmake" `
  --metadata-size 65536 `
  --metadata-slots 3 `
  --device super:9126805504 `
  --super-name super `
  --group super_group_a:9126805504 `
  --group super_group_b:9126805504 `
  --partition odm_a:readonly:"$l1":super_group_a --image odm_a="$imagesFolderPath/odm_a.img" `
  --partition odm_b:readonly:0:super_group_b `
  --partition product_a:readonly:"$l2":super_group_a --image product_a="$imagesFolderPath/product_a.img" `
  --partition product_b:readonly:0:super_group_b `
  --partition system_a:readonly:"$l3":super_group_a --image system_a="$imagesFolderPath/system_a.img" `
  --partition system_b:readonly:0:super_group_b `
  --partition system_ext_a:readonly:"$l4":super_group_a --image system_ext_a="$imagesFolderPath/system_ext_a.img" `
  --partition system_ext_b:readonly:0:super_group_b `
  --partition vendor_a:readonly:"$l5":super_group_a --image vendor_a="$imagesFolderPath/vendor_a.img" `
  --partition vendor_b:readonly:0:super_group_b `
  --virtual-ab `
  --output "$imagesFolderPath/super.img"

Write-Host "Truncating super.img to final size using busybox..."

& "$busyboxPath" truncate -s "$totalSize" "$imagesFolderPath/super.img"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Truncation successful."
} else {
    Write-Host "Truncation failed."
}

$images = @("system", "vendor", "odm", "system_ext", "product")
foreach ($img in $images) {
    & "$busyboxPath" rm -f "$imagesFolderPath\${img}_a.img"
}

Write-Host "Extracting super.img to final checkusm..."

& "$lpunpack" "$imagesFolderPath/super.img" "$imagesFolderPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Extraction successful."
} else {
    Write-Host "Extraction failed."
}

& "$busyboxPath" sha256sum `
    "$imagesFolderPath/system_a.img" `
    "$imagesFolderPath/vendor_a.img" `
    "$imagesFolderPath/odm_a.img" `
    "$imagesFolderPath/system_ext_a.img" `
    "$imagesFolderPath/product_a.img" `
    > "$imagesFolderPath/new_checksums.txt"

Write-Host "[SUCCESS] Checksums generated."

$images = @("system", "vendor", "odm", "system_ext", "product")
foreach ($img in $images) {
    & "$busyboxPath" rm -f "$imagesFolderPath\${img}_a.img"
    & "$busyboxPath" rm -f "$imagesFolderPath\${img}_b.img"
}


Write-Host "Extracting super.img to final checkusm..."

& "$busyboxPath" diff "$imagesFolderPath/original_checksums.txt" "$imagesFolderPath/new_checksums.txt"

if ($LASTEXITCODE -eq 0) {
    Write-Host "cheksum faied successful."
} else {
    Write-Host "cheksum failed."
}

Write-Host ""
Write-Host "===========================================" 
Write-Host "Autoinstaller process completed successfully!" 
Write-Host "===========================================" 
Write-Host ""


#cleanup
& "$busyboxPath" rm -f "$targetFolderPath/payload.bin" "$imagesFolderPath/original_checksums.txt" "$imagesFolderPath/new_checksums.txt"
& "$busyboxPath" rm -rf "$toolsDir" 


exit