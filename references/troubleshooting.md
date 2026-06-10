# 故障排查

## 1. ServiceHub M3 接口故障

### 错误：401 Unauthorized

**原因**：username 或 passtoken 错误。

**修复**：
1. 重新登录 https://www.ccailab.top 确认账号密码
2. 联系 ServiceHub 管理员确认账号状态
3. 检查 passtoken 是否过期

### 错误：402 积分不足

**原因**：用户积分余额为 0 或不够支付本批识别。

**修复**：登录 https://www.ccailab.top 充值后重试。

### 错误：500 Internal Server Error

**原因**：ServiceHub 后端异常。

**修复**：
1. 脚本会自动重试 3 次
2. 重跑 `recognize-images-servicehub.ps1`（断点续传，已成功的图跳过）
3. 持续失败时联系 ServiceHub 管理员

### 错误：网络超时

**修复**：
1. 检查能否访问 https://www.ccailab.top
2. 脚本默认 180 秒超时，可在脚本里调整 `-TimeoutSec`
3. 重跑脚本，已成功的图自动跳过

### 接口持续失败时的应急方案

```powershell
# 切回 mmx CLI 通道
powershell -NoProfile -File "<技能目录>\scripts\recognize-images.ps1" `
    -downloadDir "<下载文件夹>" `
    -outputJson "<JSON路径>" `
    -apiKey "$env:MMX_API_KEY"
```

## 2. mmx CLI 故障（应急通道）

### 错误：Cannot find module

```
Error: Cannot find module 'C:\Users\pc\AppData\Roaming\npm\node_modules\mmx-cli\dist\mmx.mjs'
```

**原因**：npm 全局包 `mmx-cli` 被删或未安装。

**修复**：
```bash
npm install -g mmx-cli
mmx auth status
```

### 错误：401 Unauthorized

```
{"error": "invalid api key"}
```

**修复**：
1. 找用户拿新的 API key
2. 编辑 `~/.mmx-cli/config.json`：
   ```json
   {"key": "新key"}
   ```
3. 重跑 `mmx auth status` 验证

### 错误：rate limit exceeded

```
{"error": "too many requests"}
```

**修复**：
- 在循环里加 `Start-Sleep -Milliseconds 1000`（每张图间隔 1 秒）
- 分批处理：每 30 张一批，批间休息 30 秒

## 2. MD 解析问题

### 错误：未找到任何 prompt 代码块

```
错误：未从MD文档中找到任何prompt代码块
```

**原因**：MD 里的代码块标识符不是 `prompt`。

**修复**：
- 全文搜索 ``` ```` `` 把其他标识符（`bash`、`` ``` ``、空）改成 `prompt`
- 详细规范见 `references/md-format-spec.md`

### 警告：分镜数与引用数不一致

```
警告：分镜数 53 != 引用数 52
```

**原因**：某段口播文案有 prompt 块但漏了 `![[xxx.png]]`，或反过来。

**修复**：
- 打开 MD 文档，逐个分镜核对
- 找出缺失的一边，补上

## 3. 匹配错误

### 症状：重命名后图片内容与 MD 分镜不对应

**原因**：AI agent 生成的匹配表错了。

**修复**：
1. 打开 `image_match_map.md`（脚本生成的清单）
2. 对比每张图描述和每个分镜 prompt
3. 手动修正匹配表 JSON
4. 重跑第 4 步应用

### 症状：多余图片没被处理

**原因**：下载图片数 > MD 引用数。

**处理**：
- 脚本不会自动删除多余图（保留原名不删）
- 用户手动决定：删除 / 重命名复用 / 备份

### 症状：某些分镜没图

**原因**：下载图片数 < MD 引用数。

**修复**：
- 补生成缺失的图片
- 或修改 MD 文档去掉没图的分镜

## 4. PowerShell 5.1 转义陷阱

### 错误：长 inline 脚本解析失败

```bash
# ❌ 不要这样做
powershell -Command "Get-ChildItem 'C:\Users\pc\Downloads' 'ChatGPT Image *.png' | ForEach-Object { ... 很长的代码 ... }"
```

**修复**：把脚本写到 `.ps1` 文件再执行：
```powershell
# 先 Write 工具写脚本
# 再 powershell -File "C:\path\to\script.ps1"
```

### 错误：路径含空格

```
# 错误：找不到文件
Get-ChildItem 'C:\Users\pc\Downloads\ChatGPT Image *.png'
```

**修复**：用 `-LiteralPath` 或 `-Filter`：
```powershell
Get-ChildItem -LiteralPath 'C:\Users\pc\Downloads' -Filter 'ChatGPT Image *.png'
```

## 5. 错位重命名

### 症状：第一次重命名匹配错了，第二次想改回

**不能直接改**——目标文件已存在会冲突。

**正确流程**（三步走）：
1. 把错位文件改回**临时名**：`47-33.png` → `ChatGPT Image 2026年6月8日 21_49_09 (fix).png`
2. 把正确来源重命名为目标名
3. 把临时名文件改名为正确目标

**示例**（PowerShell）：
```powershell
Rename-Item "47-33.png" "ChatGPT Image 2026年6月8日 21_49_09 (fix).png"
Rename-Item "ChatGPT Image 2026年6月8日 21_42_01.png" "47-33.png"
Rename-Item "ChatGPT Image 2026年6月8日 21_49_09 (fix).png" "47-36-1.png"
```

## 6. 性能问题

### 53 张图跑 30 分钟还没完

**原因**：
- mmx API 慢
- 网络问题
- rate limit 反复触发

**修复**：
- 检查 `mmx auth status` 是否正常
- 加 `Start-Sleep -Milliseconds 500` 在循环里
- 考虑分批 20 + 20 + 13
