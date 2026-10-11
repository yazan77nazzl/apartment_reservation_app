param([string]$Platforms = 'android,ios')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$flutterBin = Join-Path $projectRoot '.tools/flutter/bin'
if (Test-Path -LiteralPath $flutterBin) { $env:PATH = "$flutterBin;$env:PATH" }
$env:PUB_CACHE = Join-Path $projectRoot '.tools/pub-cache'
$env:PATH = "$(Join-Path $env:PUB_CACHE 'bin');$env:PATH"
$localFirebase = Join-Path $projectRoot '.tools/firebase-cli/node_modules/.bin'
if (Test-Path -LiteralPath $localFirebase) { $env:PATH = "$localFirebase;$env:PATH" }
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) { throw 'Install Firebase CLI: npm install -g firebase-tools' }
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) { throw 'Install Flutter or use the SDK in .tools/flutter.' }
firebase login
if ($LASTEXITCODE -ne 0) { throw 'Firebase login did not complete.' }
dart pub global activate flutterfire_cli
if ($LASTEXITCODE -ne 0) { throw 'FlutterFire CLI installation failed.' }
flutterfire configure --project=apartment-reservation-ap-d7a35 --platforms=$Platforms --out=lib/firebase_options.dart
if ($LASTEXITCODE -ne 0) { throw 'Firebase app registration did not complete.' }
flutter pub get
Write-Host 'Configured. Stay on Spark: deploy only Firestore rules/indexes, never Functions or Storage.'
Write-Host 'firebase deploy --only firestore:rules,firestore:indexes --project apartment-reservation-ap-d7a35'
