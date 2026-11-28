<#
.SYNOPSIS
  Windows PowerShell launcher for pi CLI lanes with closed stdin, timeout, and retry-on-throttle.
.EXAMPLE
  pwsh -File scripts/launch_win.ps1 -Task t96 -Provider $env:FMDB_GPT_PROVIDER -Model gpt-6-luna -PromptFile prompts/t96_unicorn_all_tables.md -OutDir scratch/t96/out -MaxAttempts 4 -TimeoutSec 1800
#>
param(
    [Parameter(Mandatory)][string]$Task,
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][string]$Model,
    [Parameter(Mandatory)][string]$PromptFile,
    [Parameter(Mandatory)][string]$OutDir,
    [string]$Thinking = "",
    [int]$MaxAttempts = 5,
    [int]$TimeoutSec = 1800
)

$ErrorActionPreference = "Continue"
Set-Location "D:\tmp2b\fm24-db"
New-Item -ItemType Directory -Force -Path $OutDir, "scratch/t02/pi-logs", "scratch/t02/pi-sessions" | Out-Null

if (-not $Thinking) {
    $Thinking = if ($Model -match "^gpt-") { "high" } else { "max" }
}

$logFile = "scratch/t02/pi-logs/$Task.log"
$attFile = "scratch/t02/pi-logs/$Task.attempt.log"
"" | Set-Content -Encoding UTF8 $logFile

$promptArg = "@$PromptFile"
$instruction = "请严格按照附件任务书执行。OUTDIR = $OutDir 。若 $OutDir 中已有中间进度则续作不要从头重写。分阶段落盘并在最后写入 DONE.md（含 DONE type=$Task）并打印交付清单与核心统计。"

function Test-LaneDone([string]$dir) {
    if (Test-Path (Join-Path $dir "DONE.md")) { return $true }
    $files = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".json", ".md" -and $_.Length -gt 800 }
    if ($files.Count -ge 2) {
        $hasStatus = $files | Select-String -Pattern '"status"\s*:\s*"(complete|partial|recovered|done|negative|blocked)' -Quiet
        $hasInProg = $files | Select-String -Pattern '"status"\s*:\s*"(in_progress|pending|skeleton)' -Quiet
        if ($hasStatus -and -not $hasInProg) { return $true }
    }
    return $false
}

for ($i = 1; $i -le $MaxAttempts; $i++) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "=== attempt $i/$MaxAttempts $ts model=$Model thinking=$Thinking ===" | Add-Content -Encoding UTF8 $logFile
    "" | Set-Content -Encoding UTF8 $attFile

    # Run pi in child process with stdin redirected from NUL so it never hangs on stdin
    $piCmd = (Get-Command pi.cmd -ErrorAction SilentlyContinue).Source
    if (-not $piCmd) { $piCmd = (Get-Command pi -ErrorAction Stop).Source }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    if ($piCmd -like "*.ps1") {
        $psi.FileName = "pwsh.exe"
        $argList = @("-NoProfile", "-File", $piCmd)
    } else {
        $psi.FileName = $piCmd
        $argList = @()
    }
    $argList += @(
        "--provider", $Provider,
        "--model", $Model,
        "--thinking", $Thinking,
        "--approve",
        "-p",
        "-n", $Task,
        "--session-dir", "scratch/t02/pi-sessions",
        "--session-id", "$Task-$Provider",
        $promptArg,
        $instruction
    )
    foreach ($a in $argList) { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = "D:\tmp2b\fm24-db"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    [void]$proc.Start()
    # Immediately close stdin (EOF) so pi never blocks waiting for piped input!
    $proc.StandardInput.Close()

    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()

    $exited = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $exited) {
        try { $proc.Kill($true) } catch {}
        $rc = 124
    } else {
        $rc = $proc.ExitCode
    }
    $stdoutText = try { $outTask.GetAwaiter().GetResult() } catch { "" }
    $stderrText = try { $errTask.GetAwaiter().GetResult() } catch { "" }
    $combined = ($stdoutText + "`n" + $stderrText).Trim()
    $combined | Set-Content -Encoding UTF8 $attFile
    $combined | Add-Content -Encoding UTF8 $logFile

    $tsEnd = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if (Test-LaneDone $OutDir) {
        "=== DONE $Task attempt=$i rc=$rc $tsEnd ===" | Add-Content -Encoding UTF8 $logFile
        Write-Output "=== DONE $Task attempt=$i rc=$rc ==="
        Get-Content $attFile -Tail 30
        exit 0
    }

    "=== attempt $i ended rc=$rc $tsEnd (not done yet) ===" | Add-Content -Encoding UTF8 $logFile
    if ($combined -match "upstream_saturated|temporarily unavailable|503|429|throttl|rate.limit|overloaded|ECONNRESET|ETIMEDOUT|fetch failed") {
        $waitSec = [Math]::Min(180, 30 * $i)
        "--- throttled/transient error, sleeping ${waitSec}s ---" | Add-Content -Encoding UTF8 $logFile
        Start-Sleep -Seconds $waitSec
    } else {
        Start-Sleep -Seconds 15
    }
}

"=== GAVE UP $Task after $MaxAttempts attempts ===" | Add-Content -Encoding UTF8 $logFile
Write-Output "=== GAVE UP $Task after $MaxAttempts attempts ==="
Get-Content $logFile -Tail 35
exit 1
