@{
    # Repository policy: every diagnostic returned at these severities is
    # blocking. Local checks and CI must use this settings file explicitly.
    Severity = @(
        'Error'
        'Warning'
        'Information'
    )

    ExcludeRules = @(
        # PowerShell 7 reads UTF-8 without a BOM reliably; keep repository text
        # files aligned with the cross-platform UTF-8 convention.
        'PSUseBOMForUnicodeEncodedFile'

        # Convert-ProxyNodes is the established public API and accurately
        # describes that the command converts a collection of proxy nodes.
        'PSUseSingularNouns'

        # New-Shared*Config functions only construct in-memory values and do
        # not change external state.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
