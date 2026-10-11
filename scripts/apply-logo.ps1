$ErrorActionPreference='Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path -LiteralPath 'assets/images/logo.png')) { throw 'Save the provided logo as assets/images/logo.png first.' }
$flutterBin=Join-Path (Get-Location) '.tools/flutter/bin'
if (Test-Path -LiteralPath $flutterBin) { $env:PATH="$flutterBin;$env:PATH"; $env:PUB_CACHE=Join-Path (Get-Location) '.tools/pub-cache' }
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { throw 'App icon generation failed.' }
