param(
  [string]$LogDir = (Join-Path $env:TEMP "rime.weasel")
)

$ErrorActionPreference = "Stop"

$rows = rg "moqi_latency:" "$LogDir" -g "*.WARNING.*.log" | ForEach-Object {
  if ($_ -match 'moqi_latency: profile=(\S+) phase=(\S+) seq=(\d+) ms=([0-9.]+)(?: core_ms=([0-9.]+) lua_ms=([0-9.]+))? input_before=(.*?) input_now=(.*?) keycode=(\S+)(?: candidates_seen=(\d+)| text_len=(\d+))?') {
    [pscustomobject]@{
      Profile=$matches[1]
      Phase=$matches[2]
      Seq=[int]$matches[3]
      Ms=[double]$matches[4]
      CoreMs=if ($matches[5]) { [double]$matches[5] } else { $null }
      LuaMs=if ($matches[6]) { [double]$matches[6] } else { $null }
      InputBefore=$matches[7]
      InputNow=$matches[8]
      Keycode=$matches[9]
      CandidatesSeen=if ($matches[10]) { [int]$matches[10] } else { $null }
      TextLen=if ($matches[11]) { [int]$matches[11] } else { $null }
    }
  }
}

function New-Stats($Items, $Field) {
  $vals = @($Items | ForEach-Object { $_.$Field } | Where-Object { $null -ne $_ } | Sort-Object)
  $n = $vals.Count
  if ($n -eq 0) { return $null }
  [pscustomobject]@{
    Count=$n
    Avg=[Math]::Round(($Items | Measure-Object $Field -Average).Average, 2)
    P50=$vals[[Math]::Min($n - 1, [int][Math]::Floor($n * 0.50))]
    P90=$vals[[Math]::Min($n - 1, [int][Math]::Floor($n * 0.90))]
    P95=$vals[[Math]::Min($n - 1, [int][Math]::Floor($n * 0.95))]
    P99=$vals[[Math]::Min($n - 1, [int][Math]::Floor($n * 0.99))]
    Max=($vals | Select-Object -Last 1)
  }
}

"TOTAL new-format latency rows: $($rows.Count)"
""
"By profile and phase:"
$rows | Group-Object Profile, Phase | ForEach-Object {
  $profile = $_.Group[0].Profile
  $phase = $_.Group[0].Phase
  $s = New-Stats $_.Group "Ms"
  [pscustomobject]@{
    Profile=$profile
    Phase=$phase
    Count=$s.Count
    AvgMs=$s.Avg
    P50=$s.P50
    P90=$s.P90
    P95=$s.P95
    P99=$s.P99
    Max=$s.Max
  }
} | Sort-Object Profile, Phase | Format-Table -AutoSize

""
"Late split by profile:"
$rows | Where-Object Phase -eq "candidates_late" | Group-Object Profile | ForEach-Object {
  $profile = $_.Name
  $core = New-Stats $_.Group "CoreMs"
  $lua = New-Stats $_.Group "LuaMs"
  $total = New-Stats $_.Group "Ms"
  [pscustomobject]@{
    Profile=$profile
    Count=$total.Count
    CoreAvg=$core.Avg
    CoreP95=$core.P95
    CoreMax=$core.Max
    LuaAvg=$lua.Avg
    LuaP95=$lua.P95
    LuaMax=$lua.Max
    TotalAvg=$total.Avg
    TotalP95=$total.P95
    TotalMax=$total.Max
  }
} | Sort-Object CoreAvg -Descending | Format-Table -AutoSize

""
"Slowest candidates_late rows:"
$rows |
  Where-Object Phase -eq "candidates_late" |
  Sort-Object Ms -Descending |
  Select-Object -First 30 Profile,Seq,Ms,CoreMs,LuaMs,InputBefore,InputNow,Keycode,CandidatesSeen |
  Format-Table -AutoSize
