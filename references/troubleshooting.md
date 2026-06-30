# 故障排查

## 1. Windows PowerShell 5.1 中文乱码

症状：
- 中文路径报 `Cannot find path because it does not exist`
- 脚本里中文输出或字符串常量显示异常

原因：
- `.ps1` 不是 `UTF-8 with BOM`

修复：
- 把脚本重新保存为 `UTF-8 with BOM`
- 重新运行技能

## 2. ServiceHub 返回 4xx / 5xx

现状：
- 当前主路径就是 ServiceHub 多模态识图
- 若报错，优先检查凭证、网络和服务端状态

处理：
- 先确认 `SERVICETUBER_USERNAME` / `SERVICETUBER_PASSTOKEN` 是否正确
- 再确认 `https://www.ccailab.top/api/llm/paid-rotation` 当前是否可访问
- 若用户允许，再改用 `scripts/recognize-images.ps1`

## 3. 二次重跑后 Attachments 没更新

原因：
- 旧版脚本只会“存在即跳过”

处理：

```powershell
powershell -NoProfile -File ".\scripts\apply-mapping.ps1" `
  -downloadDir "<下载目录>" `
  -mdPath "<MD路径>" `
  -matchMapFile "<match_map.json>" `
  -Mode sync
```

若你明确要强制覆盖：

```powershell
-Mode force
```

## 4. 修正映射后出现链式重命名冲突

处理：

```powershell
-Mode chain
```

当前脚本会统一先改到临时名，再改到最终名，不需要再手写 Python chain rename。

## 5. 语义匹配错位

原因：
- `_images.json` 只是图片描述
- 它不是最终 `refName` 映射

处理：
- 重新读取 `_refs.json` + `_images.json`
- 让 LLM/agent 重做语义匹配
- 对不确定项打 `medium/low`
- 只让 `high` 进入应用阶段

## 6. mmx CLI 不可用

检查：

```powershell
mmx auth status
```

若失败：
- 先完成 mmx 登录
- 再运行 `scripts/recognize-images.ps1`
