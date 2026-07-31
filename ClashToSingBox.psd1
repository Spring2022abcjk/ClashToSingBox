@{
    RootModule        = 'ClashToSingBox.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '0d8979a4-06bb-45b7-8f14-52cb14a59d99'
    Author            = 'petaljoe_'
    CompanyName       = 'petaljoe_'
    Copyright         = 'Copyright (c) 2026 petaljoe_. Licensed under the MIT License.'
    Description       = 'PowerShell module for converting Clash YAML proxy nodes to sing-box JSON outbounds.'
    PowerShellVersion = '7.0'
    RequiredModules   = @(
        @{
            ModuleName    = 'powershell-yaml'
            ModuleVersion = '0.4.12'
        }
    )

    FunctionsToExport = @(
        'Convert-ProxyNodes'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags       = @(
                'Clash',
                'sing-box',
                'Proxy',
                'YAML',
                'JSON',
                'PowerShell'
            )
            ProjectUri   = 'https://github.com/Spring2022abcjk/ClashToSingBox'
            LicenseUri   = 'https://github.com/Spring2022abcjk/ClashToSingBox/blob/main/LICENSE'
            ReleaseNotes = 'Version 1.0.0: stable conversion support for VMess, Shadowsocks, Trojan, VLESS, and AnyTLS with sparse sing-box outbound output.'
        }
    }
}
