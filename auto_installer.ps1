#
# Copyright (C) 2025-26 https://github.com/ArKT-7/Auto-Installer-Forge
#
# Made For Processing ROMs containing payload.bin, converts them into a ready-to-flash super.img, and generates a fully automated installation package for Fastboot or Recovery, which can later be flashed using my custom flasher scripts.

# Set up directories
$driveLetter = (Get-Location).Drive.Name + ":"
$driveInfo = Get-PSDrive -Name $driveLetter.TrimEnd(':')
$autoinstallerDir = Join-Path $driveLetter "Auto-Installer-Forge"
$binsDir = Join-Path $autoinstallerDir "bin"
$outDir = Join-Path $autoinstallerDir "out"
$busyboxPath = Join-Path $binsDir "busybox.exe"
$payloadDumperPath = Join-Path $binsDir "payload-dump.exe"
$lpmake = Join-Path $binsDir "lpmake.exe"
$lpunpack = Join-Path $binsDir "lpunpack.exe"

function print {
    param (
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    Write-Host "$Message" -ForegroundColor $Color
}

function log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function lognl {
    param (
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "`n[$timestamp] $Message" -ForegroundColor $Color
}

function Prompt {
    param (
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color -NoNewline
    return Read-Host
}

function nl {
    param (
        [int]$n = 1
    )
    for ($i = 0; $i -lt $n; $i++) {
        Write-Host ""
    }
}

foreach ($dir in @($binsDir, $autoinstallerDir)) {
    if (-not (Test-Path $dir -PathType Container)) {
        print "`n`nCreating directory: $dir" DarkCyan
        try {
			$null = New-Item -Path $dir -ItemType Directory -ErrorAction SilentlyContinue
        } catch {
            print "`n`nError creating directory: $dir`n$($_.Exception.Message)" Red
        }
    }
}

#$autoinstallerfiles = @{
#}

$requiredtools = @{
    "busybox.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/busybox.exe"
    "payload-dump.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/payload-dumper-go.exe"
    "magiskboot.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/magiskboot.exe"
    "lpunpack.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/lpunpack.exe"
    "lpmake.exe" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/lpmake.exe"
    "cygwin1.dll" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main/bin/windows_amd64/cygwin1.dll"
    "checksum.arkt" = "https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main//bin/checksum.arkt"
}

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

function Download($files, $destinationDir) {
    foreach ($file in $files.Keys) {
        $destinationPath = Join-Path $destinationDir $file
        $url = $files[$file]
        try {
            $storeEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
            $response = Invoke-WebRequest -Uri $url -Method Head
            [long]$fileSizeBytes = [int]$response.Headers['Content-Length']
            $fileSizeMB = $fileSizeBytes / 1MB
			nl 2
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
            log "[ERROR] Download breaks with error : $ExeptionMsg" Red
        }
    }
}

function Get-PayloadZipPath {
    print "`nPlease enter the full path to an AOSP ROM ZIP file or a folder containing multiple ROM ZIPs:`n" Yellow
    $inputPath = Read-Host "Path"
    nl
    $inputPath = $inputPath.Trim('"').Trim()
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        lognl "[INFO] No input provided. Exiting...`n" DarkCyan
        exit
    }
    $candidateZips = @()
    if (Test-Path $inputPath -PathType Container) {
        lognl "[INFO] Searching for payload-containing ZIP files in the specified folder..." DarkCyan
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
            lognl "[ERROR] The specified file is not a .zip file. Please provide a valid ZIP archive." Red
            return $null
        }
        lognl "[INFO] Checking the specified ZIP file for payload.bin..." DarkCyan
        $result = & "$busyboxPath" unzip -l "$inputPath" 2>&1
        if ($result -split "`n" | Where-Object { $_ -match "payload\.bin" }) {
            $candidateZips += $inputPath
        }
    }
    else {
        lognl "[ERROR] The specified path is invalid. Please try again." Red
        return $null
    }

    if ($candidateZips.Count -eq 0) {
        lognl "[ERROR] No valid ZIP files containing payload.bin were found." Red
        return $null
    }
    elseif ($candidateZips.Count -eq 1) {
        log "[SUCCESS] Matching ZIP file found." Green
        return $candidateZips[0]
    }
    else {
        print "`n[INFO] Multiple ZIP files containing payload.bin were found:`n" DarkCyan
        for ($i = 0; $i -lt $candidateZips.Count; $i++) {
            $displayIndex = $i + 1
            print "$displayIndex) $($candidateZips[$i])"
        }
        $valid = $false
        do {
            nl
            $selection = Prompt "Please enter the number corresponding to the ZIP file to use (1 - $($candidateZips.Count)): " Yellow
            if ($selection -match '^\d+$') {
                $index = [int]$selection - 1
                if ($index -ge 0 -and $index -lt $candidateZips.Count) {
                    $valid = $true
                    return $candidateZips[$index]
                }
            }
            print "[ERROR] Invalid selection. Please enter a valid number between 1 and $($candidateZips.Count)." Red
        } while (-not $valid)
    }
}

print "`n`nAutomating ROM conversion for easy Fastboot/Recovery flashing for Xiaomi Pad 5 (more devices planned)`n"
print "This script is Written and Made By ArKT, Telegram - '@ArKT_7', Github - 'ArKT-7'"

$minRequiredBytes = 15 * 1GB
if ($driveInfo.Free -lt $minRequiredBytes) {
    print ("`n`n[ERROR] Insufficient free space on drive $driveLetter and it's Required minimum of 15 GB, Available: {0:N0} GB`n" -f ($driveInfo.Free / 1GB)) Red
    exit 1
} else {
    #print ("`n`nDrive $driveLetter has sufficient free space: {0:N0} GB`n" -f ($driveInfo.Free / 1GB)) -ForegroundColor Green
}

Download $requiredtools $binsDir
print "`n`n[SUCCESS] Required Tools Download complete.`n" Green
if (Test-Path $outDir) {
    $fileCheck = & $busyboxPath find "$outDir" -mindepth 1 -type f 2>$null
    if (-not $fileCheck) {
        & $busyboxPath rm -rf "$outDir"
        log "[INFO] Existing folder was empty and has been deleted." DarkCyan
    }
    else {
        print "`n[WARNING] Existing files found in $outDir Choose an action:`n" Yellow
        print "1) Delete all existing files from '$outDir' and start fresh"
        print "2) Move old files to a backup folder"
        print "3) Exit script`n"
        do {
            $action = Prompt "Enter your choice (1, 2 or 3): " Yellow

            if ($action -eq "1") {
                & $busyboxPath rm -rf "$outDir"
                print "`n[SUCCESS] Existing folder deleted.`n" Green
                break
            }
            elseif ($action -eq "2") {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $folderName = Split-Path -Path $outDir -Leaf
                $backupFolderName = "BACKUP_${timestamp}_$folderName"
                $parentDir = Split-Path -Path $outDir -Parent
                $backupFullPath = Join-Path $parentDir $backupFolderName
                & $busyboxPath mv "$outDir" "$backupFullPath"
                print "`n[SUCCESS] Existing folder backed up as '$backupFolderName'.`n" Green
                break
            }
            elseif ($action -eq "3") {
                lognl "[INFO] Exiting script. No changes made.`n" DarkCyan
                exit 0
            }
            else {
                print "[ERROR] Invalid selection. Please enter a valid number between (1, 2 or 3)`n" Red
            }
        } while ($true)
    }
}

$payloadZipPath = Get-PayloadZipPath
if ($payloadZipPath) {
    lognl "[INFO] Using payload ZIP: $payloadZipPath" DarkCyan
    # Save to global variable for next processing
    $Global:SelectedPayloadZip = $payloadZipPath
} else {
    lognl "[ERROR] No valid payload zip selected. Exiting.`n" Red
    exit 1
}

$zipFileName = [System.IO.Path]::GetFileNameWithoutExtension($payloadZipPath)
$targetFolderName = "${zipFileName}_FASTBOOT_RECOVERY"
$targetFolderPath = Join-Path $outDir $targetFolderName

New-Item -Path $targetFolderPath -ItemType Directory | Out-Null
$job = Start-Job -ScriptBlock {
    param($bbPath, $zip, $dest)
    & "$bbPath" unzip -j -o "$zip" "payload.bin" -d "$dest" | Out-Null
} -ArgumentList $busyboxPath, $payloadZipPath, $targetFolderPath

$spinner = @('|','/','-','\')
$i = 0
while ($job.State -eq 'Running') {
    Write-Host -NoNewline ("Extracting payload.bin... " + $spinner[$i % $spinner.Length])
    Start-Sleep -Milliseconds 200
    Write-Host -NoNewline "`r"
    $i++
}

Write-Host (" " * 40) -NoNewline
Write-Host "`r" -NoNewline
Wait-Job $job | Out-Null
Remove-Job $job

if ($job.State -eq 'Completed' -and (Test-Path (Join-Path $targetFolderPath "payload.bin"))) {
    log "[SUCCESS] Extraction completed." Green
} elseif ($job.State -ne 'Completed') {
    log "[ERROR] Extraction failed or was interrupted." Red
    exit 1
} else {
    log "[ERROR] Failed to extract payload.bin from the ZIP file." Red
    exit 1
}

$imagesFolderPath = Join-Path $targetFolderPath "images"
lognl "[INFO] Extracting images from payload.bin...`n" DarkCyan
if (-not (Test-Path $imagesFolderPath)) {
    New-Item -Path $imagesFolderPath -ItemType Directory | Out-Null
}

& "$payloadDumperPath" -o $imagesFolderPath (Join-Path $targetFolderPath "payload.bin")
if ($LASTEXITCODE -eq 0) {
    lognl "[SUCCESS] Extraction completed" Green
} else {
    lognl "[ERROR] Payload dumping failed." Red
    exit 1
}

lognl "[INFO] Generating original checksums..." DarkCyan
$images = @("system", "vendor", "odm", "system_ext", "product")
foreach ($img in $images) {
    $srcImgPath = Join-Path $imagesFolderPath "$img.img"
    $destImgPath = Join-Path $imagesFolderPath "${img}_a.img"
    & "$busyboxPath" mv "$srcImgPath" "$destImgPath"
}

& "$busyboxPath" sha256sum `
    "$imagesFolderPath/system_a.img" `
    "$imagesFolderPath/vendor_a.img" `
    "$imagesFolderPath/odm_a.img" `
    "$imagesFolderPath/system_ext_a.img" `
    "$imagesFolderPath/product_a.img" `
    > "$imagesFolderPath/original_checksums.txt"
log "[SUCCESS] Checksums generated." Green

lognl "[INFO] Calculating total partition size with buffer..." DarkCyan
$l1 = (Get-Item "$imagesFolderPath/odm_a.img").Length
$l2 = (Get-Item "$imagesFolderPath/product_a.img").Length
$l3 = (Get-Item "$imagesFolderPath/system_a.img").Length
$l4 = (Get-Item "$imagesFolderPath/system_ext_a.img").Length
$l5 = (Get-Item "$imagesFolderPath/vendor_a.img").Length
$totalSize = $l1 + $l2 + $l3 + $l4 + $l5 + 25165824
log "[INFO] Total size (with buffer): $totalSize" Green

lognl "[INFO] Creating super.img...`n" DarkCyan
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
lognl "[SUCCESS] super.img created." Green

lognl "[INFO] Truncating super.img..." DarkCyan
& "$busyboxPath" truncate -s "$totalSize" "$imagesFolderPath/super.img"
if ($LASTEXITCODE -eq 0) {
    log "[SUCCESS] Truncation successful." Green
} else {
    log "[ERROR] Truncation failed." Red
}

lognl "[INFO] Cleaning up payload.bin extrated img's..." DarkCyan
$images = @("system", "vendor", "odm", "system_ext", "product")
foreach ($img in $images) {
    & "$busyboxPath" rm -f (Join-Path $imagesFolderPath "${img}_a.img")
}
log "[SUCCESS] Cleanup complete." Green

lognl "[INFO] Extracting super.img to final checkusm..." DarkCyan
& "$lpunpack" "$imagesFolderPath/super.img" "$imagesFolderPath"
if ($LASTEXITCODE -eq 0) {
    log "[SUCCESS] Extraction successful." Green
} else {
    log "[ERROR] Extraction failed." Red
}

lognl "[INFO] Generating new checksums..." DarkCyan
& "$busyboxPath" sha256sum `
    "$imagesFolderPath/system_a.img" `
    "$imagesFolderPath/vendor_a.img" `
    "$imagesFolderPath/odm_a.img" `
    "$imagesFolderPath/system_ext_a.img" `
    "$imagesFolderPath/product_a.img" `
    > "$imagesFolderPath/new_checksums.txt"
log "[SUCCESS] Checksums generated." Green

$images = @("system", "vendor", "odm", "system_ext", "product")
foreach ($img in $images) {
    & "$busyboxPath" rm -f (Join-Path $imagesFolderPath "${img}_a.img")
    & "$busyboxPath" rm -f (Join-Path $imagesFolderPath "${img}_b.img")
}

lognl "[INFO] Comparing checksums..." DarkCyan
& "$busyboxPath" diff "$imagesFolderPath/original_checksums.txt" "$imagesFolderPath/new_checksums.txt"
if ($LASTEXITCODE -eq 0) {
    log "[SUCCESS] Checksum comparison complete." Green
} else {
    log "[ERROR] cheksum failed." Red
}

print "`n===========================================" DarkCyan
print "Autoinstaller process completed successfully!" Yellow
print "===========================================`n" DarkCyan

#cleanup
& "$busyboxPath" rm -f "$targetFolderPath/payload.bin" "$imagesFolderPath/original_checksums.txt" "$imagesFolderPath/new_checksums.txt"
Remove-Item -Path $binsDir -Recurse -Force

exit