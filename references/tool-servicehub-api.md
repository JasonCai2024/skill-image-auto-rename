# ServiceHub 接口说明

## 结论

截至 2026-06-30，本仓库已恢复把 ServiceHub `/api/llm/paid-rotation` 当成图片识别主路径。

实测现象：
- 端点：`https://www.ccailab.top/api/llm/paid-rotation`
- `provider = minimax`
- `model = MiniMax-M3`
- `user_prompt` 使用 OpenAI 风格多模态数组
- `image_url.url` 直接传 `data:image/...;base64,...`
- 生产环境返回：`200`

推荐请求体：

```json
{
  "username": "<username>",
  "passtoken": "<passtoken>",
  "provider": "minimax",
  "model": "MiniMax-M3",
  "task_type": "text_arrange",
  "user_prompt": [
    {
      "type": "text",
      "text": "描述这张图片，并提取可见文字。"
    },
    {
      "type": "image_url",
      "image_url": {
        "url": "data:image/png;base64,<base64>"
      }
    }
  ]
}
```

## 当前仓库策略

- `scripts/recognize-images-servicehub.ps1`
  直接调用 ServiceHub 识别图片
- `scripts/recognize-images.ps1`
  仅保留作应急备用

## 注意事项

1. 默认主流程使用 `image_url + data URI`，不要再沿用旧的 `image/source/base64` 历史 payload。
2. 若服务端再次变更契约，应先复测生产端点，再更新本仓库文档和脚本。
