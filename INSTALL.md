# 安装 skill-image-auto-rename

## 安装路径

推荐：

```text
~/.claude/skills/skill-image-auto-rename/
```

或项目级：

```text
<项目根目录>/.claude/skills/skill-image-auto-rename/
```

## 安装步骤

### 自动安装

```powershell
$src = "E:\BaiduSyncdisk\WorkSpace\ForAgent\SKILLS-自媒体\skill-image-auto-rename"
$dst = "$env:USERPROFILE\.claude\skills\skill-image-auto-rename"

if (Test-Path $dst) {
    Remove-Item -Recurse -Force $dst
}

Copy-Item -Recurse $src $dst

$cmdSrc = Join-Path $src "commands\skill-image-auto-rename.md"
$cmdDst = "$env:USERPROFILE\.claude\commands\skill-image-auto-rename.md"
$cmdDstDir = Split-Path -Parent $cmdDst
if (-not (Test-Path $cmdDstDir)) {
    New-Item -ItemType Directory -Force -Path $cmdDstDir | Out-Null
}
Copy-Item -Force $cmdSrc $cmdDst
```

### 手动安装

1. 复制整个 `skill-image-auto-rename/` 到 `~/.claude/skills/`
2. 复制 `commands/skill-image-auto-rename.md` 到 `~/.claude/commands/`
3. 重启 Claude Code 或新开会话

## 必需环境

主路径当前依赖 `ServiceHub`。

准备项：
1. 已有可用的 `ServiceHub` 用户名和 `passtoken`
2. 可访问 `https://www.ccailab.top`
3. 默认走 `provider=minimax` + `model=MiniMax-M3`

## 备用环境

若你希望保留应急能力，可额外准备：
1. 已安装 `mmx CLI`
2. `mmx auth status` 可通过

## ServiceHub 说明

主脚本 `scripts/recognize-images-servicehub.ps1` 现在会直接发送多模态识图请求到：

```text
https://www.ccailab.top/api/llm/paid-rotation
```

默认参数：
- `provider = minimax`
- `model = MiniMax-M3`
- 图片通过 `image_url.url = data:image/...;base64,...` 发送

`scripts/recognize-images.ps1` 不再是主路径，只作为备用。

## PowerShell 5.1 编码要求

所有 `.ps1` 必须使用 `UTF-8 with BOM` 保存。

如果你手工修改过脚本，发布前建议重新写回 BOM：

```powershell
$p = "C:\path\to\script.ps1"
$text = [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($p, $text, [System.Text.UTF8Encoding]::new($true))
```

## 发布到 GitHub

仓库根目录就是技能目录本身：

```bash
git add -A
git commit -m "fix: harden powershell workflow"
git push
```

若本机没有稳定的 Git 凭据缓存，再按你本地凭证文档中的非交互式 PAT 流程推送。
