param(
  [ValidateSet("baseline", "no-octagram", "no-user-translators", "no-super-jian", "core-minimal")]
  [string]$Profile = "baseline"
)

$ErrorActionPreference = "Stop"
$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$custom = Join-Path $repo "moqi_wan_flypymo.custom.yaml"
$backup = Join-Path $repo "moqi_wan_flypymo.custom.yaml.ab-backup"
$patchDir = Join-Path $PSScriptRoot "patches"

if ($Profile -eq "baseline") {
  if (Test-Path -LiteralPath $custom) {
    if (-not (Test-Path -LiteralPath $backup)) {
      Copy-Item -LiteralPath $custom -Destination $backup
    }
    Remove-Item -LiteralPath $custom
  }
  Write-Host "Applied Rime A/B profile: baseline"
  Write-Host "Next: redeploy Rime, then type normally for a few minutes."
  exit 0
}

$source = Join-Path $patchDir "$Profile.custom.yaml"
if (-not (Test-Path -LiteralPath $source)) {
  throw "Missing patch file: $source"
}

if ((Test-Path -LiteralPath $custom) -and -not (Test-Path -LiteralPath $backup)) {
  Copy-Item -LiteralPath $custom -Destination $backup
}

Copy-Item -LiteralPath $source -Destination $custom -Force
Write-Host "Applied Rime A/B profile: $Profile"
Write-Host "Wrote: $custom"
Write-Host "Next: redeploy Rime, then type normally for a few minutes."
