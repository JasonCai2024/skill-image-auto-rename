---
description: 将下载文件夹中批量生成的 AI 配图通过 ServiceHub M3 多模态接口识别，与 MD 文档中的分镜提示词做内容语义匹配，自动重命名并复制到 Attachments 子文件夹。
argument-hint: [MD文档路径]
---

# skill-image-auto-rename（Claude Code 兼容命令）

> 本文件是 `~/.claude/skills/skill-image-auto-rename/` 的手动调用兼容层。
> 当 Claude Code 安装环境无法稳定把 skills 目录中的 slash command 显示在 `/` 补全列表时，复制本文件到 `~/.claude/commands/skill-image-auto-rename.md` 即可恢复手动调用。
>
> 完整的工作流与决策规则以 `SKILL.md` 为准，本文件不维护独立逻辑，避免后续漂移。

## 目标

把下载文件夹中**批量生成、文件名混乱**的 AI 配图，自动按 MD 文档里的 `![[xxx.png]]` 引用名重命名，并复制到 MD 同级的 `Attachments/` 子文件夹，让 Obsidian 等 MD 工具能正确解析图片引用。

完整流程：解析 MD 拿到分镜及对应的图片引用列表 → 调 ServiceHub M3 多模态接口拿到图片结构化视觉描述列表 → 由 AI agent 纯基于内容一致性对比两组列表生成绝对文件名匹配表 → 读匹配表重命名 + 复制到 Attachments。

## 输入

- **必填**：`$ARGUMENTS` 中提供的 MD 文档绝对路径
- **可选**：下载文件夹路径（默认 `C:\Users\pc\Downloads`）
- **可选**：ServiceHub username / passtoken（推荐从 `SERVICETUBER_USERNAME` / `SERVICETUBER_PASSTOKEN` 环境变量或 `.env` 自动装载，避免在命令行明文传入）

If no MD document path is provided in `$ARGUMENTS`, ask the user for the missing argument and stop.

## 执行入口

优先调用技能主目录下的脚本与文档：

- 主技能入口：`~/.claude/skills/skill-image-auto-rename/SKILL.md`
- 凭证装载：`~/.claude/skills/skill-image-auto-rename/.env`（仓库仅提供 `.env.example`，不要提交真实凭据）
- 脚本目录：`~/.claude/skills/skill-image-auto-rename/scripts/`
- 参考资料：`~/.claude/skills/skill-image-auto-rename/references/`

## 调用步骤

1. 读取 `$ARGUMENTS` 中的 MD 文档路径；若为空，向用户询问后停止。
2. 加载 `SKILL.md`，按其 Workflow 的 4 个步骤执行：
   - 第 1 步：跑 `scripts/extract-md-refs.ps1` 解析 MD。
   - 第 2 步：跑 `scripts/recognize-images-servicehub.ps1`（主选）或 `scripts/recognize-images.ps1`（应急）批量识别下载图片。
   - 第 3 步：AI agent 自己做语义匹配，输出基于绝对文件名的 `match_map.json`。
   - 第 4 步：跑 `scripts/apply-mapping.ps1` 完成重命名与复制。
3. 关键决策规则、容错与回退见 `SKILL.md` 的 Decision Rules / Fallback 章节；ServiceHub 接口细节见 `references/tool-servicehub-api.md`；故障排查见 `references/troubleshooting.md`。
