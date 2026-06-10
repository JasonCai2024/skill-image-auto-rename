# ServiceHub M3 多模态接口 详细用法

## 概述

本技能通过 ServiceHub 平台的 `/api/llm/paid-rotation` 接口调用 MiniMax-M3 多模态模型识别图片。M3 支持同时接收文本 + 图片块，输出图片描述。

**生产端点**：`https://www.ccailab.top/api/llm/paid-rotation`
**本地开发端点**：`http://127.0.0.1:8000/api/llm/paid-rotation`

## 为什么不用 mmx CLI

| 维度 | mmx CLI | ServiceHub M3 |
|------|---------|---------------|
| 鉴权方式 | API key（敏感）| username + passtoken（社群会员可用）|
| 共享给社群 | ❌ 需要泄露 API key | ✅ 用户自己注册账号 |
| 凭证管理 | 本地 config.json | 服务端账户体系 |
| 计费 | token plan 配额 | ServiceHub 积分（用户余额）|
| 适用场景 | 个人开发者 | 社群共享技能 |

## 接口规范

### 请求格式

```json
{
  "username": "your_username",
  "passtoken": "your_passtoken",
  "provider": "minimax",
  "model": "MiniMax-M3",
  "user_prompt": [
    {
      "type": "image",
      "source": {
        "type": "base64",
        "media_type": "image/png",
        "data": "<base64-encoded image bytes>"
      }
    },
    {
      "type": "text",
      "text": "描述这张图片的核心内容：人物外貌特征、动作、场景、关键物体。用50字以内概括。"
    }
  ]
}
```

### 关键字段

| 字段 | 值 | 说明 |
|------|---|------|
| `provider` | `minimax` | **固定**，不切换 |
| `model` | `MiniMax-M3` | **固定**，不切换 |
| `user_prompt[0].type` | `image` | 图片块 |
| `user_prompt[0].source.type` | `base64` | 本地图片必须用 base64 编码 |
| `user_prompt[0].source.media_type` | `image/png` | PNG 图填这个；JPG 填 `image/jpeg` |
| `user_prompt[1].type` | `text` | 识别指令 |
| `user_prompt[1].text` | 见 prompt 模板 | 与 mmx CLI 使用的同一套 prompt |

### 响应格式

```json
{
  "code": 200,
  "message": "处理成功",
  "data": {
    "task_id": "uuid-string",
    "processed_text": "绿衣男孩蹲地抱头被Codex大喇叭喷射技术术语淹没",
    "processing_time": 2.5,
    "provider_used": "minimax",
    "model_used": "MiniMax-M3",
    "total_tokens": 5000,
    "input_tokens": 4800,
    "output_tokens": 200,
    "input_cost": 50.4,
    "output_cost": 8.4,
    "total_cost": 73.5,
    "trade_order_id": "uuid-string",
    "reasoning": null
  },
  "params": {
    "username": "xxx",
    "task_type": "text_arrange",
    "user_prompt": "..."
  }
}
```

**技能侧只读取**：`data.processed_text` 作为图片描述。其他字段（积分、tokens、reasoning）由 ServiceHub 处理，技能侧不展示。

## 错误码

| 状态码 | 含义 | 技能侧处理 |
|--------|------|----------|
| 200 | 成功 | 读 `data.processed_text` |
| 400 | 请求参数错误 | 立即停止，提示用户检查参数 |
| 401 | 用户名/密码错误 | 立即停止，提示用户检查凭据 |
| 402 | 积分不足 | 立即停止，提示用户充值 |
| 500 | 服务器内部错误 | 重试 3 次，仍失败则记录 `error` 跳过该图 |
| 网络超时 | ServiceHub 不可达 | 重试 3 次（间隔 3 秒），仍失败则跳过 |

## 性能参考

| 指标 | 数值 |
|------|------|
| 单张图识别耗时 | 2-5 秒（取决于图大小和网络）|
| 53 张图批量 | 2-5 分钟 |
| 增量写入支持 | ✅ |
| 自动重试支持 | ✅ |

## 图片 base64 编码注意事项

1. **大小限制**：ServiceHub 接口默认 base64 编码后大小限制参考 API 文档（一般 < 10MB）
2. **格式支持**：PNG / JPG / JPEG / WEBP
3. **编码方式**：使用 PowerShell `[Convert]::ToBase64String([System.IO.File]::ReadAllBytes(path))` 或 Python `base64.b64encode(open(path,'rb').read()).decode()`

## 与 mmx CLI 的差异

| 差异点 | mmx CLI | ServiceHub M3 |
|--------|---------|---------------|
| 请求体格式 | 简单 `{prompt, image_url}` | Anthropic 消息块格式 `[{type:image},{type:text}]` |
| 响应模型字段 | 不返回模型名 | 返回 `model_used=MiniMax-M3` |
| 错误格式 | `{error: {code, message}}` | HTTP 标准状态码 + JSON body |
| 重试策略 | CLI 进程级 | 技能侧自行实现 |

## 在 PowerShell 中调用的示例

```powershell
$imagePath = "C:\Users\pc\Downloads\test.png"
$base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($imagePath))
$prompt = "描述这张图片的核心内容：人物外貌特征、动作、场景、关键物体。用50字以内概括。"

$body = @{
    username = "your_username"
    passtoken = "your_passtoken"
    provider = "minimax"
    model = "MiniMax-M3"
    user_prompt = @(
        @{
            type = "image"
            source = @{
                type = "base64"
                media_type = "image/png"
                data = $base64
            }
        },
        @{
            type = "text"
            text = $prompt
        }
    )
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod `
    -Uri "https://www.ccailab.top/api/llm/paid-rotation" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body

$description = $response.data.processed_text
```

## 应急：fallback 到 mmx CLI

如果 ServiceHub 接口长期不可用（不是 401/402 这种用户问题，而是服务端挂掉），可以临时改用 mmx CLI 通道：

```powershell
# 切换到应急脚本
powershell -NoProfile -File "<技能目录>\scripts\recognize-images.ps1" `
    -downloadDir "<下载文件夹>" `
    -outputJson "<JSON路径>" `
    -apiKey "$env:MMX_API_KEY"
```

**前提**：本机装好 `mmx-cli` 并配置了 API key（`mmx auth status` 验证通过）。