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
    [string]$taskType = "text_arrange",

    [Parameter(Mandatory = $false)]
    [string]$imageFilter = "^ChatGPT Image ",

    [Parameter(Mandatory = $false)]
    [int]$maxRetry = 3,

    [Parameter(Mandatory = $false)]
    [int]$retrySleepMs = 3000,

    [Parameter(Mandatory = $false)]
    [int]$sleepMs = 500,

    [Parameter(Mandatory = $false)]
    [switch]$UseMmxFallback
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8Json {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        $Value
    )

    $json = $Value | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = [System.IO.File]::ReadAllText($Path, $utf8NoBom)
    return $text | ConvertFrom-Json
}

function Get-ImageMediaType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Extension
    )

    $ext = $Extension.ToLowerInvariant()
    if ($ext -eq ".png") { return "image/png" }
    if ($ext -eq ".jpg") { return "image/jpeg" }
    if ($ext -eq ".jpeg") { return "image/jpeg" }
    if ($ext -eq ".webp") { return "image/webp" }
    if ($ext -eq ".gif") { return "image/gif" }

    throw "Unsupported image extension: $Extension"
}

function Invoke-ServiceHubVision {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$ImageFile
    )

    $bytes = [System.IO.File]::ReadAllBytes($ImageFile.FullName)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $mediaType = Get-ImageMediaType -Extension $ImageFile.Extension
    $dataUri = "data:{0};base64,{1}" -f $mediaType, $base64
    $promptText = "Describe the image with: 1. main subject 2. pose/action 3. facial expression 4. background/props 5. color/style. If visible text exists, include it briefly."

    $userPrompt = @(
        @{
            type = "text"
            text = $promptText
        },
        @{
            type = "image_url"
            image_url = @{
                url = $dataUri
            }
        }
    )

    $payload = @{
        username = $username
        passtoken = $passtoken
        provider = $provider
        model = $model
        task_type = $taskType
        user_prompt = $userPrompt
    }

    $uri = $baseUrl.TrimEnd("/") + $endpoint
    $body = $payload | ConvertTo-Json -Depth 12
    $lastErrorMessage = $null

    for ($attempt = 1; $attempt -le $maxRetry; $attempt++) {
        try {
            return Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json; charset=utf-8" -Body $body
        } catch {
            $responseText = $null

            if ($_.Exception.Response) {
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    if ($stream) {
                        $reader = New-Object System.IO.StreamReader($stream)
                        $responseText = $reader.ReadToEnd()
                        $reader.Dispose()
                    }
                } catch {
                }
            }

            if ($responseText) {
                $lastErrorMessage = "$($_.Exception.Message) | response=$responseText"
            } else {
                $lastErrorMessage = "$_"
            }

            if ($attempt -lt $maxRetry) {
                Start-Sleep -Milliseconds $retrySleepMs
            }
        }
    }

    throw "ServiceHub call failed: $lastErrorMessage"
}

if ([string]::IsNullOrEmpty($username)) {
    throw "Missing username. Use -username or SERVICETUBER_USERNAME."
}

if ([string]::IsNullOrEmpty($passtoken)) {
    throw "Missing passtoken. Use -passtoken or SERVICETUBER_PASSTOKEN."
}

if ([string]::IsNullOrEmpty($baseUrl)) {
    if ($env:SERVICETUBER_BASE_URL) {
        $baseUrl = $env:SERVICETUBER_BASE_URL
    } else {
        $baseUrl = "https://www.ccailab.top"
    }
}

if (-not (Test-Path -LiteralPath $downloadDir)) {
    throw "Download directory not found: $downloadDir"
}

$mmxScriptPath = Join-Path $PSScriptRoot "recognize-images.ps1"
if ($UseMmxFallback -and -not (Test-Path -LiteralPath $mmxScriptPath)) {
    throw "Missing mmx fallback script: $mmxScriptPath"
}

$images = Get-ChildItem -LiteralPath $downloadDir -File |
    Where-Object {
        $_.Extension -match "^\.(png|jpg|jpeg|webp|gif)$" -and $_.Name -match $imageFilter
    } |
    Sort-Object LastWriteTime

if ($images.Count -eq 0) {
    throw "No matching image files in: $downloadDir"
}

$results = @()
$done = @()
if (Test-Path -LiteralPath $outputJson) {
    try {
        $existing = Read-JsonFile -Path $outputJson
        if ($existing.images) {
            $results = @($existing.images)
            $done = @($existing.images | ForEach-Object { $_.filename })
            Write-Host ("  Resume from existing output: {0} done" -f $done.Count) -ForegroundColor Yellow
        }
    } catch {
        Write-Host ("  Warning: existing JSON unreadable, overwrite: {0}" -f $outputJson) -ForegroundColor Yellow
        $results = @()
        $done = @()
    }
}

$remaining = $images | Where-Object { $_.Name -notin $done }

Write-Host "==== Start image recognition via ServiceHub ====" -ForegroundColor Cyan
Write-Host ("  Endpoint: {0}{1}" -f $baseUrl.TrimEnd("/"), $endpoint)
Write-Host ("  Provider/Model: {0} / {1}" -f $provider, $model)
Write-Host ("  Total: {0}" -f $images.Count)
Write-Host ("  Remaining: {0}" -f $remaining.Count)

if ($UseMmxFallback) {
    Write-Host "  Fallback: mmx CLI enabled" -ForegroundColor Yellow
}

if ($remaining.Count -eq 0) {
    Write-Host "  Complete: nothing left to process" -ForegroundColor Green
    return
}

$idx = $results.Count + 1
foreach ($img in $remaining) {
    Write-Host ("  [{0}/{1}] {2}" -f $idx, $images.Count, $img.Name) -ForegroundColor Yellow

    try {
        $response = Invoke-ServiceHubVision -ImageFile $img
        $desc = "$($response.data.processed_text)".Trim()
        if ([string]::IsNullOrWhiteSpace($desc)) {
            throw "processed_text is empty"
        }

        $results += @{
            index = $idx
            filename = $img.Name
            description = $desc
            provider = "servicehub/$provider"
            model = $model
        }

        Write-Host ("    {0}" -f $desc.Substring(0, [Math]::Min(60, $desc.Length))) -ForegroundColor Gray
    } catch {
        if ($UseMmxFallback) {
            Write-Host ("    ServiceHub failed, fallback to mmx: {0}" -f $_) -ForegroundColor Yellow
            try {
                $fallbackPrompt = "Describe the image with: 1. main subject 2. pose/action 3. facial expression 4. background/props 5. color/style."
                $json = & mmx vision describe --image $img.FullName --prompt $fallbackPrompt --output json --quiet 2>$null
                $r = $json | ConvertFrom-Json
                $desc = "$($r.content)".Trim()

                $results += @{
                    index = $idx
                    filename = $img.Name
                    description = $desc
                    provider = "mmx-fallback"
                    model = "mmx"
                }
            } catch {
                Write-Host ("    Failed: {0}" -f $_) -ForegroundColor Red
                $results += @{
                    index = $idx
                    filename = $img.Name
                    description = ""
                    error = "$_"
                }
            }
        } else {
            Write-Host ("    Failed: {0}" -f $_) -ForegroundColor Red
            $results += @{
                index = $idx
                filename = $img.Name
                description = ""
                error = "$_"
            }
        }
    }

    $partial = @{
        downloadDir = $downloadDir
        imageCount = $images.Count
        progress = $idx
        images = $results
    }
    Write-Utf8Json -Path $outputJson -Value $partial

    $idx++
    Start-Sleep -Milliseconds $sleepMs
}

$result = @{
    downloadDir = $downloadDir
    imageCount = $images.Count
    images = $results
}
Write-Utf8Json -Path $outputJson -Value $result

Write-Host ""
Write-Host "==== Recognition complete ====" -ForegroundColor Cyan
Write-Host ("  Total: {0}" -f $images.Count)
Write-Host ("  Success: {0}" -f (@($results | Where-Object { -not $_.error }).Count))
Write-Host ("  Failed: {0}" -f (@($results | Where-Object { $_.error }).Count))
Write-Host ("  Output: {0}" -f $outputJson)
