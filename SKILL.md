---
name: skill-image-auto-rename
description: 将下载文件夹中批量生成的 AI 配图做结构化识别与语义匹配，自动按 MD 引用名重命名并复制到 MD 同级 Attachments。当前主路径为 ServiceHub 的 MiniMax-M3 图片识别接口，mmx CLI 仅作应急备用。
disable-model-invocation: true
user-invocable: true
argument-hint: [MD文档路径]
---

# Skill Image Auto Rename

> 注意：本 skill 所有 `.ps1` 脚本必须以 `UTF-8 with BOM` 保存，否则在 Windows PowerShell 5.1 下中文路径和中文字符串可能乱码。

## Goal

把下载文件夹中批量生成、文件名混乱的 AI 配图，自动按 MD 文档里的 `![[xxx.png]]` 引用名重命名，并复制到 MD 同级 `Attachments/` 子文件夹。

完整流程：
1. 解析 MD，提取分镜 prompt 与目标引用名。
2. 批量识别图片，输出结构化描述 JSON。
3. 由 AI agent 自己做语义匹配，生成 `match_map.json`。
4. 应用映射，重命名下载目录中的图片，并同步到 `Attachments/`。

## Required Inputs

加载本技能时，AI 必须确认以下信息：

1. `MD 文档路径`
2. `下载图片文件夹路径`
3. `识别通道`
   - `ServiceHub MiniMax-M3`：主选，当前推荐路径
   - `mmx CLI`：仅应急备用
4. `匹配方式`
   - `语义匹配`：默认
   - `顺序匹配`：仅当用户明确确认下载顺序等于分镜顺序时可用

禁止行为：
- 不要默认下载目录是 `C:\Users\pc\Downloads`
- 不要默认图片顺序和分镜顺序一致
- 不要把图片描述 JSON 当成最终匹配结果
- 不要依赖 Obsidian 的 `attachmentFolderPath` 推翻本技能固定输出路径

## Workflow

### 第 1 步：解析 MD

调用：

```powershell
powershell -NoProfile -File "<技能目录>\scripts\extract-md-refs.ps1" `
  -mdFilePath "<MD路径>" `
  -outputJson "<_refs.json路径>" `
  -sectionMarker "<可选章节标记>"
```

输出核心结构：

```json
{
  "storyboards": [
    {
      "shotIndex": 1,
      "prompt": "镜头描述",
      "refNames": ["47-1-1.png"]
    }
  ]
}
```

### 第 2 步：识别图片

主选：

```powershell
powershell -NoProfile -File "<技能目录>\scripts\recognize-images-servicehub.ps1" `
  -downloadDir "<下载目录>" `
  -outputJson "<_images.json路径>" `
  -username "<ServiceHub用户名>" `
  -passtoken "<ServiceHub passtoken>"
```

备用：

```powershell
powershell -NoProfile -File "<技能目录>\scripts\recognize-images.ps1" `
  -downloadDir "<下载目录>" `
  -outputJson "<_images.json路径>"
```

说明：
- `recognize-images-servicehub.ps1` 现在直接调用 `https://www.ccailab.top/api/llm/paid-rotation`
- 使用 `provider=minimax`、`model=MiniMax-M3`
- 图片通过 `image_url.url = data:image/...;base64,...` 发送
- `recognize-images.ps1` 保留为应急备用路径
- 两个识别脚本都支持断点续传

### 第 3 步：AI agent 自己做语义匹配

这是核心步骤，不能省略。

脚本只会输出：
- `_refs.json`：分镜 prompt + `refNames`
- `_images.json`：图片 `filename` + 结构化 `description`

脚本不会直接生成最终映射。最终的 `match_map.json` 必须由 AI agent 读取这两份 JSON 后生成。

推荐提示模板：

```text
你将收到两份 JSON：
1. `_refs.json`：每个分镜的 prompt 与 refNames
2. `_images.json`：每张图片的 filename 与 description

任务：
1. 仅基于语义一致性做 1:1 匹配。
2. 输出 `matches` 数组，每项必须包含 `filename`、`refName`、`confidence`。
3. 若图片无匹配，`refName` 填 `""` 或 `"无匹配"`。
4. 只有非常确定时才给 `confidence = "high"`；否则给 `medium` 或 `low`。
5. 不允许用数组索引代替文件名。
6. 若同一 refName 被多张图竞争，保留最匹配的一张，其余标记为无匹配。
```

推荐输出：

```json
{
  "matches": [
    {
      "filename": "ChatGPT Image 2026年6月8日 00_34_05.png",
      "refName": "47-1-1.png",
      "confidence": "high",
      "prompt": "男孩坐在电脑前",
      "description": "主体角色: 绿衣男孩..."
    }
  ]
}
```

合法跳过标记：
- `""`
- `"无匹配"`

`"-1"` 只作为旧映射表兼容输入，文档不再推荐生成。

### 第 4 步：应用映射

调用：

```powershell
powershell -NoProfile -File "<技能目录>\scripts\apply-mapping.ps1" `
  -downloadDir "<下载目录>" `
  -mdPath "<MD路径>" `
  -matchMapFile "<match_map.json路径>" `
  -Mode sync
```

`-Mode` 说明：
- `create`：只创建不存在的目标文件；`Attachments` 已存在文件不覆盖
- `sync`：默认；`Attachments` 已存在时对比内容，不同则覆盖
- `force`：强制覆盖下载目录中冲突目标文件，并强制覆盖 `Attachments`
- `chain`：与 `sync` 类似，但显式用于“修正映射后二次重跑”的语义；脚本会统一走临时名，两阶段重命名，自动处理链式重命名

当前脚本能力：
- 支持重跑幂等
- 支持链式重命名
- 支持 `Attachments` 同步覆盖
- 低置信度条目自动跳过

## Decision Rules

- 优先使用 `ServiceHub MiniMax-M3`
- 只有在 ServiceHub 不可用且用户接受时，才切到 `mmx CLI`
- 目标输出目录固定为 `<MD所在目录>\Attachments`
- 不读取 `.obsidian/app.json`
- 内容一致性优先于时间顺序

## Output Requirements

执行完成后，AI 应输出：

1. `match_map.json` 路径
2. 重命名统计
3. 复制到 `Attachments/` 的文件数
4. 未匹配图片列表
5. 仍需人工确认的 `medium/low` 条目

## Validation

1. 抽样核对图片内容与 prompt 是否一致
2. 确认 `Attachments/` 中图片能被 MD 中的 `![[...]]` 正常引用
3. 若修正了映射后二次重跑，确认 `Attachments/` 中文件内容已同步更新

## Related Files

- `scripts/extract-md-refs.ps1`
- `scripts/recognize-images-servicehub.ps1`
- `scripts/recognize-images.ps1`
- `scripts/apply-mapping.ps1`
- `references/tool-servicehub-api.md`
- `references/troubleshooting.md`
