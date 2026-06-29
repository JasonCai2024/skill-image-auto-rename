---
description: 将下载目录中的 AI 配图做结构化识别和语义匹配，自动重命名并复制到 MD 同级 Attachments。当前主路径为 mmx CLI。
argument-hint: [MD文档路径]
---

# skill-image-auto-rename

本文件是手动调用兼容层，完整逻辑以 `SKILL.md` 为准。

## 执行入口

1. 读取 `$ARGUMENTS` 中的 MD 路径
2. 读取 `SKILL.md`
3. 按以下顺序执行：
   - `scripts/extract-md-refs.ps1`
   - `scripts/recognize-images.ps1`
   - AI agent 自己做语义匹配，生成 `match_map.json`
   - `scripts/apply-mapping.ps1 -Mode sync`

## 注意

- `scripts/recognize-images-servicehub.ps1` 已改为兼容包装器，不再是主选识别路径
- 语义匹配必须由 AI agent 介入，不能把 `_images.json` 直接当成最终映射
- 输出目录始终是 MD 同级 `Attachments/`
