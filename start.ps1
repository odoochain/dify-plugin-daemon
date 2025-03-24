# 设置环境变量
$env:PLATFORM = "local"
$env:GIN_MODE = "release"

# 启动服务器
Write-Host "正在启动 dify-plugin-daemon 服务..." -ForegroundColor Green
d:\myima\dify-plugins\dify-plugin-daemon\main.exe
