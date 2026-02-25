[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

$script:RE_Ansi = '\x1b\[[0-9;]*m'

function Test-PnpmAvailable {
    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Write-Host "`n  未检测到 pnpm，请先安装并加入 PATH。" -ForegroundColor Red
        return $false
    }
    return $true
}

function Invoke-PnpmGlobalUpdate {
    Write-Host "`n  正在执行 pnpm -g update ..." -ForegroundColor Cyan
    Write-Host ""
    $lines = & pnpm -g update 2>&1
    $code = $LASTEXITCODE
    return @{ ExitCode=$code; Lines=@($lines) }
}

function Show-Results([hashtable]$result) {
    foreach ($lineObj in $result.Lines) {
        $line = ($lineObj.ToString() -replace $script:RE_Ansi, '').TrimEnd()
        if ($line) { Write-Host "  $line" }
    }
    Write-Host ""
    if ($result.ExitCode -eq 0) {
        Write-Host "  ✅ pnpm 全局包更新完成。" -ForegroundColor Green
    } else {
        Write-Host "  ❌ pnpm 更新过程中出现错误（退出码：$($result.ExitCode)）" -ForegroundColor Red
    }
}

# === Main ===
function Main {
    Write-Host "`n  === pnpm Daily ===" -ForegroundColor Cyan

    if (-not (Test-PnpmAvailable)) { return }

    $result = Invoke-PnpmGlobalUpdate
    Show-Results $result
}

Main
Read-Host "`n  按回车键退出"
