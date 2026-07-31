. (Join-Path $PSScriptRoot "Classes\ProxyNode.ps1")

# 加载私有工具
. (Join-Path $PSScriptRoot "Private\Parser.ps1")
. (Join-Path $PSScriptRoot "Private\Validation.Shared.ps1")
. (Join-Path $PSScriptRoot "Private\Validators\Vmess.Validator.ps1")
. (Join-Path $PSScriptRoot "Private\Validators\Shadowsocks.Validator.ps1")
. (Join-Path $PSScriptRoot "Private\Validators\Trojan.Validator.ps1")
. (Join-Path $PSScriptRoot "Private\Validators\Vless.Validator.ps1")
. (Join-Path $PSScriptRoot "Private\Validators\AnyTls.Validator.ps1")
. (Join-Path $PSScriptRoot "Private\Validator.ps1")
. (Join-Path $PSScriptRoot "Private\Converter.ps1")

# 加载公有函数
. (Join-Path $PSScriptRoot "Public\Convert-ProxyNodes.ps1")

# 导出命令
Export-ModuleMember -Function Convert-ProxyNodes
