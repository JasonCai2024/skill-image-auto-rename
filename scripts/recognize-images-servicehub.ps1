param(
    [Parameter(Mandatory=$true)]
    [string]$downloadDir,

    [Parameter(Mandatory=$true)]
    [string]$outputJson,

    [Parameter(Mandatory=$true)]
    [string]$username,

    [Parameter(Mandatory=$true)]
    [string]$passtoken,

    [Parameter(Mandatory=$false)]
    [string]$baseUrl = "https://www.ccailab.top",

    [Parameter(Mandatory=$false)]
    [string]$endpoint = "/api/llm/paid-rotation",

    [Parameter(Mandatory=$false)]
    [string]$provider = "minimax",

    [Parameter(Mandatory=$false)]
    [string]$model = "MiniMax-M3",

    [Parameter(Mandatory=$false)]
    [string]$imageFilter = "^ChatGPT Image ",

    [Parameter(Mandatory=$false)]
    [int]$maxRetry = 3,

    [Parameter(Mandatory=$false)]
    [int]$retrySleepMs = 3000
)

$ErrorActionPreference = "Stop"

# 1. 验证输入
if (-not (Test-Path $downloadDir)) {
    throw "下载文件夹不存在: $downloadDir"
}

$url = "$baseUrl$endpoint"
Write-Host "==== ServiceHub $model 图片识别 ====" -ForegroundColor Cyan
Write-Host "  下载文件夹: $downloadDir"
Write-Host "  接口端点: $url"
Write-Host "  用户名: $username"

# 2. 获取已识别进度（增量写入 + 断点续传）
$done = @()
if (Test-Path $outputJson) {
    try {
        $existing = Get-Content $outputJson -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($existing.images) {
            $done = @($existing.images | ForEach-Object { $_.filename })
            Write-Host "  已识别: $($done.Count) 张（断点续传）" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [警告] 现有 JSON 解析失败，将覆盖" -ForegroundColor Yellow
    }
}

# 3. 获取下载图片
$images = Get-ChildItem -LiteralPath $downloadDir -Filter "*.png" |
    Where-Object { $_.Name -match $imageFilter } |
    Sort-Object LastWriteTime

if ($images.Count -eq 0) {
    throw "下载文件夹中没有匹配的图片（filter: $imageFilter）: $downloadDir"
}

# 排除已识别
$remaining = $images | Where-Object { $_.Name -notin $done }
Write-Host "  总数: $($images.Count) 剩余: $($remaining.Count)"

if ($remaining.Count -eq 0) {
    Write-Host "  [完成] 所有图片已识别，无需处理" -ForegroundColor Green
    return
}

# 4. 加载或初始化结果
if (Test-Path $outputJson) {
    $data = Get-Content $outputJson -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $data = @{
        downloadDir = $downloadDir
        imageCount   = $images.Count
        images       = @()
    }
}

# 5. 识别 prompt（结构化视觉特征提取）
$textPrompt = "请提取并列出这张图片中的核心视觉元素，按以下结构分项输出（控制在80字以内）：`n" +
              "1. 主体角色（如：1个绿衣男孩）`n" +
              "2. 动作姿态（如：用手指着前方）`n" +
              "3. 面部表情（如：自信微笑、沮丧、平静）`n" +
              "4. 核心背景与道具（如：电脑房、全息发光灯泡）`n" +
              "5. 色调与画风（如：3D动画画风、冷色调）"

# 6. 逐张识别
$nextIdx = $data.images.Count + 1
$successCount = 0
$failedCount = 0

foreach ($img in $remaining) {
    Write-Host "  [$nextIdx] $($img.Name)" -ForegroundColor Yellow

    # 6.1 base64 编码
    try {
        $bytes = [System.IO.File]::ReadAllBytes($img.FullName)
        $base64 = [Convert]::ToBase64String($bytes)
        $mediaType = switch ($img.Extension.ToLower()) {
            ".png"  { "image/png" }
            ".jpg"  { "image/jpeg" }
            ".jpeg" { "image/jpeg" }
            ".webp" { "image/webp" }
            default { "image/png" }
        }
    } catch {
        Write-Host "    [错误] 读取图片失败: $_" -ForegroundColor Red
        $data.images += @{
            index       = $nextIdx
            filename    = $img.Name
            description = ""
            error       = "read_failed: $_"
        }
        $failedCount++
        $nextIdx++
        $data | ConvertTo-Json -Depth 10 | Out-File $outputJson -Encoding UTF8
        continue
    }

    # 6.2 构造请求体
    $body = @{
        username  = $username
        passtoken = $passtoken
        provider  = $provider
        model     = $model
        user_prompt = @(
            @{
                type = "image"
                source = @{
                    type       = "base64"
                    media_type = $mediaType
                    data       = $base64
                }
            }
            @{
                type = "text"
                text = $textPrompt
            }
        )
    }

    # 6.3 重试调用
    $ok = $false
    $lastError = ""
    for ($retry = 1; $retry -le $maxRetry; $retry++) {
        try {
            $jsonBody = $body | ConvertTo-Json -Depth 10 -Compress
            $responseObj = Invoke-WebRequest `
                -Uri $url `
                -Method Post `
                -ContentType "application/json; charset=utf-8" `
                -Body $jsonBody `
                -TimeoutSec 180

            # Decode UTF-8 correctly
            $rawString = ""
            if ($responseObj.Content -is [string]) {
                # If it's a string, it might have been decoded incorrectly, check if it needs recovery
                try {
                    $bytes = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($responseObj.Content)
                    $rawString = [System.Text.Encoding]::UTF8.GetString($bytes)
                } catch {
                    $rawString = $responseObj.Content
                }
            } else {
                $rawString = [System.Text.Encoding]::UTF8.GetString($responseObj.Content)
            }
            $response = ConvertFrom-Json $rawString

            # 6.4 检查业务错误码
            if ($response.code -ne 200) {
                $lastError = "业务错误: code=$($response.code), message=$($response.message)"
                Write-Host "    [重试 $retry/$maxRetry] $lastError" -ForegroundColor Gray
                Start-Sleep -Milliseconds $retrySleepMs
                continue
            }

            if (-not $response.data.processed_text) {
                $lastError = "响应缺少 processed_text"
                Write-Host "    [重试 $retry/$maxRetry] $lastError" -ForegroundColor Gray
                Start-Sleep -Milliseconds $retrySleepMs
                continue
            }

            # 6.5 成功
            $description = $response.data.processed_text
            $data.images += @{
                index       = $nextIdx
                filename    = $img.Name
                description = $description
            }
            Write-Host "    $($description.Substring(0, [Math]::Min(60, $description.Length)))" -ForegroundColor Gray
            $ok = $true
            $successCount++
            break
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorBody = ""
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $errorBody = $reader.ReadToEnd()
            } catch {}

            # 401 / 402 立即停止（不要重试）
            if ($statusCode -eq 401) {
                throw "401 未授权：用户名或密码令牌错误"
            }
            if ($statusCode -eq 402) {
                throw "402 积分不足：请充值 ServiceHub 账户"
            }

            $lastError = "HTTP $statusCode : $_"
            if ($errorBody) { $lastError += " | body: $errorBody" }
            Write-Host "    [重试 $retry/$maxRetry] $lastError" -ForegroundColor Gray
            Start-Sleep -Milliseconds $retrySleepMs
        }
    }

    if (-not $ok) {
        $data.images += @{
            index       = $nextIdx
            filename    = $img.Name
            description = ""
            error       = "max_retry: $lastError"
        }
        $failedCount++
    }

    $nextIdx++
    # 增量写入
    $data | ConvertTo-Json -Depth 10 | Out-File $outputJson -Encoding UTF8
}

# 7. 更新最终统计
$data.imageCount = $data.images.Count
$data | ConvertTo-Json -Depth 10 | Out-File $outputJson -Encoding UTF8

Write-Host ""
Write-Host "==== 识别完成 ====" -ForegroundColor Cyan
Write-Host "  总数: $($images.Count)"
Write-Host "  已成功: $successCount"
Write-Host "  本轮失败: $failedCount"
Write-Host "  输出: $outputJson"