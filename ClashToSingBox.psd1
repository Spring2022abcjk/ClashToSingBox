@{
    RootModule        = 'ClashToSingBox.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '0d8979a4-06bb-45b7-8f14-52cb14a59d99'
    Author            = 'petaljoe_'
    CompanyName       = 'petaljoe_'
    Copyright         = 'Copyright (c) 2026 petaljoe_. Licensed under the MIT License.'
    Description       = 'PowerShell module for converting Clash YAML proxy nodes to sing-box JSON outbounds.'
    PowerShellVersion = '7.0'

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
            ReleaseNotes = 'Initial module manifest for local installation and future PSResource publishing.'
        }
    }
}
