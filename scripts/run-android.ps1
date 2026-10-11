param([ValidateSet('demo', 'live')][string]$Mode = 'live')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$env:ANDROID_HOME = Join-Path (Get-Location) '.tools/android-sdk'
$env:ANDROID_AVD_HOME = Join-Path (Get-Location) '.tools/android-avd'
$env:JAVA_HOME = Join-Path (Get-Location) '.tools/java/jdk-21.0.12.1+1'
$env:PUB_CACHE = Join-Path (Get-Location) '.tools/pub-cache'
$env:GRADLE_USER_HOME = Join-Path (Get-Location) '.tools/gradle'
$env:PATH = "$(Join-Path (Get-Location) '.tools/flutter/bin');$env:ANDROID_HOME\platform-tools;$env:JAVA_HOME\bin;$env:PATH"
$adb = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
$emulator = Join-Path $env:ANDROID_HOME 'emulator/emulator.exe'
if (-not (Test-Path -LiteralPath $emulator)) { throw 'Android SDK/emulator is not installed in .tools/android-sdk.' }
if (-not (Test-Path -LiteralPath "$env:ANDROID_AVD_HOME/CampusHome.avd")) { throw 'The CampusHome virtual device has not been created.' }
$avdConfig = Join-Path $env:ANDROID_AVD_HOME 'CampusHome.avd/config.ini'
$avdText = [IO.File]::ReadAllText($avdConfig).Replace('hw.keyboard=no', 'hw.keyboard=yes').Replace('hw.keyboard.lid=yes', 'hw.keyboard.lid=no')
[IO.File]::WriteAllText($avdConfig, $avdText, (New-Object Text.UTF8Encoding($false)))
if ($Mode -eq 'demo') {
    foreach ($port in 9099, 8080, 5001) {
        if (-not (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)) {
            throw 'Start scripts/start-emulators.ps1 in another terminal, then run scripts/seed-demo.ps1 before demo mode.'
        }
    }
}
& $adb start-server
$devices = & $adb devices
if (-not ($devices -match 'emulator-5554\s+device')) {
    Start-Process -FilePath $emulator -ArgumentList '-avd', 'CampusHome', '-port', '5554', '-no-snapshot-load', '-gpu', 'auto' -WindowStyle Normal
}
$deadline = (Get-Date).AddMinutes(3)
do {
    Start-Sleep -Seconds 3
    try { $boot = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>$null }
    catch { $boot = $null }
} while ($boot -ne '1' -and (Get-Date) -lt $deadline)
if ($boot -ne '1') { throw 'The emulator did not finish booting. Check its window and retry.' }
& $adb -s emulator-5554 shell settings put secure stylus_handwriting_enabled 0
& $adb -s emulator-5554 shell settings put secure show_ime_with_hard_keyboard 1
if ($Mode -eq 'demo') {
    Write-Host 'Demo mode requires scripts/start-emulators.ps1 and scripts/seed-demo.ps1.'
    & "$PSScriptRoot/run-demo.ps1" -Device emulator-5554
} else {
    & "$PSScriptRoot/run-live.ps1" -Device emulator-5554
}
