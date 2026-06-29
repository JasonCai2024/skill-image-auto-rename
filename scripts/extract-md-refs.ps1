param(
    [Parameter(Mandatory = $true)]
    [string]$mdFilePath,

    [Parameter(Mandatory = $true)]
    [string]$outputJson,

    [Parameter(Mandatory = $false)]
    [string]$sectionMarker = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-Utf8Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.File]::ReadAllText($Path, $utf8NoBom)
}

function Write-Utf8Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

if (-not (Test-Path -LiteralPath $mdFilePath)) {
    throw "MD 文件不存在: $mdFilePath"
}

$content = Read-Utf8Text -Path $mdFilePath

if ($sectionMarker -ne "") {
    $idx = $content.IndexOf($sectionMarker)
    if ($idx -lt 0) {
        throw "未找到章节标记: $sectionMarker"
    }

    $content = $content.Substring($idx)
    Write-Host "[截取] 从 '$sectionMarker' 开始解析" -ForegroundColor Cyan
}

$promptPattern = '```prompt\s*([\s\S]*?)```'
$promptMatches = [regex]::Matches($content, $promptPattern)
$promptsList = @()
$storyboards = @()

$shotIdx = 1
foreach ($m in $promptMatches) {
    $promptText = $m.Groups[1].Value.Trim()
    $promptsList += $promptText
    $storyboards += [PSCustomObject]@{
        shotIndex = $shotIdx
        index     = $m.Index
        prompt    = $promptText
        refNames  = @()
    }
    $shotIdx++
}

$refPattern = '!\[\[([^\]]+\.png)\]\]'
$refMatches = [regex]::Matches($content, $refPattern)
$refNamesList = @()
$nonStoryboardRefs = @()

foreach ($m in $refMatches) {
    $refName = $m.Groups[1].Value
    $refNamesList += $refName

    $parentStoryboard = $null
    for ($i = $storyboards.Count - 1; $i -ge 0; $i--) {
        if ($storyboards[$i].index -lt $m.Index) {
            $parentStoryboard = $storyboards[$i]
            break
        }
    }

    if ($null -ne $parentStoryboard) {
        $parentStoryboard.refNames += $refName
    } else {
        $nonStoryboardRefs += $refName
    }
}

if ($storyboards.Count -eq 0) {
    throw "未从 MD 文档中找到任何 prompt 代码块。请确认使用 ```prompt 标识符。"
}

Write-Host "==== MD 解析完成 ====" -ForegroundColor Cyan
Write-Host "  分镜数: $($storyboards.Count)"
Write-Host "  图片引用总数: $($refNamesList.Count)"
Write-Host "  非分镜引用数: $($nonStoryboardRefs.Count)"

$result = @{
    mdPath            = $mdFilePath
    shotCount         = $storyboards.Count
    prompts           = $promptsList
    refNames          = $refNamesList
    storyboards       = $storyboards
    nonStoryboardRefs = $nonStoryboardRefs
}

$json = $result | ConvertTo-Json -Depth 10
Write-Utf8Text -Path $outputJson -Content $json

Write-Host "  输出: $outputJson"
