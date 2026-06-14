# 安装 skill-image-auto-rename 技能

## 推荐安装路径

**Claude Code 与 OpenCode 通用**：
```text
~/.claude/skills/skill-image-auto-rename/
```

或项目级：
```text
<你的项目根目录>/.claude/skills/skill-image-auto-rename/
```

## 安装步骤

### 自动安装（PowerShell）

```powershell
$src = "E:\BaiduSyncdisk\WorkSpace\ForAgent\SKILLS-自媒体\skill-image-auto-rename"
$dst = "$env:USERPROFILE\.claude\skills\skill-image-auto-rename"

if (Test-Path $dst) {
    Remove-Item -Recurse -Force $dst
}
Copy-Item -Recurse $src $dst
Write-Host "已安装技能主目录到: $dst"

# 同时安装 Claude Code 手动调用兼容命令（从仓库内的 commands/ 目录拷贝）
$cmdSrc = Join-Path $src "commands\skill-image-auto-rename.md"
$cmdDst = "$env:USERPROFILE\.claude\commands\skill-image-auto-rename.md"
$cmdDstDir = Split-Path -Parent $cmdDst
if (-not (Test-Path $cmdDstDir)) {
    New-Item -ItemType Directory -Force -Path $cmdDstDir | Out-Null
}
Copy-Item -Force $cmdSrc $cmdDst
Write-Host "已安装 Claude Code 兼容命令到: $cmdDst"
```

### 手动安装

1. 复制 `skill-image-auto-rename/` 整个文件夹到 `~/.claude/skills/`
2. 复制 `skill-image-auto-rename/commands/skill-image-auto-rename.md` 到 `~/.claude/commands/`
3. 重启 Claude Code 或新开会话，再输入 `/`，应能看到 `skill-image-auto-rename` 补全项。

### 验证

启动 Claude Code 或 OpenCode，输入 `/`，应该看到 `skill-image-auto-rename` 补全项。

## 文件结构

```text
skill-image-auto-rename/
├─ SKILL.md                          # 入口（frontmatter + 工作流）
├─ README.md                         # 系统架构与设计说明
├─ INSTALL.md                        # 本文件
├─ .env.example                      # 凭证配置模板（不含真实值）
├─ .gitignore                        # 强制忽略 .env 与运行产物
├─ commands/                         # Claude Code 手动调用兼容层
│  └─ skill-image-auto-rename.md     # 同名 legacy command
├─ references/
│  ├─ tool-servicehub-api.md         # ServiceHub M3 接口详细用法（主选）
│  ├─ tool-mmx-cli-legacy.md         # mmx CLI 应急通道
│  ├─ md-format-spec.md              # MD 文档格式要求
│  └─ troubleshooting.md             # 故障排查
└─ scripts/
   ├─ extract-md-refs.ps1            # 解析 MD 文稿
   ├─ recognize-images-servicehub.ps1 # 调 ServiceHub M3 识别图片（主选）
   ├─ recognize-images.ps1           # 调 mmx 识别图片（应急）
   └─ apply-mapping.ps1              # 重命名 + 复制
```

## 必需配置

技能使用前需准备：
1. **ServiceHub 账号**：在 https://www.ccailab.top 注册并充值积分
2. **passtoken**：登录后从用户中心获取
3. **网络访问**：能访问 https://www.ccailab.top

## 兼容性说明

- **Claude Code**：✅ 完整支持（含 `/skill-image-auto-rename` slash command）
- **OpenCode**：✅ 支持（按需加载技能）
- **Codex**：✅ 支持（扫描 `.claude/skills/`）
- **MiniMax Code**：✅ 支持

## 卸载

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\skills\skill-image-auto-rename"
Remove-Item -Force "$env:USERPROFILE\.claude\commands\skill-image-auto-rename.md"
```

## 首次发布到 GitHub

**认证策略**：

默认应使用**非交互式认证**发布，优先读取本机凭证文档中的 GitHub PAT，并通过一次性 HTTP header 完成 `git push`。  
**不要默认触发浏览器登录、设备码登录或 Git Credential Manager 弹窗**；只有用户明确要求手动登录排障时，才允许走交互式流程。

仓库根目录就是技能目录本身。在仓库根下执行：

```bash
# 1. 初始化
git init

# 2. 首次提交（仓库内不含任何 .env / 真实 token / 真实 webhook / 真实密码）
git add -A
git commit -m "feat: add skill-image-auto-rename"

# 3. 切换默认分支
git branch -M main

# 4. 绑定远端
git remote add origin https://github.com/JasonCai2024/skill-image-auto-rename.git

# 5. 推送（推荐：非交互式 PAT）
# PowerShell 示例：从本机凭证文档读取 PAT 后，使用一次性 extraheader 推送
$pair = "<github-username>:<github-pat>"
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $b64" push -u origin main
```

如本机已经确认存在稳定可复用的 Git 凭据缓存，也可直接执行普通 `git push`；但对 AI 助理的默认策略，仍应优先选择上面的非交互式方式，避免弹出认证窗口阻塞任务。

**发布前安全检查**：

1. 仓库内不存在 `.env`、`.env.local`、`data/credentials.json`、`config.local.json`。
2. `README.md`、`SKILL.md`、`commands/`、脚本、示例命令中没有任何真实 token / 真实 webhook / 真实用户名密码组合。
3. `.env.example` 只保留变量名与占位示例，不放真实值。
4. `.gitignore` 已忽略运行日志、缓存、数据库、真实环境变量文件、运行产物 JSON/MD。

**本机 GitHub 凭证文档引用**：

本机 GitHub 发布账号 / token / 推送方式等运维信息，只允许从以下本地文档读取，**严禁**在仓库文件或 AI 输出中转抄其中的 token、密码或密钥：

```text
E:\BaiduSyncdisk\WorkSpace\Personal\外部API与服务管理\API调用信息.md
```
