param(
    [Parameter(Mandatory=$true)]
    [string]$mdFilePath,

    [Parameter(Mandatory=$true)]
    [string]$outputJson,

    [Parameter(Mandatory=$false)]
    [string]$sectionMarker = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $mdFilePath)) {
    throw "MD 文件不存在: $mdFilePath"
}

$content = Get-Content -LiteralPath $mdFilePath -Raw -Encoding UTF8

# 0. 如果指定了 sectionMarker，先截取从 marker 之后的内容
if ($sectionMarker -ne "") {
    $idx = $content.IndexOf($sectionMarker)
    if ($idx -lt 0) {
        throw "未找到章节标记: $sectionMarker"
    }
    $content = $content.Substring($idx)
    Write-Host "[截取] 从 '$sectionMarker' 开始解析" -ForegroundColor Cyan
}

# 1. 提取 prompt 代码块（记录位置以进行顺序匹配）
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

# 2. 提取 ![[xxx.png]] 引用（记录位置以归属到对应的 prompt）
$refPattern = '!\[\[([^\]]+\.png)\]\]'
$refMatches = [regex]::Matches($content, $refPattern)
$refNamesList = @()
$nonStoryboardRefs = @()

foreach ($m in $refMatches) {
    $refName = $m.Groups[1].Value
    $refNamesList += $refName

    # 寻找在当前引用之前且最邻近的 prompt 块
    $parentStoryboard = $null
    for ($i = $storyboards.Count - 1; $i -ge 0; $i--) {
        if ($storyboards[$i].index -lt $m.Index) {
            $parentStoryboard = $storyboards[$i]
            break
        }
    }

    if ($parentStoryboard -ne $null) {
        $parentStoryboard.refNames += $refName
    } else {
        # 如果在第一个 prompt 之前，归为非分镜引用（例如封面图）
        $nonStoryboardRefs += $refName
    }
}

# 3. 校验
if ($storyboards.Count -eq 0) {
    throw "未从 MD 文档中找到任何 prompt 代码块。请确认代码块使用 ```prompt 标识符。"
}

Write-Host "==== MD 解析完成 ====" -ForegroundColor Cyan
Write-Host "  分镜数: $($storyboards.Count)"
Write-Host "  图片引用总数: $($refNamesList.Count)"
Write-Host "  非分镜引用数: $($nonStoryboardRefs.Count)"

# 4. 输出 JSON
$result = @{
    mdPath            = $mdFilePath
    shotCount         = $storyboards.Count
    prompts           = $promptsList
    refNames          = $refNamesList
    storyboards       = $storyboards
    nonStoryboardRefs = $nonStoryboardRefs
}

# 转换并写入文件，确保使用 UTF8 编码
$json = $result | ConvertTo-Json -Depth 10
$json | Out-File -FilePath $outputJson -Encoding UTF8

Write-Host "  输出: $outputJson"
