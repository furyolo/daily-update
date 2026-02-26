# daily-update

Windows 11 下的日常包管理更新工具。双击一次，同时完成 Scoop 和 pnpm 全局包更新。

## 使用

双击 `daily-update.cmd`，自动弹出两个 PowerShell 窗口并行执行：

- **Scoop Daily** — 更新 bucket → 检查可更新软件 → 版本分级展示 → 交互选择 → 逐项更新
- **pnpm Daily** — 执行 `pnpm -g update` → 展示结果

## Scoop 交互选择

```
[1] claude-code (2.1.51 -> 2.1.52) 🔴 补丁
[2] opencode (1.1.43 -> 1.2.11) 🟡 次版本
[3] python (3.13.7 -> 3.14.3) 🟢 主版本

请选择要更新的软件（编号/名称/all/high/dev/cancel）：
```

| 输入 | 效果 |
|------|------|
| `all` | 全部更新 |
| `high` | 仅补丁级（🔴） |
| `dev` | 仅开发工具 |
| `1,3` 或 `1-3` | 按编号选择 |
| `python` | 按名称选择 |
| `cancel` | 取消（别名：`q`/`quit`/`exit`/`n`/`no`） |

## 失败重试

更新失败时自动重试最多 2 次（间隔 2s → 5s），权限错误跳过重试。

## 前置条件

- Windows 11
- [Scoop](https://scoop.sh) 已安装并在 PATH 中
- [pnpm](https://pnpm.io) 已安装并在 PATH 中
