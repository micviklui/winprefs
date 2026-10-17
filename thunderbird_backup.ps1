param (
    [bool]$Dryrun = $false,
    # 1. Define source and backup destination paths
    [string]$SourcePath = "$env:APPDATA\Thunderbird",
    [string]$DestinationPath = "$env:HOMEPATH\Thunderbird-Backup",
    [string]$LogPath = "$DestinationPath\Thunderbird-Backup-Log.txt"
)

function Calc-TreeSize {
  param (
    $Path
  )
  $FolderItems = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
  $TotalSizeBytes = ($FolderItems | Measure-Object -Property Length -Sum).Sum
  # Convert bytes to Gigabytes (rounded to 2 decimal places)
  $TotalSizeGB = [math]::round(($TotalSizeBytes / 1GB), 2)
  $TotalFileCount = $FolderItems.Count
  [pscustomobject]@{
    FileCount = $TotalFileCount
    SizeBytes = $TotalSizeBytes
    SizeGB = $TotalSizeGB
  }
}

$ProfilesPath = "$SourcePath\Profiles"
if (Test-Path -Path $ProfilesPath) {
  Write-Host "Profile Stats:" -ForegroundColor Cyan
  Write-Output (Get-ChildItem $SourcePath\Profiles)
  Write-Host "`n"
}
else {
  Write-Host "SourcePath Stats:" -ForegroundColor Cyan
  Write-Output (Get-Item $SourcePath)
  Write-Host "`n"
}

Write-Host ("Calculated size for {0}:" -f (Get-Item $SourcePath).FullName) -ForegroundColor Cyan
Write-Host (Calc-TreeSize -Path $SourcePath)
Write-Host "`n"

# 2. Safely close Thunderbird if it's currently running
$ProcessName = "thunderbird"
$TbProcess = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

if ($TbProcess) {
    Write-Host "Closing Thunderbird safely to prevent profile lock..." -ForegroundColor Yellow
    Stop-Process -Name $ProcessName -Force
    Start-Sleep -Seconds 3 # Give it a moment to release locks
}

# 3. Create destination folder if it doesn't exist
if (!(Test-Path -Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath | Out-Null
}

Write-Host "Starting incremental delta backup..." -ForegroundColor Cyan
Write-Host "`n"
# 4. Execute Robocopy to copy only the delta
# /MIR  : Mirrors a directory tree (copies changes, deletes from backup if deleted from source)
# /XJD  : Excludes Junction Points (prevents infinite loops)
# /R:2  : Retries failed copies twice
# /W:5  : Waits 5 seconds between retries
# /MT:16 - Multi-threaded copying (uses 16 threads for speed)
# /NP    - No Progress indicator (keeps the log file clean)
# /LOG   - Overwrites the log file (use /LOG+ if you want to append logs over time)
# /L     - only list, don't copy
$RoboOptions = @("/MIR", "/XJD", "/R:2", "/W:5", "/MT:16", "/NP", "/LOG+:$LogPath")
if ($Dryrun -eq $true) {
  Write-Host "`nDRYRUN`n" -ForegroundColor Yellow
  $Robocopy += "/L"
}
& robocopy.exe $SourcePath $DestinationPath $RoboOptions

# 5. Check Robocopy Exit Code 
# Note: Robocopy exit codes below 8 indicate success/normal changes. 8 or higher means errors.
if ($LASTEXITCODE -lt 8) {
    Write-Host "Backup completed successfully! Exit code: $LASTEXITCODE" -ForegroundColor Green
    Write-Host "Log file saved to: $LogPath" -ForegroundColor Gray
} else {
    Write-Error "Robocopy encountered errors during backup. Check the log at: $LogPath (Exit code: $LASTEXITCODE)"
}

# 5. Restart Thunderbird
#Write-Host "Re-launching Thunderbird..." -ForegroundColor Yellow
#Start-Process -FilePath "C:\Program Files\Mozilla Thunderbird\thunderbird.exe"

