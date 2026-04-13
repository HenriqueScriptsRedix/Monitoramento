# Garante output correto no PS7
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.OutputRendering = 'PlainText'
}

# Localiza CorePath (64-bit e fallback WOW6432Node)
$regPaths = @(
    "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\",
    "HKLM:\SOFTWARE\WOW6432Node\Veeam\Veeam Backup and Replication\"
)

$InstallPath = $null
foreach ($path in $regPaths) {
    if (Test-Path $path) {
        $InstallPath = (Get-ItemProperty -Path $path -ErrorAction Stop).CorePath
        break
    }
}

if (-not $InstallPath) {
    throw "Não foi possível localizar o CorePath do Veeam no registro."
}

# Importante: garante que o CorePath é usado no binding de DLLs
$env:PATH = "$InstallPath;$env:PATH"

# Carrega as DLLs necessárias explicitamente (sem depender do módulo)
$assemblies = @(
    "Veeam.Backup.Configuration.dll",
    "Veeam.Backup.Common.dll"
)

foreach ($asm in $assemblies) {
    $full = Join-Path $InstallPath $asm
    if (Test-Path $full) {
        [System.Reflection.Assembly]::LoadFrom($full) | Out-Null
    }
}

# Agora importa o módulo
Import-Module Veeam.Backup.PowerShell -ErrorAction Stop -WarningAction SilentlyContinue

# Agora o tipo existe
$VEEAMPRODUCTINFO = [Veeam.Backup.Configuration.BackupProduct]::Create()
$VEEAMLICINFO = Get-VBRInstalledLicense

[PSCustomObject]@{
    DisplayName             = $VEEAMPRODUCTINFO.DisplayName
    ProductVersion          = $VEEAMPRODUCTINFO.ProductVersion
    MarketName              = $VEEAMPRODUCTINFO.MarketName
    Type                    = $VEEAMLICINFO.Type
    ExpirationDate          = $VEEAMLICINFO.ExpirationDate
    LicensedInstancesNumber = $VEEAMLICINFO.InstanceLicenseSummary.LicensedInstancesNumber
    UsedInstancesNumber     = $VEEAMLICINFO.InstanceLicenseSummary.UsedInstancesNumber
}