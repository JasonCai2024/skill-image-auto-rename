# 自动分镜图重命名与资产迁移技能 (Image Auto-Rename Skill)

本技能旨在为自媒体视频制作流中，自动将 Midjourney / DALL-E 生成的乱序图片，与 Markdown 文稿中的分镜提示词进行多模态语义匹配，完成自动化重命名并迁移至文档附件区（`Attachments/`），确保 Obsidian 等渲染工具能直接以 `![[refName.png]]` 的形式完美加载。

---

## 1. 核心架构与业务流程

整个技能管道（Pipeline）分为四个核心步骤，形成一个闭环，支持增量运行与断点续传：

```mermaid
graph TD
    A[MD文稿分镜解析] -->|提取分镜Prompt和引用名| B(storyboards.json)
    C[图片多模态特征识别] -->|提取图片视觉特征| D(image_descriptions.json)
    B & D -->|AI 语义匹配与剧情校对| E(match_map.json & 对照表)
    E -->|应用映射与迁移脚本| F[Attachments 归档 & MD完美渲染]
```

1. **第 1 步：Markdown 解析提取 (`scripts/extract-md-refs.ps1`)**
   * 从口播文案分镜设计章节（`## 口播文案分镜设计`）顺序解析，将分镜 Prompt 和预设的 `![[47-x.png]]` 引用文件名绑定，提取为 `storyboards.json`。
2. **第 2 步：多模态图片识别 (`scripts/recognize-images-servicehub.ps1` / `scripts/recognize-images.ps1`)**
   * 读取存放下载图的目录，调用 ServiceHub 的 MiniMax-M3 多模态模型进行批量识别。
   * 采用**结构化提示词**，提取每张图的主体角色、动作姿态、面部表情、核心背景与道具、画风与色调，形成 `image_descriptions.json`。具备增量跳过已识别图的断点续传能力。
3. **第 3 步：语义匹配与冲突消除 (AI Agent 脑内校对)**
   * AI 基于内容一致性（人物一致性、动作演进、道具与剧情走向）进行多对多校对，将 `image_descriptions.json` 的原文件名和 `storyboards.json` 中的目标引用文件名进行 1:1 配对。
   * 输出具有幂等性的映射表 `match_map.json` 及人可读的 `image_match_map.md`。
4. **第 4 步：执行映射与迁移 (`scripts/apply-mapping.ps1`)**
   * 读取 `match_map.json`，在下载目录下进行原子重命名，并将重命名后的图片一键复制到 Markdown 所在的同级 `Attachments/` 文件夹下。

---

## 2. 文件目录结构

```text
skill-image-auto-rename/
├─ SKILL.md                          # 技能入口（声明工作流规范与决策规则）
├─ INSTALL.md                        # 安装指南（全局部署与局部部署说明）
├─ README.md                         # 本文档（系统架构与设计说明）
├─ .env.example                      # 凭证配置模板（不含真实值）
├─ .gitignore                        # 强制忽略 .env 与运行产物
├─ commands/                         # Claude Code 手动调用兼容层
│  └─ skill-image-auto-rename.md     # 同名 legacy command（复制到 ~/.claude/commands/）
├─ references/                       # 核心规范与接口说明
│  ├─ md-format-spec.md              # Markdown 分镜设计排版规范
│  ├─ tool-servicehub-api.md         # ServiceHub M3 多模态接口规范（主选）
│  ├─ tool-mmx-cli-legacy.md         # mmx CLI 工具备用规范
│  └─ troubleshooting.md             # 常见故障排查手册
└─ scripts/                          # 核心执行脚本（PowerShell）
   ├─ extract-md-refs.ps1            # 解析文稿生成 storyboards.json
   ├─ recognize-images-servicehub.ps1 # 增量多模态识别脚本（推荐）
   ├─ recognize-images.ps1           # 增量多模态识别脚本（备用）
   └─ apply-mapping.ps1              # 重命名并复制文件至 Attachments/
```

---

## 3. 核心设计决策 (Design Decisions)

* **绝对文件名映射，杜绝索引漂移**：匹配结果使用 `filename` 映射 `refName`，即使匹配被中途打断、文件排序发生变更或多次重复运行，也绝对不会造成顺序错乱，完全幂等。
* **内容一致性第一，时间线仅做辅助**：视觉特征（人物、动作、道具、表情、画风）是匹配的决策依据；图片生成时间（LastWriteTime）只作为"疑似线索"提示，不作为最终决策——同款角色、相似姿态的分镜时间靠得近不代表就是它，必须用特征 + 剧情走向二次确认。
* **多图多引用冲突消解**：同一张图被多个分镜命中、或同一引用被多张图命中时，必须启用 Tie-Breaker 微小差异对比（表情、道具细节、剧情递进），并把次优候选的 `refName` 标记为空 `""`，让重命名脚本安全跳过，避免误占位。
* **无匹配容错处理**：如生成的图片数量多于分镜数量（如废弃废稿），对应 `refName` 会被标空 `""`，重命名脚本将安全跳过，防止误删用户资产。
* **幂等 + 断点续传**：脚本逐张处理，已识别的图、已重命名的图、已复制到 `Attachments/` 的文件都会自动跳过，再次运行不会重复扣费、不会覆盖、不会重复写入。

---

## 4. 获取与安装 (Get & Install)

### 克隆仓库 (Clone Repository)

仓库地址在首次发布时填入，此处仅保留占位符，避免伪造/过期的地址污染开源用户：

```bash
# 请将 <your-repo-url> 替换为该技能实际发布的 GitHub 仓库地址
git clone <your-repo-url>
```

安装配置详情，请参阅 [INSTALL.md](./INSTALL.md)。

---

## 5. 凭证安全与隔离规范 (Credential Security)

本技能完全符合 `OpenClaw 智能体技能开发规范：凭证安全与隔离方案` 规范：
* **无凭据泄露风险**：所有代码库文件（包括脚本和配置文件）均无硬编码的用户名、密码或 API 密钥。
* **本地配置文件**：敏感凭据统一存放于本地技能根目录下的 `.env` 文件中。`.gitignore` 已对 `.env` 及其本地变体进行强制拦截。
* **配置范式**：仓库中提供了一个 [`.env.example`](./.env.example) 模版。开源用户可以复制该文件为 `.env` 并填入自己的服务凭证，或者通过设置以下环境变量使技能自动读取：
  * `SERVICETUBER_USERNAME`：您的 ServiceHub 账户用户名。
  * `SERVICETUBER_PASSTOKEN`：您的 ServiceHub 账号授权令牌 (passtoken)。
  * `SERVICETUBER_BASE_URL`：ServiceHub 的接口基础 URL（默认为 `https://www.ccailab.top`）。

---

## 6. 仓库地址与本机凭证

本仓库的 GitHub 远端地址在 `git remote add origin` 时填入，**不应**由本仓库内容硬编码发布地址。

本机 GitHub 发布账号 / token / 推送方式等运维信息，只允许从以下本地文档读取，**严禁**在本 README、`SKILL.md` 或脚本中转抄其中的 token、密码或密钥：

```text
E:\BaiduSyncdisk\WorkSpace\Personal\外部API与服务管理\API调用信息.md
```

发布前请重新阅读 `INSTALL.md` 中"首次发布到 GitHub"章节，按占位符填入实际仓库地址。
