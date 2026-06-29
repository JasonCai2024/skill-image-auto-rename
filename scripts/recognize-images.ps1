param(
    [Parameter(Mandatory = $true)]
    [string]$downloadDir,

    [Parameter(Mandatory = $true)]
    [string]$outputJson,

    [Parameter(Mandatory = $false)]
    [string]$apiKey = "",

    [Parameter(Mandatory = $false)]
    [int]$sleepMs = 500,

    [Parameter(Mandatory = $false)]
    [string]$imageFilter = "^ChatGPT Image "
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Utf8Json {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        $Value
    )

    $json = $Value | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

$mmxStatus = & mmx auth status 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "mmx CLI 不可用: $mmxStatus"
}

if (-not (Test-Path -LiteralPath $downloadDir)) {
    throw "下载文件夹不存在: $downloadDir"
}

$images = Get-ChildItem -LiteralPath $downloadDir -Filter "*.png" |
    Where-Object { $_.Name -match $imageFilter } |
    Sort-Object LastWriteTime

if ($images.Count -eq 0) {
    throw "下载文件夹中没有匹配的图片文件（filter: $imageFilter）: $downloadDir"
}

$results = @()
$done = @()
if (Test-Path -LiteralPath $outputJson) {
    try {
        $existing = [System.IO.File]::ReadAllText($outputJson, $utf8NoBom) | ConvertFrom-Json
        if ($existing.images) {
            $results = @($existing.images)
            $done = @($existing.images | ForEach-Object { $_.filename })
            Write-Host "  已识别: $($done.Count) 张（断点续传）" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [警告] 现有输出 JSON 解析失败，将从头覆盖: $outputJson" -ForegroundColor Yellow
        $results = @()
        $done = @()
    }
}

$remaining = $images | Where-Object { $_.Name -notin $done }

Write-Host "==== 开始识别图片 ====" -ForegroundColor Cyan
Write-Host "  总数: $($images.Count)"
Write-Host "  待处理: $($remaining.Count)"

if ($remaining.Count -eq 0) {
    Write-Host "  [完成] 所有图片已识别，无需重复执行" -ForegroundColor Green
    return
}

$prompt = "请提取并列出这张图片中的核心视觉元素，按以下结构分项输出（控制在80字以内）：`n" +
    "1. 主体角色（如：1个绿衣男孩）`n" +
    "2. 动作姿态（如：用手指着前方）`n" +
    "3. 面部表情（如：自信微笑、沮丧、平静）`n" +
    "4. 核心背景与道具（如：电脑房、全息发光灯泡）`n" +
    "5. 色调与画风（如：3D动画画风、冷色调）"

$idx = $results.Count + 1
foreach ($img in $remaining) {
    Write-Host "  [$idx/$($images.Count)] $($img.Name)" -ForegroundColor Yellow

    try {
        $json = & mmx vision describe --image $img.FullName --prompt $prompt --output json --quiet 2>$null
        $r = $json | ConvertFrom-Json
        $desc = "$($r.content)"

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

    $partial = @{
        downloadDir = $downloadDir
        imageCount  = $images.Count
        progress    = $idx
        images      = $results
    }
    Write-Utf8Json -Path $outputJson -Value $partial

    $idx++
    Start-Sleep -Milliseconds $sleepMs
}

$result = @{
    downloadDir = $downloadDir
    imageCount  = $images.Count
    images      = $results
}
Write-Utf8Json -Path $outputJson -Value $result

Write-Host ""
Write-Host "==== 识别完成 ====" -ForegroundColor Cyan
Write-Host "  总数: $($images.Count)"
Write-Host "  成功: $(@($results | Where-Object { -not $_.error }).Count)"
Write-Host "  失败: $(@($results | Where-Object { $_.error }).Count)"
Write-Host "  输出: $outputJson"
