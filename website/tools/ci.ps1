# @static-doc
# 作用：官网本地 CI：构建生产镜像，以生产资源限制跑容器冒烟，通过后用 Docker Compose 部署到本机。
#
# ## 契约与约束
# - 只在本地构建/测试/部署，不推任何 registry；镜像默认标签 `steam-navigator-website:local`。
# - 冒烟容器必须使用与生产一致的约束：read-only rootfs、32 MB 内存、0.25 CPU、丢弃 capabilities。
# - 冒烟覆盖 `/healthz`、首页、游戏信息、百科、CSS、404、gzip 与缓存头；任一项失败则不部署。
# - 部署使用 `website/docker-compose.yml`，更新 `website` + `site-api`（只读内容 API）服务；Cloudflare Tunnel 另行启动。
# - 构建前先跑 `node website/tools/build-release-data.mjs`：从 GitHub Releases API 刷新版本数据
#   （下载页 / 开发日志页的版本号、日期、大小、直链），网络失败时保留上一次生成的文件；
#   `-SkipReleaseData` 可跳过（离线构建）。
# - 不修改站点内容（除生成数据外），不触碰 `dev_mods/`；可从任意工作目录运行。
#
# ## 重点逻辑
# ### 先测后部署
# - 先用临时容器在 `-SmokePort`（默认 18080）验证镜像，再执行
#   `docker compose -f website/docker-compose.yml up -d --build website site-api`。
# ### 清理
# - 冒烟容器在 `finally` 中删除；部署后的健康检查失败会以非零退出码结束。
# @end-static-doc

[CmdletBinding()]
param(
    [int]$SmokePort = 18080,
    [switch]$SkipSmoke,
    [switch]$SkipDeploy,
    [switch]$SkipReleaseData
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Image = "steam-navigator-website:local"
$ComposeFile = Join-Path $Root "website/docker-compose.yml"
$Container = "sn-website-ci-$PID"
$NullDevice = if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) { "/dev/null" } else { "NUL" }

function Invoke-Docker {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    # Windows PowerShell 5.1: docker 的进度/警告写入 stderr，EAP=Stop 会把它误判为终止错误。
    # 临时降级 EAP，只用退出码判断成败。
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & docker @Arguments
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($LASTEXITCODE -ne 0) {
        throw "docker $($Arguments -join ' ') failed (exit $LASTEXITCODE)"
    }
}

function Wait-Healthy {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$TimeoutSeconds = 30
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2
            if ($response.StatusCode -eq 200 -and $response.Content.Trim() -eq "ok") {
                return $true
            }
        } catch {
            # 容器尚未就绪
        }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "未找到 docker，请先启动 Docker Desktop / Docker Engine。"
}
& docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
    throw "未找到 docker compose（需要 Docker Compose v2）。"
}

Set-Location $Root

if (-not $SkipReleaseData) {
    Write-Host "==> 同步 GitHub 最新 Release 版本数据（网站版本号 / 下载链接）" -ForegroundColor Cyan
    & node website/tools/build-release-data.mjs
    if ($LASTEXITCODE -ne 0) {
        throw "release data generation failed (exit $LASTEXITCODE)；可加 -SkipReleaseData 跳过"
    }
}

Write-Host "==> 构建镜像 $Image" -ForegroundColor Cyan
Invoke-Docker -Arguments @("build", "-f", "website/deploy/Dockerfile", "-t", $Image, "website")

if (-not $SkipSmoke) {
    Write-Host "==> 冒烟测试（127.0.0.1:$SmokePort，32 MB / 只读 / 0.25 CPU）" -ForegroundColor Cyan
    & docker rm -f $Container 2>$null | Out-Null
    try {
        Invoke-Docker -Arguments @(
            "run", "-d", "--name", $Container,
            "-p", "127.0.0.1:${SmokePort}:8080",
            "--read-only",
            "--tmpfs", "/tmp:rw,noexec,nosuid,size=8m",
            "--memory", "32m",
            "--cpus", "0.25",
            "--pids-limit", "64",
            "--cap-drop", "ALL",
            "--security-opt", "no-new-privileges",
            $Image
        ) | Out-Null

        if (-not (Wait-Healthy -Url "http://127.0.0.1:$SmokePort/healthz")) {
            & docker logs $Container
            throw "冒烟容器未在 30 秒内就绪。"
        }

        $checks = @(
            @{ Name = "首页"; Url = "/"; Contains = "蒸汽航海" },
            @{ Name = "游戏信息"; Url = "/game.html"; Contains = "关于《蒸汽航海》" },
            @{ Name = "游戏百科"; Url = "/wiki.html"; Contains = "游戏百科" },
            @{ Name = "开发团队"; Url = "/team.html"; Contains = "开发团队" },
            @{ Name = "样式表"; Url = "/assets/css/site.css"; Contains = "site-header" },
            @{ Name = "版本数据"; Url = "/assets/data/release-data.js"; Contains = "SN_RELEASE_DATA" }
        )
        foreach ($check in $checks) {
            $body = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$SmokePort$($check.Url)" -TimeoutSec 5).Content
            if ($body -notlike "*$($check.Contains)*") {
                throw "冒烟失败：$($check.Name) 未包含预期内容。"
            }
        }

        $notFound = (& curl.exe -s -o $NullDevice -w "%{http_code}" "http://127.0.0.1:$SmokePort/does-not-exist").Trim()
        if ($notFound -ne "404") {
            throw "冒烟失败：未知路径返回 $notFound，预期 404。"
        }

        $htmlHeaders = (& curl.exe -sSI "http://127.0.0.1:$SmokePort/" | Out-String)
        if ($htmlHeaders -notmatch "(?i)cache-control:\s*no-cache") {
            throw "冒烟失败：HTML 未返回 Cache-Control: no-cache。"
        }

        $assetHeaders = (& curl.exe -sSI "http://127.0.0.1:$SmokePort/assets/img/hero-main.jpg" | Out-String)
        if ($assetHeaders -notmatch "(?i)cache-control:\s*max-age=604800") {
            throw "冒烟失败：静态资源未返回 7 天缓存。"
        }

        $releaseDataHeaders = (& curl.exe -sSI "http://127.0.0.1:$SmokePort/assets/data/release-data.js" | Out-String)
        if ($releaseDataHeaders -notmatch "(?i)cache-control:\s*no-cache") {
            throw "冒烟失败：版本数据未返回 Cache-Control: no-cache（部署后会显示旧版本）。"
        }

        $gzipHeaders = (& curl.exe -sSI -H "Accept-Encoding: gzip" "http://127.0.0.1:$SmokePort/assets/css/site.css" | Out-String)
        if ($gzipHeaders -notmatch "(?i)content-encoding:\s*gzip") {
            throw "冒烟失败：CSS 未启用 gzip。"
        }

        $memory = (& docker stats --no-stream --format "{{.MemUsage}}" $Container | Out-String).Trim()
        Write-Host "    冒烟通过；容器内存：$memory" -ForegroundColor Green
    } finally {
        & docker rm -f $Container 2>$null | Out-Null
    }
}

if (-not $SkipDeploy) {
    Write-Host "==> 部署到本机 Docker Compose" -ForegroundColor Cyan
    Invoke-Docker -Arguments @("compose", "-f", $ComposeFile, "up", "-d", "--build", "website", "site-api")

    $deployBinding = (& docker compose -f $ComposeFile port website 8080 2>$null | Out-String).Trim()
    if (-not $deployBinding) {
        & docker compose -f $ComposeFile logs --tail 80 website
        throw "无法读取 website 的宿主机端口映射。"
    }

    if (-not (Wait-Healthy -Url "http://$deployBinding/healthz")) {
        & docker compose -f $ComposeFile logs --tail 80 website
        throw "部署后的站点未在 30 秒内就绪。"
    }

    # site-api 通过 nginx 反代；等它 healthy 后确认 /api/site/release 可读（发版后网站的自动更新依赖它）。
    $apiDeadline = (Get-Date).AddSeconds(30)
    $apiReady = $false
    while ((Get-Date) -lt $apiDeadline) {
        try {
            $apiBody = (Invoke-WebRequest -UseBasicParsing -Uri "http://$deployBinding/api/site/release" -TimeoutSec 3).Content
            if ($apiBody -like '*"ok":true*') { $apiReady = $true; break }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $apiReady) {
        & docker compose -f $ComposeFile logs --tail 60 site-api
        & docker compose -f $ComposeFile logs --tail 60 website
        throw "部署后 /api/site/release 不可用；网站将无法自动获取最新版本。"
    }

    $stats = (& docker stats --no-stream --format "{{.Name}} {{.MemUsage}} {{.CPUPerc}}" steam-navigator-website steam-navigator-site-api | Out-String).Trim()
    Write-Host "==> 完成" -ForegroundColor Green
    Write-Host "    站点：http://$deployBinding/"
    Write-Host "    健康：http://$deployBinding/healthz"
    Write-Host "    版本 API：http://$deployBinding/api/site/release"
    Write-Host "    容器：$stats"
    Write-Host "    Cloudflare Tunnel：cd website; docker compose --profile tunnel up -d"
}

exit 0
