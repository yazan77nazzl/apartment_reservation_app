param([string]$Device = 'chrome')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$flutterBin=Join-Path (Get-Location) '.tools/flutter/bin'
if (Test-Path -LiteralPath $flutterBin) { $env:PATH="$flutterBin;$env:PATH"; $env:PUB_CACHE=Join-Path (Get-Location) '.tools/pub-cache' }
$imageConfigArgs = @()
if (Test-Path -LiteralPath 'config/image-storage.json') {
    $imageConfigArgs = @('--dart-define-from-file=config/image-storage.json')
}
flutter run -d $Device --dart-define=USE_EMULATORS=false --dart-define=BACKEND_MODE=spark --dart-define=IMAGE_STORAGE=supabase @imageConfigArgs --web-port=7358
