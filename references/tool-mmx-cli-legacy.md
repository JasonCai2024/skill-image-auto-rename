# mmx CLI 详细用法

## 什么是 mmx

`mmx` 是 MiniMax 提供的命令行工具，提供图片理解等 AI 能力。

**关键特性**：
- 通过本地 `config.json` 认证（不依赖 OAuth 弹窗）
- 跨平台：Windows / macOS / Linux 都能用
- 不依赖任何特定 AI 编程环境（Claude Code、Codex、OpenCode 都能用）

## 安装

```bash
npm install -g mmx-cli
```

## 认证

第一次跑 `mmx vision describe` 时会自动读取本地 `config.json` 里的 API key。

验证：
```bash
mmx auth status
# 应返回 {"method":"api-key", "source":"config.json", "key":"eyJh..."}
```

如果 `mmx auth status` 报错，**不要**反复试 `mmx auth`（会触发 OAuth 弹窗）。直接：
1. 检查 `~/.mmx-cli/config.json` 是否存在
2. 检查 API key 是否有效

## 常用命令

### 图片理解（核心命令）

```bash
mmx vision describe --image "<图片路径>" --prompt "<识别提示词>" --output json --quiet
```

**参数**：
| 参数 | 必填 | 说明 |
|------|------|------|
| `--image` | 是 | 本地图片绝对路径 |
| `--prompt` | 是 | 识别指令 |
| `--output` | 否 | `json`（默认）/ `text` |
| `--quiet` | 否 | 不输出额外日志 |

**示例**：
```bash
mmx vision describe --image "C:\Users\pc\Downloads\ChatGPT Image 2026年6月8日 00_34_05.png" --prompt "描述这张图片的核心内容：人物外貌特征、动作、场景、关键物体。用50字以内概括。" --output json --quiet
```

**返回**：
```json
{
  "content": "绿衣男孩蹲地抱头被Codex大喇叭喷射技术术语淹没",
  "model": "MiniMax-VL-01",
  "tokens": 234
}
```

### 在 PowerShell 中使用

```powershell
$result = mmx vision describe --image "C:\path\to\image.png" --prompt "描述..." --output json --quiet 2>$null | ConvertFrom-Json
$description = $result.content
```

注意 `2>$null` 抑制 stderr 输出（mmx 可能输出非 JSON 的进度信息到 stderr）。

## 批量识别最佳实践

### 推荐方式：分批每批 10 张

mmx CLI **没有**原生 batch 接口。要批量必须循环：

```powershell
$images = Get-ChildItem "C:\Users\pc\Downloads" "ChatGPT Image *.png" | Sort-Object LastWriteTime
$results = @()
foreach ($img in $images) {
    $r = mmx vision describe --image $img.FullName --prompt "..." --output json --quiet 2>$null | ConvertFrom-Json
    $results += @{ filename = $img.Name; description = $r.content }
    Start-Sleep -Milliseconds 500  # 避免触发 rate limit
}
$results | ConvertTo-Json -Depth 5 | Out-File "results.json" -Encoding UTF8
```

### 故障：Cannot find module

错误信息：
```
Error: Cannot find module 'C:\Users\pc\AppData\Roaming\npm\node_modules\mmx-cli\dist\mmx.mjs'
```

**原因**：npm 全局包 `mmx-cli` 被删或未安装。

**修复**：
```bash
npm install -g mmx-cli
mmx auth status  # 验证
```

### 故障：API key 无效

错误信息：`401 Unauthorized` 或 `invalid api key`

**修复**：
1. 找用户拿新的 API key
2. 编辑 `~/.mmx-cli/config.json`，更新 `key` 字段
3. 重跑 `mmx auth status` 验证

## 性能参考

| 操作 | 单次耗时 | 备注 |
|------|---------|------|
| 单张图片识别 | 0.5-2 秒 | 取决于图片大小和网络 |
| 53 张图批量 | 30-90 秒 | 加 500ms 间隔防 rate limit |
| 100 张图批量 | 60-180 秒 | 建议分批 50 + 50 |
