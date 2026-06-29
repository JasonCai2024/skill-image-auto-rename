# ServiceHub 兼容性说明

## 结论

截至 2026-06-30，本仓库不再把 ServiceHub `/api/llm/paid-rotation` 当成可直接承载历史多模态图片识别请求的主路径。

实测现象：
- 端点：`https://www.ccailab.top/api/llm/paid-rotation`
- `user_prompt` 为纯文本字符串时：`200`
- `user_prompt` 为历史多模态数组，且图片以 base64 内联时：`422`

因此，旧版这类请求体当前不可用：

```json
{
  "user_prompt": [
    {
      "type": "image",
      "source": {
        "type": "base64",
        "media_type": "image/png",
        "data": "<base64>"
      }
    },
    {
      "type": "text",
      "text": "describe this image"
    }
  ]
}
```

## 当前仓库策略

- `scripts/recognize-images-servicehub.ps1`
  保留文件名不变，只做兼容包装器
- 实际识别工作
  自动委托给 `scripts/recognize-images.ps1`

## 如果未来要恢复 ServiceHub

至少需要以下任一条件：

1. ServiceHub 明确支持图片多模态数组
2. ServiceHub 提供“先上传图片，再给 URL”的稳定工作流
3. 仓库里能拿到该工作流的正式参数规范和返回样例

在条件没明确前，不建议再把 ServiceHub 写回主路径。
