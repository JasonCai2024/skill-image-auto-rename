param(
    [Parameter(Mandatory = $true)]
    [string]$downloadDir,

    [Parameter(Mandatory = $true)]
    [string]$mdPath,

    [Parameter(Mandatory = $true)]
    [string]$matchMapFile,

    [Parameter(Mandatory = $false)]
    [ValidateSet("create", "sync", "force", "chain")]
    [string]$Mode = "sync"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Get-ConfidenceState {
    param(
        [Parameter(Mandatory = $false)]
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

function Should-SkipMatch {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RefName
    )

    if ([string]::IsNullOrWhiteSpace($RefName)) {
        return $true
    }

    $normalized = $RefName.Trim().ToLowerInvariant()
    return $normalized -in @("无匹配", "skip", "unmatched", "-1")
}

function Get-FileHashSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash
}

function Get-UniqueTempName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$Extension
    )

    do {
        $candidate = ".__air_tmp__{0}{1}" -f ([guid]::NewGuid().ToString("N")), $Extension
        $candidatePath = Join-Path $Directory $candidate
    } while (Test-Path -LiteralPath $candidatePath)

    return $candidate
}

if (-not (Test-Path -LiteralPath $downloadDir)) {
    throw "下载文件夹不存在: $downloadDir"
}

if (-not (Test-Path -LiteralPath $mdPath)) {
    throw "MD 文件不存在: $mdPath"
}

if (-not (Test-Path -LiteralPath $matchMapFile)) {
    throw "匹配表文件不存在: $matchMapFile"
}

$matchMap = [System.IO.File]::ReadAllText($matchMapFile, $utf8NoBom) | ConvertFrom-Json

$mdDir = Split-Path -Parent $mdPath
$attachDir = Join-Path $mdDir "Attachments"

Write-Host "==== 应用匹配表 (基于文件名映射) ====" -ForegroundColor Cyan
Write-Host "  匹配条数: $($matchMap.matches.Count)"
Write-Host "  目标目录: $attachDir"
Write-Host "  模式: $Mode"
Write-Host "  规则: 仅复制到 MD 同级 Attachments；不读取 Obsidian attachmentFolderPath" -ForegroundColor Gray

$matched = 0
$skipped = 0
$failed = 0
$lowConfidenceSkipped = 0
$missingConfidenceProcessed = 0
$multiAssigned = @{}
$filesToCopy = @{}
$pendingRenames = @()

foreach ($m in $matchMap.matches) {
    $srcName = "$($m.filename)"
    $dstName = if ($null -eq $m.refName) { "" } else { "$($m.refName)" }
    $confidence = Get-ConfidenceState -value $m.confidence

    if ([string]::IsNullOrWhiteSpace($srcName)) {
        Write-Host "  [跳过] 存在未提供 filename 的条目" -ForegroundColor Gray
        $skipped++
        continue
    }

    if (Should-SkipMatch -RefName $dstName) {
        Write-Host "  [跳过] 图片 $srcName 标记为无匹配或多余" -ForegroundColor Gray
        $skipped++
        continue
    }

    if ($confidence -in @("medium", "low")) {
        Write-Host "  [跳过-$confidence] 图片 $srcName 置信度为 $confidence，保留原名且不复制" -ForegroundColor Gray
        $skipped++
        $lowConfidenceSkipped++
        continue
    }

    if ($confidence -eq "missing") {
        Write-Host "  [警告] 图片 $srcName 未提供 confidence，按高置信度兼容处理" -ForegroundColor Yellow
        $missingConfidenceProcessed++
    } elseif ($confidence -ne "high") {
        Write-Host "  [跳过-$confidence] 图片 $srcName 置信度不支持自动应用，保留原名且不复制" -ForegroundColor Gray
        $skipped++
        continue
    }

    if ($multiAssigned.ContainsKey($dstName)) {
        Write-Host "  [冲突] 目标文件名 $dstName 被映射到多张图片" -ForegroundColor Red
        $failed++
        continue
    }
    $multiAssigned[$dstName] = $true

    $srcPath = Join-Path $downloadDir $srcName
    $dstPath = Join-Path $downloadDir $dstName

    if (Test-Path -LiteralPath $srcPath) {
        if ($srcName -eq $dstName) {
            Write-Host "  [OK-原名一致] $dstName" -ForegroundColor Gray
            $matched++
            $filesToCopy[$dstName] = $srcPath
            continue
        }

        $pendingRenames += [PSCustomObject]@{
            SrcName  = $srcName
            DstName  = $dstName
            SrcPath  = $srcPath
            DstPath  = $dstPath
            TempName = $null
            TempPath = $null
            Skip     = $false
        }
        continue
    }

    if (Test-Path -LiteralPath $dstPath) {
        Write-Host "  [OK-已重命名] $dstName (图片已在先前运行中重命名)" -ForegroundColor Gray
        $matched++
        $filesToCopy[$dstName] = $dstPath
        continue
    }

    Write-Host "  [错误] 找不到源图片: $srcName" -ForegroundColor Red
    $failed++
}

if ($pendingRenames.Count -gt 0) {
    $pendingSourceNames = @{}
    foreach ($item in $pendingRenames) {
        $pendingSourceNames[$item.SrcName] = $true
    }

    foreach ($item in $pendingRenames) {
        $dstExists = Test-Path -LiteralPath $item.DstPath
        $isPendingSource = $pendingSourceNames.ContainsKey($item.DstName)

        if ($dstExists -and -not $isPendingSource) {
            if ($Mode -eq "force") {
                Remove-Item -LiteralPath $item.DstPath -Force
                Write-Host "  [强制删除] 已移除现存目标文件: $($item.DstName)" -ForegroundColor Yellow
            } else {
                Write-Host "  [冲突-目标存在] $($item.SrcName) -> $($item.DstName)；当前模式 $Mode 不覆盖下载目录中的现存目标文件" -ForegroundColor Yellow
                $skipped++
                $item.Skip = $true
            }
        }
    }

    foreach ($item in $pendingRenames | Where-Object { -not $_.Skip }) {
        try {
            $item.TempName = Get-UniqueTempName -Directory $downloadDir -Extension ([System.IO.Path]::GetExtension($item.SrcName))
            $item.TempPath = Join-Path $downloadDir $item.TempName
            Rename-Item -LiteralPath $item.SrcPath -NewName $item.TempName -ErrorAction Stop
        } catch {
            Write-Host "  [失败] 临时改名失败 $($item.SrcName): $_" -ForegroundColor Red
            $failed++
            $item.Skip = $true
        }
    }

    foreach ($item in $pendingRenames | Where-Object { -not $_.Skip }) {
        try {
            if ((Test-Path -LiteralPath $item.DstPath) -and $Mode -eq "force") {
                Remove-Item -LiteralPath $item.DstPath -Force
            }

            Rename-Item -LiteralPath $item.TempPath -NewName $item.DstName -ErrorAction Stop
            Write-Host "  [OK] $($item.SrcName) -> $($item.DstName)" -ForegroundColor Green
            $matched++
            $filesToCopy[$item.DstName] = $item.DstPath
        } catch {
            Write-Host "  [失败] $($item.SrcName) -> $($item.DstName): $_" -ForegroundColor Red
            $failed++

            if ($item.TempPath -and (Test-Path -LiteralPath $item.TempPath)) {
                try {
                    Rename-Item -LiteralPath $item.TempPath -NewName $item.SrcName -ErrorAction Stop
                } catch {
                    Write-Host "  [警告] 回滚失败，临时文件仍在下载目录: $($item.TempName)" -ForegroundColor Yellow
                }
            }
        }
    }
}

Write-Host ""
Write-Host "==== 复制到 Attachments ====" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $attachDir)) {
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
        if ($Mode -eq "create") {
            continue
        }

        if ($Mode -in @("sync", "chain")) {
            $sameHash = (Get-FileHashSafe -Path $src) -eq (Get-FileHashSafe -Path $dst)
            if ($sameHash) {
                continue
            }
        }

        try {
            Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
            $copied++
        } catch {
            Write-Host "  [复制失败] ${name}: $_" -ForegroundColor Red
        }
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

Write-Host ""
Write-Host "==== 完成 ====" -ForegroundColor Cyan
Write-Host "  匹配/重命名成功: $matched"
Write-Host "  跳过: $skipped"
Write-Host "  失败: $failed"
Write-Host "  medium/low 跳过: $lowConfidenceSkipped"
Write-Host "  缺失 confidence 兼容处理: $missingConfidenceProcessed"
Write-Host "  复制到 Attachments: $copied 张"
