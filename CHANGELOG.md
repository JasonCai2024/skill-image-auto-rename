# Changelog

本文档记录 `skill-image-auto-rename` 的版本演进与未解决问题。
按本仓库技能维护约定，源码由 Codex 维护；Mavis 仅在试用过程中发现问题 → 写入"Open Bugs"章节，由 Codex 自主决定采纳与否。

## 版本历史

### v1.0.0 (2026-06-14)
- 初版发布。
- 支持从 MD 分镜文档中提取 `![[47-x-x.png]]` 引用 → 通过 ServiceHub M3 多模态接口识别下载文件夹的 AI 配图 → AI agent 内容语义匹配 → 重命名 + 复制到 `Attachments/`。
- PowerShell 4 脚本：`extract-md-refs.ps1` / `recognize-images-servicehub.ps1` / `recognize-images.ps1`（应急） / `apply-mapping.ps1`。
- 凭证：`SERVICETUBER_USERNAME` / `SERVICETUBER_PASSTOKEN` / `SERVICETUBER_BASE_URL`（默认 `https://www.ccailab.top`）。
- 兼容 Claude Code / OpenCode / Codex / MiniMax Code。

## Open Bugs

> 每条 bug 需包含 5 字段：date / symptom / trigger / affected module / status。
> 单次实验 + 多变量 = "未验证观察"，不写进本表，可另记在 Mavis 笔记中。

（暂无已验证的未解决问题）
