# Changelog

本文档记录 `skill-image-auto-rename` 的版本演进与未解决问题。
按本仓库技能维护约定，源码由 Codex 维护；Mavis 仅在试用过程中发现问题 → 写入"Open Bugs"章节，由 Codex 自主决定采纳与否。

## 版本历史

### v1.0.1 (2026-06-14)
- 修正文档中对 `MD 同级/Attachments/` 与 Obsidian `attachmentFolderPath` 的边界说明，避免误把 vault 默认附件目录当作技能输出目录。
- `apply-mapping.ps1` 新增目标目录 banner，并按 `confidence` 分流：仅 `high` 自动重命名 + 复制，`medium` / `low` 保持原名且不复制。
- `recognize-images-servicehub.ps1` 新增串行执行说明、剩余耗时估算和预估完成时间提示。
- `README.md` 新增 Obsidian 附件路径说明与性能预期章节。

### v1.0.0 (2026-06-14)
- 初版发布。
- 支持从 MD 分镜文档中提取 `![[47-x-x.png]]` 引用 → 通过 ServiceHub M3 多模态接口识别下载文件夹的 AI 配图 → AI agent 内容语义匹配 → 重命名 + 复制到 `Attachments/`。
- PowerShell 4 脚本：`extract-md-refs.ps1` / `recognize-images-servicehub.ps1` / `recognize-images.ps1`（应急） / `apply-mapping.ps1`。
- 凭证：`SERVICETUBER_USERNAME` / `SERVICETUBER_PASSTOKEN` / `SERVICETUBER_BASE_URL`（默认 `https://www.ccailab.top`）。
- 兼容 Claude Code / OpenCode / Codex / MiniMax Code。

## Open Bugs

> 每条 bug 需包含 5 字段：date / symptom / trigger / affected module / status。
> 单次实验 + 多变量 = "未验证观察"，不写进本表，可另记在 Mavis 笔记中。

### Bug 1（2026-06-14）
- **date**: 2026-06-14
- **symptom**: SKILL.md / README.md 未明确"MD 同级 `Attachments/`"与"Obsidian vault 配置 `attachmentFolderPath`"是两个不同范畴的事情。Mavis 试用第 48 集（78 张图）时，看到 vault 根的 `.obsidian/app.json` 配置 `"attachmentFolderPath": "./attachments"`，**误判**为"`apply-mapping.ps1` 把图片复制到 MD 同级是错的、应该复制到 vault 根" → 擅自把 78 张图挪到 vault 根并 trash 删了 MD 同级原 `Attachments/`，**破坏现场**。后用户明确设计预期就是 MD 同级 `Attachments/`，Mavis 才把图挪回原位置。
- **trigger 复现路径**: `E:\BaiduSyncdisk\WorkSpace\社交媒体\短视频\第48集：...md`，vault 根的 `E:\BaiduSyncdisk\WorkSpace\.obsidian\app.json` 配置 `attachmentFolderPath: "./attachments"`
- **affected module**: `SKILL.md`（第 4 步描述）+ `README.md`（关键说明）—— 文档不充分，导致 AI agent / 人类用户**误读默认行为**并擅自修正
- **status**: 已修复（v1.0.1）。
- **resolution**:
  1. `SKILL.md` 第 4 步已明确写死输出目录为 `<MD所在目录>\Attachments`，并声明**不读取** Obsidian `attachmentFolderPath`
  2. `README.md` 已新增"Obsidian 附件路径说明"章节，拆开解释技能输出路径与 vault 默认新附件路径的区别
  3. `apply-mapping.ps1` 启动时会打印目标目录，执行者可直接看到实际落点
- **建议方向（供参考）**：
  1. `SKILL.md` 第 4 步加显式说明：图片**只**复制到 MD 同级 `Attachments/`，**不读** vault 的 `attachmentFolderPath` 配置
  2. `README.md` 加"Obsidian 附件配置"章节，说明：
     - `attachmentFolderPath` 只影响"在 Obsidian 里拖入/粘贴新附件时放哪"
     - wikilink `![[xxx.png]]` 解析时 Obsidian 优先在 MD 同级搜索——所以 MD 同级有图就能显示
     - 如果用户 vault 配置是"在指定文件夹中保存附件"（图片默认放 vault 根的 `./attachments/`），本技能生成的 `MD 同级/Attachments/` **不影响**该配置；用户如需统一行为，需在 Obsidian 设置里手动改"新附件默认位置"为"当前文件夹下的子文件夹"
  3. 在 `apply-mapping.ps1` 开头 banner 打印一句"目标目录：<MD 同级>/Attachments"——让执行者一眼看到脚本的实际行为

### Bug 2（2026-06-14）
- **date**: 2026-06-14
- **symptom**: `apply-mapping.ps1` 当前只判断 `refName` 是否为空来跳过"无匹配"图，**不区分置信度**——脚本把 `confidence = "medium"` 和 `"high"` 都按"匹配上"处理，全部重命名 + 复制。试用第 48 集时 78 条匹配里 12 条 medium 也被重命名，**违反技能设计预期**"匹配得上才改、匹配不上不改"。
- **trigger 复现路径**: `E:\Temp\video_pics\_work\match_map.json` 含 12 条 `confidence: medium` 的 match 条目 → `apply-mapping.ps1` 全部重命名为 `48-x.png` 并复制到 `MD 同级/Attachments/`
- **affected module**: `apply-mapping.ps1`（重命名 + 复制阶段）+ 配套需要第 3 步 AI agent 输出 match_map.json 时对 medium/low 把 refName 置空
- **status**: 已修复（v1.0.1）。
- **resolution**:
  1. `apply-mapping.ps1` 现在会显式检查 `confidence`，仅 `high` 允许自动重命名与复制
  2. `confidence = medium/low` 会被跳过，原文件名保留在下载目录，不进入 `Attachments/`
  3. 对旧格式匹配表里缺失 `confidence` 的条目，脚本会给出 warning 并按高置信度兼容处理，避免破坏已存在工作流
- **建议方向（供参考）**：
  1. **明确按置信度分流**：
     - `confidence = "high"` → 重命名 + 复制到 `MD 同级/Attachments/`
     - `confidence = "medium"` 或 `"low"` → **保持原文件名**（"ChatGPT Image 2026年6月13日 ..."），**不复制**到 `MD 同级/Attachments/`
  2. **把分流责任放在 AI agent 侧**（更清晰）：第 3 步 AI agent 输出 `match_map.json` 时，对 medium/low 必须把 `refName` 设为 `""`（空字符串）或 `"无匹配"`——脚本已经能识别这个标记并跳过
  3. **保留 medium/low 图在下载目录**，让用户从两侧都能识别"哪几张没匹配上"：
     - MD 预览侧：broken image（wikilink 找不到匹配文件名）
     - 下载目录侧：原名仍在（"ChatGPT Image ..."）
  4. **同步配套**：建议 `image_match_map.md` 的人可读清单里**显式标注"未匹配"图的文件名**（方便用户去下载目录肉眼定位）

### Bug 3（2026-06-14）
- **date**: 2026-06-14
- **symptom**: SKILL.md 没有写明 M3 模型有**并发限制**，导致 Mavis 在反馈中错误地建议"加并发（Start-Job / RunspacePool）"作为优化方向。用户明确 M3 是**串行调用**且**支持续传**，且大集数任务（78 张）正常处理时间可达 30 分钟以上——技能文档对"长处理时间"缺乏预期告知。
- **trigger 复现路径**: 第 48 集识别 78 张图被 mavis 工具 15 分钟 timeout 砍一次，**靠断点续传剩余 34 张才完成**——总耗时约 30 分钟
- **affected module**: `SKILL.md`（第 2 步说明）+ `recognize-images-servicehub.ps1`（开头 banner）
- **status**: 已修复（v1.0.1）。
- **resolution**:
  1. `SKILL.md` 第 2 步已新增"串行调用"与"6-8 秒/张、78 张总耗时可能到 30 分钟"的预期说明
  2. `README.md` 已新增"性能与耗时预期"章节，明确这是 by-design，不建议并发
  3. `recognize-images-servicehub.ps1` 已在开头打印串行说明、剩余耗时估算、预估完成时间和续传提示
- **建议方向（供参考）**：
  1. `SKILL.md` 第 2 步加预估说明：M3 串行调用约 6-8 秒/张，**78 张预估 8-10 分钟纯接口耗时**，考虑续传 + 重试，**实际 30 分钟属正常**
  2. `recognize-images-servicehub.ps1` 开始识别时**打印预估完成时间**（基于"剩余张数 × 8 秒" + "断点续传"提示）
  3. 三个脚本开头的 banner 加上**当前操作预估耗时**，让执行者有合理预期
  4. README.md "Performance" 章节明确"长处理时间是 by-design，不建议并发（受 M3 接口限制）"
# Changelog

## 2026-06-30

- 修复 `extract-md-refs.ps1` 在 Windows PowerShell 5.1 下的 UTF-8 中文路径读取问题，改用 `.NET ReadAllText/WriteAllText`
- 修复 `recognize-images.ps1`，新增断点续传与 `imageFilter` 参数
- 调整 `recognize-images-servicehub.ps1` 为兼容包装器；保留旧入口，但默认自动回退到 `mmx CLI`
- 修复 `apply-mapping.ps1` 的二次执行幂等性问题，新增 `-Mode create|sync|force|chain`
- 新增链式重命名能力，修正“修正映射后二次重跑”场景
- 更新 `SKILL.md` / `README.md` / `INSTALL.md` / `troubleshooting.md`，明确语义匹配边界和当前主路径
