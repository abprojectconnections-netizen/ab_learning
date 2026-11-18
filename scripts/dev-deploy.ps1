<#
  Deploys backend (rules, indexes, storage rules, functions) to the DEV project
  and optionally seeds dev data. Refuses any project ID not ending in -dev.
  Usage: powershell -ExecutionPolicy Bypass -File scripts/dev-deploy.ps1 -Project absmart-dev [-Seed] [-SkipFunctions]
#>
param(
  [Parameter(Mandatory = $true)][string]$Project,
  [switch]$Seed,
  [switch]$SkipFunctions
)
$ErrorActionPreference = 'Stop'
if ($Project -notmatch '-dev$') { throw "Refusing: '$Project' does not end with -dev." }

firebase deploy --only "firestore:rules,firestore:indexes,storage" --project $Project
if (-not $SkipFunctions) { firebase deploy --only functions --project $Project }
if ($Seed) {
  $env:GCLOUD_PROJECT = $Project
  npm run seed:dev --prefix functions
}
Write-Host "Backend deployed to $Project." -ForegroundColor Green
