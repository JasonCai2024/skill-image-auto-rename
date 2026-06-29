param(
    [Parameter(Mandatory = $true)]
    [string]$downloadDir,

    [Parameter(Mandatory = $true)]
    [string]$outputJson,

    [Parameter(Mandatory = $false)]
    [string]$username = $env:SERVICETUBER_USERNAME,

    [Parameter(Mandatory = $false)]
    [string]$passtoken = $env:SERVICETUBER_PASSTOKEN,

    [Parameter(Mandatory = $false)]
    [string]$baseUrl = $null,

    [Parameter(Mandatory = $false)]
    [string]$endpoint = "/api/llm/paid-rotation",

    [Parameter(Mandatory = $false)]
    [string]$provider = "minimax",

    [Parameter(Mandatory = $false)]
    [string]$model = "MiniMax-M3",

    [Parameter(Mandatory = $false)]
    [string]$imageFilter = "^ChatGPT Image ",

    [Parameter(Mandatory = $false)]
    [int]$maxRetry = 3,

    [Parameter(Mandatory = $false)]
    [int]$retrySleepMs = 3000,

    [Parameter(Mandatory = $false)]
    [int]$sleepMs = 500,

    [Parameter(Mandatory = $false)]
    [switch]$DisableMmxFallback
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

if ([string]::IsNullOrEmpty($username)) {
    throw "未提供用户名。请在参数中传入 -username 或配置环境变量 SERVICETUBER_USERNAME。"
}

if ([string]::IsNullOrEmpty($passtoken)) {
    throw "未提供凭证。请在参数中传入 -passtoken 或配置环境变量 SERVICETUBER_PASSTOKEN。"
}

if ([string]::IsNullOrEmpty($baseUrl)) {
    $baseUrl = if ($env:SERVICETUBER_BASE_URL) { $env:SERVICETUBER_BASE_URL } else { "https://www.ccailab.top" }
}

if (-not (Test-Path -LiteralPath $downloadDir)) {
    throw "下载文件夹不存在: $downloadDir"
}

$mmxScriptPath = Join-Path $PSScriptRoot "recognize-images.ps1"
if (-not (Test-Path -LiteralPath $mmxScriptPath)) {
    throw "缺少 mmx fallback 脚本: $mmxScriptPath"
}

Write-Host "==== ServiceHub 兼容包装器 ====" -ForegroundColor Cyan
Write-Host "  下载文件夹: $downloadDir"
Write-Host "  配置端点: $baseUrl$endpoint"
Write-Host "  配置 provider/model: $provider / $model"
Write-Host "  状态: 当前自动回退到 mmx CLI" -ForegroundColor Yellow
Write-Host "  原因: 2026-06-30 实测同一端点对纯文本 user_prompt 返回 200，但对历史多模态数组 + base64 图片请求返回 422。" -ForegroundColor Yellow
Write-Host "  备注: maxRetry/retrySleepMs 目前仅保留为兼容参数，回退路径不再使用它们。" -ForegroundColor Gray

if ($DisableMmxFallback) {
    throw "当前 ServiceHub / paid-rotation 端点与本技能历史多模态请求格式不兼容。请改用 scripts/recognize-images.ps1，或等 ServiceHub 提供可用的图片上传 + URL 工作流后再恢复。"
}

Write-Host "  动作: 调用 scripts/recognize-images.ps1" -ForegroundColor Cyan
& $mmxScriptPath -downloadDir $downloadDir -outputJson $outputJson -sleepMs $sleepMs -imageFilter $imageFilter
