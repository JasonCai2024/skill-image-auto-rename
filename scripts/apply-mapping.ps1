param(
    [Parameter(Mandatory=$true)]
    [string]$downloadDir,

    [Parameter(Mandatory=$true)]
    [string]$mdPath,

    [Parameter(Mandatory=$true)]
    [string]$matchMapFile
)

$ErrorActionPreference = "Stop"

function Get-ConfidenceState {
    param(
        [Parameter(Mandatory=$false)]
        $value
    )

    if ($null -eq $value) {
        return "missing"
    }

    $text = "$value".Trim().ToLowerInvariant()
    if ([string]::IsNullOrEmpty($text)) {
        return "missing"
    }

    return $text
}

# 1. 加载匹配表
if (-not (Test-Path $matchMapFile)) {
    throw "匹配表文件不存在: $matchMapFile"
}
$matchMap = Get-Content -LiteralPath $matchMapFile -Raw -Encoding UTF8 | ConvertFrom-Json

$mdDir = Split-Path -Parent $mdPath
$attachDir = Join-Path $mdDir "Attachments"

Write-Host "==== 应用匹配表 (基于文件名映射) ====" -ForegroundColor Cyan
Write-Host "  匹配条数: $($matchMap.matches.Count)"
Write-Host "  目标目录: $attachDir"
Write-Host "  规则: 仅复制到 MD 同级 Attachments；不读取 Obsidian attachmentFolderPath" -ForegroundColor Gray

# 2. 执行重命名
$matched = 0
$skipped = 0
$failed = 0
$lowConfidenceSkipped = 0
$missingConfidenceProcessed = 0
$multiAssigned = @{}  # 记录每个目标引用名被匹配了几次
$filesToCopy = @{}

foreach ($m in $matchMap.matches) {
    $srcName = $m.filename
    $dstName = $m.refName
    $confidence = Get-ConfidenceState -value $m.confidence

    # 过滤掉无效/无匹配的分镜
    if ([string]::IsNullOrEmpty($dstName) -or $dstName -eq "无匹配" -or $dstName -eq "-1") {
        Write-Host "  [跳过] 图片 $srcName 标记为无匹配或多余" -ForegroundColor Gray
        $skipped++
        continue
    }

    if ($confidence -in @("medium", "low")) {
        Write-Host "  [跳过-$confidence] 图片 $srcName 置信度为 $confidence，保持原名且不复制" -ForegroundColor Gray
        $skipped++
        $lowConfidenceSkipped++
        continue
    }

    if ($confidence -eq "missing") {
        Write-Host "  [警告] 图片 $srcName 未提供 confidence，按高置信度兼容处理" -ForegroundColor Yellow
        $missingConfidenceProcessed++
    } elseif ($confidence -ne "high") {
        Write-Host "  [跳过-$confidence] 图片 $srcName 置信度不支持自动应用，保持原名且不复制" -ForegroundColor Gray
        $skipped++
        continue
    }

    # 检查同分镜被多次匹配
    if ($multiAssigned.ContainsKey($dstName)) {
        Write-Host "  [冲突] 目标文件名 $dstName 被映射到多张图片！" -ForegroundColor Red
        $failed++
        continue
    }
    $multiAssigned[$dstName] = $true

    $srcPath = Join-Path $downloadDir $srcName
    $dstPath = Join-Path $downloadDir $dstName

    # 检查源文件是否存在
    if (-not (Test-Path -LiteralPath $srcPath)) {
        # 如果源文件不存在，但目标文件已经存在，说明可能在之前的运行中已经重命名成功了
        if (Test-Path -LiteralPath $dstPath) {
            Write-Host "  [OK-已存在] $dstName (图片已在先前运行中重命名)" -ForegroundColor Gray
            $matched++
            $filesToCopy[$dstName] = $dstPath
            continue
        }
        Write-Host "  [错误] 找不到源图片: $srcName" -ForegroundColor Red
        $failed++
        continue
    }

    # 检查目标文件是否冲突
    if (Test-Path -LiteralPath $dstPath) {
        Write-Host "  [冲突-目标存在] 目标文件名已存在，无法重命名: $srcName -> $dstName" -ForegroundColor Yellow
        $skipped++
        continue
    }

    try {
        Rename-Item -LiteralPath $srcPath -NewName $dstName -ErrorAction Stop
        Write-Host "  [OK] $srcName -> $dstName" -ForegroundColor Green
        $matched++
        $filesToCopy[$dstName] = $dstPath
    } catch {
        Write-Host "  [失败] $srcName -> ${dstName}: $_" -ForegroundColor Red
        $failed++
    }
}

# 3. 复制到 Attachments
Write-Host ""
Write-Host "==== 复制到 Attachments ====" -ForegroundColor Cyan

if (-not (Test-Path $attachDir)) {
    New-Item -ItemType Directory -Path $attachDir -Force | Out-Null
    Write-Host "  [创建] $attachDir" -ForegroundColor Cyan
}

$copied = 0
foreach ($name in $filesToCopy.Keys | Sort-Object) {
    $src = $filesToCopy[$name]
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Host "  [复制跳过] 源文件不存在: $name" -ForegroundColor Yellow
        continue
    }

    $dst = Join-Path $attachDir $name
    if (Test-Path -LiteralPath $dst) {
        continue
    }

    try {
        Copy-Item -LiteralPath $src -Destination $dst -ErrorAction Stop
        $copied++
    } catch {
        Write-Host "  [复制失败] ${name}: $_" -ForegroundColor Red
    }
}

Write-Host "  复制完成: $copied 张"

# 4. 总结
Write-Host ""
Write-Host "==== 完成 ====" -ForegroundColor Cyan
Write-Host "  匹配/重命名成功: $matched"
Write-Host "  跳过: $skipped"
Write-Host "  失败: $failed"
Write-Host "  medium/low 跳过: $lowConfidenceSkipped"
Write-Host "  缺失 confidence 兼容处理: $missingConfidenceProcessed"
Write-Host "  复制到 Attachments: $copied 张"
