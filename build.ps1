# 设置版本变量
$VERSION = "0.0.6"

# 设置工作目录
$WORKDIR = "d:\myima\dify-plugins\dify-plugin-daemon"
Set-Location $WORKDIR

Write-Host "开始构建 dify-plugin-daemon..." -ForegroundColor Cyan

# 检查 Go 是否安装
if (-not (Get-Command "go" -ErrorAction SilentlyContinue)) {
    Write-Host "错误: 未找到 Go。请安装 Go 1.22 或更高版本。" -ForegroundColor Red
    exit 1
}

# 询问是否设置 HTTP 代理
$useProxy = Read-Host "是否设置 HTTP 代理？(Y/n)，默认使用"
if ($useProxy -ne "n" -and $useProxy -ne "N") {
    $proxyAddress = Read-Host "请输入代理地址 (默认: http://127.0.0.1:10809)"
    if ([string]::IsNullOrEmpty($proxyAddress)) {
        $proxyAddress = "http://127.0.0.1:10809"
    }
    
    # 设置 HTTP 代理环境变量
    $env:HTTP_PROXY = $proxyAddress
    $env:HTTPS_PROXY = $proxyAddress
    
    Write-Host "HTTP 代理已设置为: $proxyAddress" -ForegroundColor Green
}

# 构建 Go 应用
Write-Host "正在构建 Go 应用..." -ForegroundColor Cyan
$BUILD_TIME = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$GO_BUILD_CMD = "go build -ldflags `"-X 'github.com/langgenius/dify-plugin-daemon/internal/manifest.VersionX=$VERSION' -X 'github.com/langgenius/dify-plugin-daemon/internal/manifest.BuildTimeX=$BUILD_TIME'`" -o $WORKDIR\main.exe $WORKDIR\cmd\server\main.go"

Invoke-Expression $GO_BUILD_CMD

if (-not (Test-Path "$WORKDIR\main.exe")) {
    Write-Host "构建失败: 未生成可执行文件" -ForegroundColor Red
    exit 1
}

Write-Host "Go 应用构建成功!" -ForegroundColor Green

# 检查 Python 是否安装
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    Write-Host "警告: 未找到 Python。某些功能可能无法正常工作。" -ForegroundColor Yellow
}
else {
    $PYTHON_VERSION = python --version
    Write-Host "检测到 $PYTHON_VERSION" -ForegroundColor Cyan
    
    # 安装 dify_plugin 和相关依赖
    Write-Host "正在安装 Python 依赖..." -ForegroundColor Cyan
    
    # 设置 tiktoken 缓存目录
    $env:TIKTOKEN_CACHE_DIR = "$WORKDIR\.tiktoken"
    
    # 设置 UV 使用复制模式而不是硬链接
    $env:UV_LINK_MODE = "copy"
    
    # 安装 uv (如果需要)
    python -m pip install uv
    
    # 使用 uv 安装 dify_plugin，添加 --force-reinstall 参数覆盖现有安装
    Write-Host "正在安装 dify_plugin..." -ForegroundColor Cyan
    python -m uv pip install --force-reinstall dify_plugin
    
    # 预加载 tiktoken
    Write-Host "正在预加载 tiktoken..." -ForegroundColor Cyan
    python -c "import tiktoken; tiktoken.get_encoding('gpt2').special_tokens_set; tiktoken.get_encoding('cl100k_base').special_tokens_set"
}

# 创建启动脚本
$ENTRYPOINT_SCRIPT = @"
# 设置环境变量
`$env:PLATFORM = "local"
`$env:GIN_MODE = "release"

# 启动服务器
Write-Host "正在启动 dify-plugin-daemon 服务..." -ForegroundColor Green
$WORKDIR\main.exe
"@

Set-Content -Path "$WORKDIR\start.ps1" -Value $ENTRYPOINT_SCRIPT

Write-Host "构建完成! 使用以下命令启动服务:" -ForegroundColor Green
Write-Host ".\start.ps1" -ForegroundColor Yellow