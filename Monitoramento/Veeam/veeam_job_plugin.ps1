# Garante output correto no PS7
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.OutputRendering = 'PlainText'
}

# CorePath pode estar em 64 ou WOW6432Node (dependendo do ambiente)
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

# Prioriza CorePath no binding de DLLs
$env:PATH = "$InstallPath;$env:PATH"

# Carrega assemblies principais do CorePath para evitar mismatch
$assemblies = @(
    "Veeam.Backup.Common.dll",
    "Veeam.Backup.Core.dll",
    "Veeam.Backup.Configuration.dll"
)

foreach ($asm in $assemblies) {
    $full = Join-Path $InstallPath $asm
    if (Test-Path $full) {
        [System.Reflection.Assembly]::LoadFrom($full) | Out-Null
    }
}

# Agora importa módulo
Import-Module Veeam.Backup.PowerShell -ErrorAction Stop -WarningAction SilentlyContinue

$PLUGINJOBS = Get-VBRPluginJob -WarningAction SilentlyContinue

foreach ($PLUGINJOB in $PLUGINJOBS) {

    $JOBSESSION = $null
    try {
        $JOBSESSION = [Veeam.Backup.Core.CBackupSession]::FindLastByJob($PLUGINJOB.Id)
    } catch {
        $JOBSESSION = $null
    }

    #RuntimeSeconds
    $RuntimeSeconds = 0
    if ($JOBSESSION.CreationTime -and $JOBSESSION.EndTime -and $JOBSESSION.EndTime -gt $JOBSESSION.CreationTime) {
        $RuntimeSeconds = [int](($JOBSESSION.EndTime - $JOBSESSION.CreationTime).TotalSeconds)
    }

    if ($null -ne $JOBSESSION) {
        [PSCustomObject]@{
            JobName         = $JOBSESSION.JobName
            ScheduleEnabled = $PLUGINJOB.IsEnabled
            Platform        = $JOBSESSION.Platform
            JobTypeString   = $JOBSESSION.JobTypeString
            CreationTime    = $JOBSESSION.CreationTime
            EndTime         = $JOBSESSION.EndTime
            State           = $JOBSESSION.State
            BaseProgress    = $JOBSESSION.BaseProgress
            Result          = $JOBSESSION.Result
            RuntimeSeconds  = $RuntimeSeconds
        }
    }
}