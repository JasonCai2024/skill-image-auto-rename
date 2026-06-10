---
name: skill-image-auto-rename
description: 第三人称视角。将下载文件夹中批量生成的 AI 配图（如 ChatGPT/MiniMax 命名格式）通过 ServiceHub M3 多模态接口识别图片内容，与 MD 文档中的分镜提示词做纯内容语义匹配，自动按 MD 引用名（如 47-1-1.png）重命名并复制到 MD 文档的 Attachments 子文件夹。适用于短视频分镜配图、绘本分页插图等批量图片与 MD 引用一一对应的场景。使用者需具备 ServiceHub 平台的用户名和密码令牌。
disable-model-invocation: true
user-invocable: true
argument-hint: [MD文档路径]
---

# Skill Image Auto Rename

## Goal

把下载文件夹中**批量生成、文件名混乱**的 AI 配图，自动按 MD 文档里的 `![[xxx.png]]` 引用名重命名，让 Obsidian 之类的 MD 工具能正确解析图片引用。

完整流程：解析 MD 拿到分镜及对应的图片引用列表 → 调 ServiceHub M3 多模态接口拿到图片结构化视觉描述列表 → 由 AI agent 纯基于内容一致性对比两组列表生成绝对文件名匹配表 → 读匹配表重命名 + 复制到 Attachments。

## Required Inputs

加载本技能时，AI 必须向用户**逐一确认**以下信息（或通过本地环境变量/ `.env` 配置文件自动装载）：

1. **MD 文档路径**：被处理的 MD 文件绝对路径（必填）
2. **下载图片文件夹路径**：默认 `C:\Users\pc\Downloads`，可改
3. **ServiceHub 用户名**：用户在 ServiceHub 平台注册的用户名（或从环境变量 `SERVICETUBER_USERNAME` 自动载入）
4. **ServiceHub 密码令牌（passtoken）**：用于调 `/api/llm/paid-rotation` 接口（或从环境变量 `SERVICETUBER_PASSTOKEN` 自动载入）
5. **匹配方式**（AI agent 部分）：
   - 纯内容一致性匹配（默认，靠 AI 识别图片特征和分镜剧情做语义对齐）
   - 顺序匹配（仅当用户**明确确认**下载顺序完全等于分镜顺序时使用）

**禁止行为**：
- 不要假设路径是 `C:\Users\pc\Downloads`
- 不要假设 ServiceHub 凭据已有
- 不要假设图片是按分镜顺序下载的
- 不要展示积分成本预估（积分扣减由 ServiceHub 后台处理）

## Workflow

### 第 1 步：解析 MD 文档，提取分镜信息

调用 `scripts/extract-md-refs.ps1`：

```powershell
powershell -NoProfile -File "<技能目录>\scripts\extract-md-refs.ps1" -mdFilePath "<用户给的MD路径>" -outputJson "<输出JSON路径>" -sectionMarker "<可选：分镜章节标题>"
```

**新增参数**：`-sectionMarker` —— MD 文档包含多个 `prompt` 块（如封面、BGM、分镜）时，用这个参数指定**只解析哪个章节之后**的内容。例：`-sectionMarker "## 口播文案分镜设计"`。

脚本输出 JSON：
```json
{
  "mdPath": "...",
  "shotCount": 53,
  "storyboards": [
    {
      "shotIndex": 1,
      "prompt": "A relatable young man in a green hoodie sitting in front of a computer...",
      "refNames": ["47-1-1.png"]
    }
  ],
  "nonStoryboardRefs": ["cover.png"]
}
```

### 第 2 步：批量识别下载图片（ServiceHub M3）

调用 `scripts/recognize-images-servicehub.ps1`：

```powershell
powershell -NoProfile -File "<技能目录>\scripts\recognize-images-servicehub.ps1" `
    -downloadDir "<用户给的下载文件夹>" `
    -outputJson "<图片描述JSON路径>" `
    -username "<ServiceHub用户名>" `
    -passtoken "<ServiceHub密码令牌>"
```

脚本内部固定调用 ServiceHub `https://www.ccailab.top/api/llm/paid-rotation` 接口，固定 `provider=minimax`、`model=MiniMax-M3`。

脚本输出 JSON：
```json
{
  "imageCount": 54,
  "images": [
    {
      "index": 1,
      "filename": "ChatGPT Image 2026年6月8日 00_34_05.png",
      "description": "1.主体角色:1个绿衣男孩\n2.动作姿态:坐在电脑前\n3.面部表情:专注\n4.核心背景与道具:发光的屏幕\n5.色调与画风:3D动画"
    }
  ]
}
```

脚本特性：
- **结构化识别**：多模态识别图片的主体、动作、表情、背景道具、色调画风，以结构化标签方式输出。
- **增量写入**：每识别完一张图就写一次 JSON，中断后可断点续传。
- **自动重试**：单张失败重试 3 次（应对 ServiceHub 接口偶发网络/超时）。
- **断点续传**：已识别的图跳过，再次运行从中断处继续。

### 第 3 步：AI agent 自己做语义匹配（核心）

**这是整个技能的关键步骤，AI agent 必须亲自做**：

1. 读第 1 步输出的 `storyboards` 列表（每个分镜包含 `prompt` 和 `refNames`）。
2. 读第 2 步输出的 `images` 列表（包含每张图的 `filename` 和结构化 `description`）。
3. 逐个对比图片描述和分镜 prompt，建立**纯内容一致性（Semantic Content Consistency）**匹配关系。
   * **特征比对原则**：比对图片结构化描述中的“主体角色、动作姿态、面部表情、道具背景”与分镜 Prompt 中的核心要素。
   * **剧情线（Narrative Arc）对齐**：当遇到高度相似的重复角色画面（如都是绿衣男孩）时，阅读整篇 MD 口播文案，利用故事的情节递进关系（起承转合）进行辅助推导与定位。
4. **生成匹配表 JSON**（直接映射绝对文件名），保存为：

```json
{
  "matches": [
    {
      "filename": "ChatGPT Image 2026年6月8日 00_34_05.png",
      "refName": "47-1-1.png",
      "confidence": "high",
      "prompt": "男孩在绿衣帽衫下坐在电脑前...",
      "description": "1.主体角色:1个绿衣男孩 2.动作姿态:坐在电脑前 3.面部表情:焦虑"
    }
  ]
}
```

**注意**：
- **基于文件名匹配**：绝对不允许使用数组索引/虚拟编号，必须直接在映射表中指明 `filename` 与 `refName` 的映射。
- **多余图处理**：如果图比分镜对应的引用多，多余的图在匹配表中将 `refName` 设为 `""`（空字符串）或 `"无匹配"`，重命名脚本会自动跳过，保留原名不删。
- **分镜图缺失**：如果分镜有 `refName` 但没找到图匹配，提示用户漏生成该图片。
- **冲突消解（Tie-Breaker）**：如果同一张图匹配了多个分镜，或同一个引用匹配了多张图，启动侧重对比（将相关图片的表情、细节并排比较，挑选出最佳贴合的一张），其余标空。
- **上下文处理**：当图片数量很多时（如 100+），可分批进行语义匹配（例如每批 15 张），最后合并生成完整的匹配表。

### 第 4 步：应用匹配表 → 重命名 + 复制

调用 `scripts/apply-mapping.ps1`：

```powershell
powershell -NoProfile -File "<技能目录>\scripts\apply-mapping.ps1" `
    -downloadDir "<下载文件夹>" `
    -mdPath "<MD文档路径>" `
    -matchMapFile "<匹配表JSON路径>"
```

脚本工作原理：
1. 按匹配表读取 `filename` 并在下载文件夹中查找对应文件，重命名为指定的 `refName`。
2. 自动处理断点续传（如果某张图已在先前运行中成功重命名，将自动跳过并保持幂等）。
3. 自动将已命名的配图（如 `47-*.png`）复制到 MD 文档同级的 `Attachments` 文件夹中。

## Decision Rules

### 匹配表生成（AI agent 决策）

- **图片与引用 1:1 匹配**：正常映射 `filename` -> `refName`。
- **图片多于引用**：多余图的 `refName` 标记为空 `""`，保持原名。
- **图片少于引用**：警告用户哪些分镜引用未被匹配到，提示补生。
- **同张图映射到多个引用**：立刻报错，提示用户介入处理。
- **同引用映射了多张图**：保留特征匹配度或剧情走向最契合的一张，另一张标记为无匹配。
- **内容一致性第一原则**：拒绝依赖任何图片修改时间，所有决策均基于视觉特征（人物、道具、动作）和剧情逻辑推理做出。

### 路径与文件命名

- **MD 文档路径必填**，其他路径必须有用户明确输入或确认
- **图片文件名前缀**：脚本自动从 MD 引用名推断（如 `47-1-1.png` 推断为第 47 集）
- **Attachments 文件夹**：自动创建（如不存在），已存在文件跳过不覆盖

### 错误处理

- **ServiceHub 接口失败**：单张重试 3 次，仍失败则在 JSON 里记 `error` 字段，跳过该图继续
- **401 未授权**：立刻停止，提示用户检查 username / passtoken
- **402 积分不足**：立刻停止，提示用户充值
- **JSON 解析失败**：打印原始输出，提示用户手动检查
- **目标文件已存在**：跳过并警告，不覆盖

## Output Requirements

执行完成后必须输出：

1. **匹配表 JSON 路径**：用户可审阅
2. **重命名统计**：成功 / 失败 / 多余
3. **复制到 Attachments 的文件数**
4. **剩余未处理图片列表**（如有）
5. **生成的映射表 MD 路径**（人可读，便于人工核对）

**不展示**：积分消耗明细（由 ServiceHub 平台处理，不在技能侧展示）。

## Validation

执行完成后由 AI agent 做以下校验：

1. **数量校验**：成功重命名数 == MD 引用数
2. **内容校验**：抽样 3-5 张图片，对比 MD 提示词，确认内容一致性语义匹配无误
3. **路径校验**：Attachments 文件夹下文件数 == MD 引用数
4. **引用校验**：在 Obsidian 中打开 MD 文档，确认 `![[xxx.png]]` 图片能正常显示

## Fallback

### ServiceHub 接口故障

如果 `recognize-images-servicehub.ps1` 持续失败:
1. 检查网络是否能访问 `https://www.ccailab.top`
2. 检查 username / passtoken 是否正确（401 表示认证失败）
3. 检查用户积分余额（402 表示积分不足）
4. **应急**：使用 `scripts/recognize-images.ps1`（mmx CLI 版本）需要本机有 mmx CLI 配置

### 匹配失败

如果 AI agent 生成的匹配表错误率高（>20%）:
1. 改用"分批 LLM 匹配"：每 15 张图打成一个 batch 让 LLM 单独匹配，缩小候选池以防混淆
2. 对模棱两可的相似图片，启用微小差异对比（Tie-Breaker）
3. 人工合并各批结果

### 人工兜底

如果自动匹配完全跑不通:
1. 脚本只生成 `image_match_map.md`（图片描述 + 分镜 prompt 清单）
2. 用户手动编辑这份 MD，在每张图后加 `-> 47-x-x.png` 标记
3. 用 PowerShell `Get-Content image_match_map.md` 解析，构造匹配表 JSON
4. 重新跑第 4 步

## Examples

### 触发示例 1：处理单集 MD 文档

用户输入：
```
/image-auto-rename E:\BaiduSyncdisk\WorkSpace\社交媒体\短视频\第47集：\第47集：xxx.md
```

AI agent 应该：
1. 询问下载文件夹路径（默认 `C:\Users\pc\Downloads`）
2. 询问 ServiceHub username 和 passtoken
3. 跑第 1 步解析 MD
4. 跑第 2 步识别图片（ServiceHub M3）得到结构化描述
5. 读两份 JSON，进行剧情和特征一致性对比，生成基于文件名的匹配表
6. 跑第 4 步重命名 + 复制

### 触发示例 2：用户已知是顺序下载

用户输入：
```
/image-auto-rename E:\...\第46集.md --sequential
```

AI agent 跳过内容比对匹配，直接按下载时间顺序（LastWriteTime） 1:1 对应 MD 引用顺序生成匹配表。

## Related Files

- `references/tool-servicehub-api.md` — ServiceHub M3 接口详细用法
- `references/md-format-spec.md` — MD 文档格式要求
- `references/troubleshooting.md` — 常见故障排查
- `scripts/extract-md-refs.ps1` — 解析 MD 文档
- `scripts/recognize-images-servicehub.ps1` — 调 ServiceHub M3 识别图片（主选）
- `scripts/recognize-images.ps1` — 调 mmx CLI 识别图片（应急）
- `scripts/apply-mapping.ps1` — 重命名 + 复制
