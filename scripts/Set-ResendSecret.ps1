[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryPath = Split-Path -Parent $PSScriptRoot
$environmentPath = Join-Path $repositoryPath '.env.local'

if (-not (Test-Path -LiteralPath $environmentPath)) {
    throw '.env.local is required. Pull the Neon child-branch environment before configuring Resend.'
}

$secureToken = Read-Host 'Paste the Resend API key (input hidden)' -AsSecureString
$developmentRecipient = (Read-Host 'Resend account email for development delivery').Trim().ToLowerInvariant()
try {
    $parsedRecipient = [Net.Mail.MailAddress]::new($developmentRecipient)
}
catch {
    throw 'Enter the email address used by your Resend account.'
}
if (-not $parsedRecipient.Address.Equals($developmentRecipient, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Enter the email address used by your Resend account.'
}
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
try {
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    if ([string]::IsNullOrWhiteSpace($token) -or -not $token.StartsWith('re_', [StringComparison]::Ordinal)) {
        throw 'The Resend API key must start with re_.'
    }

    $lines = [Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -LiteralPath $environmentPath) {
        if ($line -notmatch '^\s*(RESEND_APITOKEN|Email__Enabled|Email__DevelopmentRecipient)\s*=') {
            $lines.Add($line)
        }
    }
    $lines.Add("RESEND_APITOKEN=$token")
    $lines.Add('Email__Enabled=true')
    $lines.Add("Email__DevelopmentRecipient=$developmentRecipient")
    [IO.File]::WriteAllLines($environmentPath, $lines, [Text.UTF8Encoding]::new($false))
}
finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    $token = $null
    $secureToken.Dispose()
}

Write-Host 'Resend email delivery is enabled in the ignored .env.local file. Restart both API containers.'
