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
# 复制到全局 .claude/skills/
$src = "E:\BaiduSyncdisk\WorkSpace\ForAgent\SKILLS-自媒体\skill-image-auto-rename"
$dst = "$env:USERPROFILE\.claude\skills\skill-image-auto-rename"

if (Test-Path $dst) {
    Remove-Item -Recurse -Force $dst
}
Copy-Item -Recurse $src $dst
Write-Host "已安装到: $dst"

# 同时生成 Claude Code 兼容命令
$cmdDst = "$env:USERPROFILE\.claude\commands\skill-image-auto-rename.md"
$cmdSrc = "$src\..\skill-image-auto-rename\..\..\..\..\Users\pc\.claude\commands\skill-image-auto-rename.md"
# （兼容命令已经生成在 $env:USERPROFILE\.claude\commands\skill-image-auto-rename.md）
```

### 手动安装

1. 复制 `skill-image-auto-rename/` 整个文件夹到 `~/.claude/skills/`
2. 复制 `skill-image-auto-rename/commands/skill-image-auto-rename.md` 到 `~/.claude/commands/`

### 验证

启动 Claude Code 或 OpenCode，输入 `/`，应该看到 `skill-image-auto-rename` 补全项。

## 文件结构

```text
skill-image-auto-rename/
├─ SKILL.md                          # 入口（frontmatter + 工作流）
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
