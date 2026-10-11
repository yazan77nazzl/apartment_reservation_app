$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not (Test-Path -LiteralPath 'lib/firebase_options.dart')) { Copy-Item -LiteralPath 'config/firebase_options.stub' -Destination 'lib/firebase_options.dart' }
$flutterBin = Join-Path $projectRoot '.tools/flutter/bin'
if (Test-Path -LiteralPath $flutterBin) { $env:PATH = "$flutterBin;$env:PATH"; $env:PUB_CACHE = Join-Path $projectRoot '.tools/pub-cache' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Flutter package installation failed.' }
