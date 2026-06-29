# 自动分镜图重命名与资产迁移技能

这个技能用于把下载目录中的 AI 配图，与 Markdown 分镜中的 `![[refName.png]]` 引用做语义匹配，然后完成重命名和复制归档。

## 当前状态

- `mmx CLI` 是主选识别通道。
- `ServiceHub` 旧入口仍保留，但已经改成兼容包装器，默认自动回退到 `mmx CLI`。
- `apply-mapping.ps1` 现在支持 `create/sync/force/chain` 四种模式。
- 所有 PowerShell 脚本都要求以 `UTF-8 with BOM` 保存，避免 Windows PowerShell 5.1 中文乱码。

## 为什么调整

2026-06-30 实测结果：
- `https://www.ccailab.top/api/llm/paid-rotation`
- 纯文本 `user_prompt` 返回 `200`
- 历史多模态数组 + base64 图片请求返回 `422`

因此，旧版“直接走 ServiceHub M3 多模态识别”的主路径已经不可靠。当前仓库把 `mmx CLI` 明确设为主通道，并把旧入口保留为兼容包装器，避免依赖方因命令名变化而直接报错。

## 核心流程

1. `scripts/extract-md-refs.ps1`
   读取 MD，输出 `_refs.json`
2. `scripts/recognize-images.ps1`
   识别图片，输出 `_images.json`
3. AI agent 自己做语义匹配
   读取两份 JSON，生成 `match_map.json`
4. `scripts/apply-mapping.ps1`
   重命名下载目录里的图片，并复制到 MD 同级 `Attachments/`

## 语义匹配边界

脚本只负责：
- 提取分镜引用
- 识别图片内容
- 应用最终映射

脚本不负责：
- 自动决定哪张图对应哪个 `refName`

也就是说，`_images.json` 不是最终结果，中间一定需要 LLM/agent 根据 `description` 和分镜 `prompt` 做语义匹配。

## `apply-mapping.ps1` 模式

- `create`
  只创建新文件，不覆盖现存目标
- `sync`
  默认模式；若 `Attachments` 中已有同名文件但内容不同，则覆盖
- `force`
  强制覆盖下载目录和 `Attachments` 中的冲突文件
- `chain`
  用于“修正映射后二次重跑”；脚本统一走临时名，两阶段重命名，自动解决链式冲突

## 兼容性

- Windows PowerShell 5.1：支持
- PowerShell 7+：支持
- Claude Code / OpenCode / Codex：支持

## 相关文件

- [SKILL.md](./SKILL.md)
- [INSTALL.md](./INSTALL.md)
- [references/tool-servicehub-api.md](./references/tool-servicehub-api.md)
- [references/troubleshooting.md](./references/troubleshooting.md)
