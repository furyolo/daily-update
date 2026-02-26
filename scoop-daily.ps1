[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

# 版本前缀固定的软件：minor 实为 major，patch 实为 minor
$script:VersionOffset = @(
    'python','go','golang',
    'nodejs','node',
    'ruby','perl','php','lua','erlang','elixir',
    'gcc','cmake',
    'rust','zig','nim',
    'dotnet-sdk','dotnet'
)

$script:DevTools = @(
    'git','nodejs','node','python','go','rust','gcc','cmake','make',
    'ruby','perl','php','java','dotnet','deno','bun','zig','nim'
)

$script:UpgradeMaxRetries = 2
$script:UpgradeRetryDelays = @(2, 5)

$script:RE = @{
    Ansi       = '\x1b\[[0-9;]*m'
    Header     = '^\s*Name\s+Installed Version\s+Latest Version'
    Separator  = '^\s*-{2,}\s+-{2,}\s+-{2,}'
    Semver     = '^\d+(?:\.\d+){1,3}(?:[-+][0-9A-Za-z\.-]+)?$'
    Range      = '^(\d+)-(\d+)$'
    Number     = '^\d+$'
    Name       = '^[a-zA-Z0-9._-]+$'
    NetErr     = '(?i)(fatal:|unable to access|could not resolve|failed to download|timed out|connection.*(reset|refused)|network|429|503)'
    PermErr    = '(?i)(Access is denied|permission denied|EPERM|EACCES)'
}

function Invoke-ScoopCmd([string]$arguments) {
    $tmp = [System.IO.Path]::GetTempFileName()
    $cmdLine = "powershell.exe -NoProfile -Command `"$arguments`" > `"$tmp`" 2>&1"
    cmd /c $cmdLine
    $code = $LASTEXITCODE
    $lines = @(Get-Content $tmp -Encoding UTF8)
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    return @{ ExitCode=$code; Lines=$lines }
}

function Test-ScoopAvailable {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "`n  未检测到 scoop，请先安装并加入 PATH。" -ForegroundColor Red
        return $false
    }
    return $true
}

function Invoke-ScoopUpdate {
    Write-Host "`n  正在执行 scoop update ..." -ForegroundColor Cyan
    $r = Invoke-ScoopCmd "scoop update"
    $code = $r.ExitCode
    $text = ($r.Lines) -join "`n"
    if ($code -eq 0) { return @{ OK=$true; Err=$null; ExitCode=0; Message=$null } }
    $et = 'Unknown'
    if ($text -match $script:RE.NetErr)  { $et = 'Network' }
    elseif ($text -match $script:RE.PermErr) { $et = 'Permission' }
    $last = ($r.Lines | Select-Object -Last 1)
    return @{ OK=$false; Err=$et; ExitCode=$code; Message=$last }
}

function Get-ScoopStatus {
    Write-Host "  正在获取 scoop status ..." -ForegroundColor Cyan
    $r = Invoke-ScoopCmd "scoop status"
    $code = $r.ExitCode
    $clean = @()
    foreach ($line in $r.Lines) {
        $s = ($line -replace $script:RE.Ansi, '').TrimEnd()
        if ($s -ne '') { $clean += $s }
    }
    $apps = @()
    $colStarts = @()
    $pastHeader = $false
    foreach ($line in $clean) {
        if ($line -match $script:RE.Header) { $pastHeader = $false; continue }
        if ($line -match $script:RE.Separator) {
            $colStarts = @()
            $inDash = $false
            for ($ci = 0; $ci -lt $line.Length; $ci++) {
                if ($line[$ci] -eq '-' -and -not $inDash) {
                    $colStarts += $ci
                    $inDash = $true
                } elseif ($line[$ci] -ne '-') {
                    $inDash = $false
                }
            }
            $pastHeader = $true
            continue
        }
        if (-not $pastHeader) { continue }
        if ($colStarts.Count -lt 3) { continue }
        if ($line.Length -le $colStarts[2]) { continue }
        $name = $line.Substring($colStarts[0], $colStarts[1] - $colStarts[0]).Trim()
        $cur  = $line.Substring($colStarts[1], $colStarts[2] - $colStarts[1]).Trim()
        $latEnd = if ($colStarts.Count -ge 4 -and $line.Length -ge $colStarts[3]) { $colStarts[3] } else { $line.Length }
        $lat  = $line.Substring($colStarts[2], $latEnd - $colStarts[2]).Trim()
        if ($name -and $cur -and $lat) {
            $apps += [PSCustomObject]@{ Name=$name; Current=$cur; Latest=$lat }
        }
    }
    return @{ ExitCode=$code; Apps=@($apps) }
}

function Get-ChangeType([string]$name, [string]$from, [string]$to) {
    if ($from -notmatch $script:RE.Semver -or $to -notmatch $script:RE.Semver) { return 'Unknown' }
    $f = ($from -split '[-+]')[0] -split '\.'
    $t = ($to   -split '[-+]')[0] -split '\.'
    $offset = if ($script:VersionOffset -contains $name.ToLower()) { -1 } else { 0 }
    $max = [Math]::Max($f.Count, $t.Count)
    for ($i = 0; $i -lt $max; $i++) {
        $fv = 0; $tv = 0
        if ($i -lt $f.Count) { if (-not [int]::TryParse($f[$i], [ref]$fv)) { return 'Unknown' } }
        if ($i -lt $t.Count) { if (-not [int]::TryParse($t[$i], [ref]$tv)) { return 'Unknown' } }
        if ($fv -ne $tv) {
            $level = $i + $offset
            if ($level -eq 0) { return 'Major' }
            if ($level -eq 1) { return 'Minor' }
            return 'Patch'
        }
    }
    return 'Unknown'
}

function Show-UpdateList([array]$apps) {
    $map = @{ Patch = @('🔴','补丁','Red'); Minor = @('🟡','次版本','Yellow'); Major = @('🟢','主版本','Green') }
    $list = @()
    Write-Host ""
    for ($i = 0; $i -lt $apps.Count; $i++) {
        $a = $apps[$i]
        $ct = Get-ChangeType $a.Name $a.Current $a.Latest
        $m = if ($map.ContainsKey($ct)) { $map[$ct] } else { @('⚪','未知','Gray') }
        $item = [PSCustomObject]@{
            Idx=($i+1); Name=$a.Name; Current=$a.Current; Latest=$a.Latest
            Type=$ct; Emoji=$m[0]; Label=$m[1]; Color=$m[2]
        }
        $list += $item
        Write-Host ("  [{0}] {1} ({2} -> {3}) {4} {5}" -f $item.Idx,$item.Name,$item.Current,$item.Latest,$item.Emoji,$item.Label) -ForegroundColor $item.Color
    }
    Write-Host ""
    return $list
}

function Read-UserSelection([array]$list) {
    while ($true) {
        $raw = Read-Host "  请选择要更新的软件（编号/名称/all/high/dev/cancel）"
        $input_ = if ($raw) { $raw.Trim() } else { '' }
        if ($input_ -eq '') { Write-Host "  请输入有效选择。" -ForegroundColor Yellow; continue }
        $low = $input_.ToLower()

        if ($low -in @('cancel','q','quit','exit','n','no')) { return $null }
        if ($low -eq 'all')    { return $list }
        if ($low -eq 'high')   { return @($list | Where-Object { $_.Type -eq 'Patch' }) }
        if ($low -eq 'dev')    { return @($list | Where-Object { $script:DevTools -contains $_.Name.ToLower() }) }

        $tokens = $input_ -split '[,\s]+' | Where-Object { $_ }
        $sel = @(); $bad = @()
        foreach ($t in $tokens) {
            if ($t -match $script:RE.Range) {
                $a = [int]$Matches[1]; $b = [int]$Matches[2]
                if ($a -gt $b) { $tmp=$a; $a=$b; $b=$tmp }
                for ($n=$a; $n -le $b; $n++) {
                    $hit = $list | Where-Object { $_.Idx -eq $n }
                    if ($hit) { $sel += $hit } else { $bad += "$n" }
                }
            } elseif ($t -match $script:RE.Number) {
                $hit = $list | Where-Object { $_.Idx -eq [int]$t }
                if ($hit) { $sel += $hit } else { $bad += $t }
            } elseif ($t -match $script:RE.Name) {
                $hit = $list | Where-Object { $_.Name -ieq $t } | Select-Object -First 1
                if ($hit) { $sel += $hit } else { $bad += $t }
            } else {
                $bad += $t
            }
        }
        if ($bad.Count -gt 0) { Write-Host ("  无效项：{0}" -f ($bad -join ', ')) -ForegroundColor Yellow; continue }
        $sel = @($sel | Sort-Object Name -Unique)
        if ($sel.Count -eq 0) { Write-Host "  未匹配到任何可更新项。" -ForegroundColor Yellow; continue }
        return $sel
    }
}

function Invoke-ScoopUpgrade([array]$sel) {
    $okFirst = 0
    $okRetry = 0
    $fail = 0
    $maxAttempts = $script:UpgradeMaxRetries + 1

    foreach ($app in $sel) {
        Write-Host ("  更新 {0} ..." -f $app.Name) -ForegroundColor Cyan
        $attempt = 1
        while ($attempt -le $maxAttempts) {
            $r = Invoke-ScoopCmd "scoop update $($app.Name)"
            $exitCode = $r.ExitCode

            if ($exitCode -eq 0) {
                Write-Host ("  ✅ {0}" -f $app.Name) -ForegroundColor Green
                if ($attempt -eq 1) { $okFirst++ } else { $okRetry++ }
                break
            }

            $text = ($r.Lines) -join "`n"
            $last = ($r.Lines | Select-Object -Last 1)
            if (-not $last) { $last = "退出码: $exitCode" }
            $isPermErr = $text -match $script:RE.PermErr

            if ($isPermErr -or $attempt -ge $maxAttempts) {
                $reason = if ($isPermErr) { "权限错误，跳过重试" } else { "共尝试 $attempt 次" }
                Write-Host ("  ❌ {0} - {1}（{2}）" -f $app.Name, $last, $reason) -ForegroundColor Red
                $fail++
                break
            }

            $delayIdx = if ($attempt - 1 -lt $script:UpgradeRetryDelays.Count) { $attempt - 1 } else { $script:UpgradeRetryDelays.Count - 1 }
            $delay = $script:UpgradeRetryDelays[$delayIdx]
            Write-Host ("  ⚠ {0} 失败，{1} 秒后重试（{2}/{3}）..." -f $app.Name, $delay, $attempt, $script:UpgradeMaxRetries) -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
            $attempt++
        }
    }
    $totalOk = $okFirst + $okRetry
    Write-Host ""
    Write-Host ("  总计：{0} 成功（{1} 重试后成功），{2} 失败" -f $totalOk, $okRetry, $fail) -ForegroundColor Cyan
}

# === Main ===
function Main {
    Write-Host "`n  === Scoop Daily ===" -ForegroundColor Cyan

    if (-not (Test-ScoopAvailable)) { return }

    $u = Invoke-ScoopUpdate
    if (-not $u.OK) {
        Write-Host ("  scoop update 失败（{0}，退出码：{1}）" -f $u.Err, $u.ExitCode) -ForegroundColor Yellow
        if ($u.Message) { Write-Host ("  详情：{0}" -f $u.Message) -ForegroundColor Yellow }
        $go = Read-Host "  是否继续检查 status？(y/n)"
        if ($go -notin @('y','yes')) { return }
    }

    $status = Get-ScoopStatus
    $apps = @($status.Apps)
    if ($status.ExitCode -ne 0 -and $apps.Count -eq 0) {
        Write-Host "`n  scoop status 执行失败，未解析出有效更新列表。" -ForegroundColor Red
        return
    }
    if ($apps.Count -eq 0) {
        Write-Host "`n  所有软件均为最新版本。" -ForegroundColor Green
        return
    }

    $list = Show-UpdateList $apps
    $sel = Read-UserSelection $list
    if ($null -eq $sel) {
        Write-Host "  已取消。" -ForegroundColor Yellow
        return
    }
    if (@($sel).Count -eq 0) {
        Write-Host "  选择结果为空，无需更新。" -ForegroundColor Yellow
        return
    }

    Invoke-ScoopUpgrade $sel
}

Main
Read-Host "`n  按回车键退出"
