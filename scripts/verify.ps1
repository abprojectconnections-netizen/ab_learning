<#
  Runs every check CI runs, in order, and writes verify-report.txt.
  Usage (repo root):  powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
  Requires: Flutter, Node 22, JDK 21, firebase-tools on PATH.
#>
$ErrorActionPreference = 'Continue'
$report = Join-Path (Get-Location) 'verify-report.txt'
Set-Content $report "AB Learning verification $(Get-Date -Format s)"
$results = @()

function Step([string]$name, [scriptblock]$cmd) {
  Write-Host "`n=== $name ===" -ForegroundColor Cyan
  Add-Content $report "`n=== $name ==="
  $out = & $cmd 2>&1 | Out-String
  $code = $LASTEXITCODE
  Add-Content $report $out
  Write-Host $out
  $status = if ($code -eq 0) { 'PASS' } else { "FAIL (exit $code)" }
  $script:results += "$status  $name"
}

Step 'java -version'            { java -version }
Step 'node --version (want 22)' { node --version }
Step 'flutter pub get'          { flutter pub get }
Step 'flutter analyze'          { flutter analyze }
Step 'flutter test'             { flutter test }
Step 'functions: npm ci'        { npm ci --prefix functions }
Step 'functions: lint'          { npm run lint --prefix functions }
Step 'rules-tests: npm ci'      { npm ci --prefix rules-tests }
Step 'rules tests (emulator)'   { firebase emulators:exec --only firestore,storage --project demo-ab-learning "npm test --prefix rules-tests" }

Add-Content $report "`n=== SUMMARY ==="
$results | ForEach-Object { Add-Content $report $_; Write-Host $_ }
Write-Host "`nReport saved to $report. Paste its contents back to Claude." -ForegroundColor Green
