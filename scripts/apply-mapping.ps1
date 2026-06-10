param(
    [Parameter(Mandatory=$true)]
    [string]$downloadDir,

    [Parameter(Mandatory=$true)]
    [string]$mdPath,

    [Parameter(Mandatory=$true)]
    [string]$matchMapFile
)

$ErrorActionPreference = "Stop"

# 1. 加载匹配表
if (-not (Test-Path $matchMapFile)) {
    throw "匹配表文件不存在: $matchMapFile"
}
$matchMap = Get-Content -LiteralPath $matchMapFile -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "==== 应用匹配表 (基于文件名映射) ====" -ForegroundColor Cyan
Write-Host "  匹配条数: $($matchMap.matches.Count)"

# 2. 执行重命名
$matched = 0
$skipped = 0
$failed = 0
$multiAssigned = @{}  # 记录每个目标引用名被匹配了几次

foreach ($m in $matchMap.matches) {
    $srcName = $m.filename
    $dstName = $m.refName

    # 过滤掉无效/无匹配的分镜
    if ([string]::IsNullOrEmpty($dstName) -or $dstName -eq "无匹配" -or $dstName -eq "-1") {
        Write-Host "  [跳过] 图片 $srcName 标记为无匹配或多余" -ForegroundColor Gray
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
    } catch {
        Write-Host "  [失败] $srcName -> ${dstName}: $_" -ForegroundColor Red
        $failed++
    }
}

# 3. 复制到 Attachments
Write-Host ""
Write-Host "==== 复制到 Attachments ====" -ForegroundColor Cyan

$mdDir = Split-Path -Parent $mdPath
$attachDir = Join-Path $mdDir "Attachments"
if (-not (Test-Path $attachDir)) {
    New-Item -ItemType Directory -Path $attachDir -Force | Out-Null
    Write-Host "  [创建] $attachDir" -ForegroundColor Cyan
}

# 推断文件名前缀（从匹配表的目标文件名里找）
$prefix = ""
foreach ($m in $matchMap.matches) {
    if ($m.refName -match '^(\d+)-') {
        $prefix = $Matches[1] + "-"
        break
    }
}

$copied = 0
Get-ChildItem -LiteralPath $downloadDir -Filter "*.png" |
    Where-Object { $_.Name -match "^\d+-\d+.*\.png$" -or ($prefix -ne "" -and $_.Name.StartsWith($prefix)) } |
    ForEach-Object {
        $dst = Join-Path $attachDir $_.Name
        if (Test-Path -LiteralPath $dst) { return }
        try {
            Copy-Item -LiteralPath $_.FullName -Destination $dst -ErrorAction Stop
            $copied++
        } catch {
            Write-Host "  [复制失败] $_.Name: $_" -ForegroundColor Red
        }
    }

Write-Host "  复制完成: $copied 张"

# 4. 总结
Write-Host ""
Write-Host "==== 完成 ====" -ForegroundColor Cyan
Write-Host "  匹配/重命名成功: $matched"
Write-Host "  跳过: $skipped"
Write-Host "  失败: $failed"
Write-Host "  复制到 Attachments: $copied 张"
