$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$firebaseBin = Join-Path $projectRoot '.tools/firebase-cli/node_modules/.bin'
if (Test-Path -LiteralPath $firebaseBin) { $env:PATH = "$firebaseBin;$env:PATH" }
$javaDir = Join-Path $projectRoot '.tools/java'
if (Test-Path -LiteralPath $javaDir) { $env:JAVA_HOME = (Get-ChildItem -LiteralPath $javaDir -Directory | Select-Object -First 1).FullName; $env:PATH = "$env:JAVA_HOME\bin;$env:PATH" }
firebase emulators:start --project demo-apartment-reservation --only auth,firestore,functions,storage
