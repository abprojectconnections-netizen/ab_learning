<#
  One command to run the whole app locally against the Firebase emulators.
    powershell -ExecutionPolicy Bypass -File scripts/dev-local.ps1            # run (seeds on first start)
    powershell -ExecutionPolicy Bypass -File scripts/dev-local.ps1 -Reseed    # wipe local data and seed again
    powershell -ExecutionPolicy Bypass -File scripts/dev-local.ps1 -Device edge
  Requires: Flutter, Node 22, JDK 21, firebase-tools (npm i -g firebase-tools).
#>
param(
  [switch]$Reseed,
  [string]$Device = 'chrome'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Require([string]$cmd, [string]$hint) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "'$cmd' was not found. $hint" }
}
Require 'java'     'Install JDK 21: winget install EclipseAdoptium.Temurin.21.JDK, then open a new terminal.'
Require 'node'     'Install Node 22 (fnm install 22).'
Require 'flutter'  'Install the Flutter SDK and add it to PATH.'
Require 'firebase' 'Run: npm install -g firebase-tools'

$nodeMajor = [int]((node --version).TrimStart('v').Split('.')[0])
if ($nodeMajor -ne 22) { Write-Warning "Node $nodeMajor detected; Cloud Functions target Node 22 (fnm use 22)." }

function Test-Port([int]$port) {
  try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $port); $c.Close(); return $true } catch { return $false }
}

if (-not (Test-Path 'functions/node_modules')) { npm ci --prefix functions }

$dataDir = '.emulator-data'
if ($Reseed -and (Test-Path $dataDir)) { Remove-Item $dataDir -Recurse -Force }
$firstRun = -not (Test-Path $dataDir)

if (Test-Port 9099) {
  Write-Host 'Emulators already running; reusing them.' -ForegroundColor Yellow
} else {
  $emuArgs = "emulators:start --only auth,firestore,functions,storage --project demo-ab-learning --export-on-exit $dataDir"
  if (-not $firstRun) { $emuArgs += " --import $dataDir" }
  Start-Process powershell -ArgumentList '-NoExit', '-Command', "firebase $emuArgs"
  Write-Host 'Waiting for the emulators (first start downloads them)...'
  $deadline = (Get-Date).AddMinutes(5)
  while (-not ((Test-Port 9099) -and (Test-Port 8180) -and (Test-Port 9199))) {
    if ((Get-Date) -gt $deadline) { throw 'Emulators did not start within 5 minutes. Check the emulator window.' }
    Start-Sleep -Seconds 2
  }
}

if ($firstRun) {
  $env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
  $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8180'
  $env:GCLOUD_PROJECT = 'demo-ab-learning'
  npm run seed:users --prefix functions
  npm run seed:dev --prefix functions
  npm run seed:demo --prefix functions
}

Write-Host "`nEmulator UI: http://localhost:4000   Demo password for every account: Demo#12345" -ForegroundColor Green
Write-Host 'Accounts: learner@ / instructor@ / corpadmin@ / corpmanager@ / employer@ / admin@ / superadmin@  (all @demo.test)' -ForegroundColor Green
flutter pub get
flutter run -d $Device --dart-define-from-file=env/emulator.json
