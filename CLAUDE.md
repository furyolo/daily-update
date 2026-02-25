# daily-update

Windows 11 下的日常包管理更新工具集。双击 `daily-update.cmd` 并行启动 scoop 和 pnpm 全局更新。

## 文件结构

- `daily-update.cmd` — 入口，并行启动两个 PowerShell 窗口
- `scoop-daily.ps1` — 交互式 scoop 更新（版本分级 + 选择更新）
- `pnpm-daily.ps1` — 自动 pnpm 全局包更新

## 注意事项

- `.ps1` 文件必须保存为 **UTF-8 with BOM** 编码。PowerShell 5.1 默认用系统编码（GBK/CP936）读取无 BOM 文件，中文字符会导致解析错误闪退。
- `.ps1` 中禁止使用 `exit` 语句（会直接关闭窗口），主流程包在 `Main` 函数中用 `return` 提前退出，脚本末尾统一 `Read-Host` 保持窗口。
- PowerShell 5.1 兼容：不使用 `??`、`??=`、三元 `?:` 等 7+ 语法。
- scoop 内部用 `[Console]::WriteLine` 输出表格，绕过 PowerShell 所有输出流。捕获其输出必须通过 `cmd /c "powershell ... > file 2>&1"` 做 OS 级管道重定向，不能用 `*>&1` 或 `Start-Process -RedirectStandardOutput`。
- scoop status 表格按固定列位置解析（从 separator 行推断列起止），不能用多空格分割（长包名会导致列间仅一个空格）。
