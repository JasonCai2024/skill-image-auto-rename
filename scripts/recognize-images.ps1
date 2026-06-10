param(
    [Parameter(Mandatory=$true)]
    [string]$downloadDir,

    [Parameter(Mandatory=$true)]
    [string]$outputJson,

    [Parameter(Mandatory=$false)]
    [string]$apiKey = "",

    [Parameter(Mandatory=$false)]
    [int]$sleepMs = 500
)

$ErrorActionPreference = "Stop"

# 1. 验证 mmx 可用
$mmxStatus = & mmx auth status 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "mmx CLI 不可用: $mmxStatus"
}

# 2. 获取下载图片
if (-not (Test-Path $downloadDir)) {
    throw "下载文件夹不存在: $downloadDir"
}

$images = Get-ChildItem -LiteralPath $downloadDir -Filter "*.png" |
    Where-Object { $_.Name -match '^ChatGPT Image ' } |
    Sort-Object LastWriteTime

if ($images.Count -eq 0) {
    throw "下载文件夹中没有 ChatGPT Image *.png 文件: $downloadDir"
}

Write-Host "==== 开始识别 $($images.Count) 张图片 ====" -ForegroundColor Cyan

# 3. 逐张识别（结构化视觉特征提取）
$prompt = "请提取并列出这张图片中的核心视觉元素，按以下结构分项输出（控制在80字以内）：`n" +
          "1. 主体角色（如：1个绿衣男孩）`n" +
          "2. 动作姿态（如：用手指着前方）`n" +
          "3. 面部表情（如：自信微笑、沮丧、平静）`n" +
          "4. 核心背景与道具（如：电脑房、全息发光灯泡）`n" +
          "5. 色调与画风（如：3D动画画风、冷色调）"
$results = @()
$idx = 1

foreach ($img in $images) {
    Write-Host "  [$idx/$($images.Count)] $($img.Name)" -ForegroundColor Yellow

    try {
        $json = & mmx vision describe --image $img.FullName --prompt $prompt --output json --quiet 2>$null
        $r = $json | ConvertFrom-Json
        $desc = $r.content

        $results += @{
            index       = $idx
            filename    = $img.Name
            description = $desc
        }
        Write-Host "    $($desc.Substring(0, [Math]::Min(60, $desc.Length)))" -ForegroundColor Gray
    } catch {
        Write-Host "    识别失败: $_" -ForegroundColor Red
        $results += @{
            index       = $idx
            filename    = $img.Name
            description = ""
            error       = "$_"
        }
    }

    $idx++
    Start-Sleep -Milliseconds $sleepMs

    # 增量写入：每张图识别完就写一次，避免中断丢失
    $partial = @{
        downloadDir = $downloadDir
        imageCount  = $images.Count
        progress    = $idx - 1
        images      = $results
    }
    $partial | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputJson -Encoding UTF8
}

# 4. 写最终 JSON
$result = @{
    downloadDir = $downloadDir
    imageCount  = $images.Count
    images      = $results
}
$result | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputJson -Encoding UTF8

Write-Host ""
Write-Host "==== 识别完成 ====" -ForegroundColor Cyan
Write-Host "  总数: $($images.Count)"
Write-Host "  成功: $($results | Where-Object { -not $_.error }.Count)"
Write-Host "  失败: $($results | Where-Object { $_.error }.Count)"
Write-Host "  输出: $outputJson"
