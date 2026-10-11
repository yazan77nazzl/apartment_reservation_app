param([string]$Device = 'chrome')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$flutterBin=Join-Path (Get-Location) '.tools/flutter/bin'
if (Test-Path -LiteralPath $flutterBin) { $env:PATH="$flutterBin;$env:PATH"; $env:PUB_CACHE=Join-Path (Get-Location) '.tools/pub-cache' }
flutter run -d $Device --dart-define=BACKEND_MODE=spark --dart-define=IMAGE_STORAGE=demo --web-port=7358
