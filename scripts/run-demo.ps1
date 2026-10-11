param([string]$Device = 'chrome')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$flutterBin = Join-Path $projectRoot '.tools/flutter/bin'
if (Test-Path -LiteralPath $flutterBin) { $env:PATH = "$flutterBin;$env:PATH"; $env:PUB_CACHE = Join-Path $projectRoot '.tools/pub-cache' }
if (-not (Test-Path -LiteralPath 'lib/firebase_options.dart')) { Copy-Item -LiteralPath 'config/firebase_options.stub' -Destination 'lib/firebase_options.dart' }
$emulatorHost = if ($Device -eq 'chrome') { '127.0.0.1' } else { '10.0.2.2' }
flutter run -d $Device --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=$emulatorHost --dart-define=BACKEND_MODE=functions --dart-define=IMAGE_STORAGE=demo --web-port=7357
