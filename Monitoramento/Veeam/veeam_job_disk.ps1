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

# Prioriza CorePath no binding de DLLs
$env:PATH = "$InstallPath;$env:PATH"

# Carrega assemblies principais do CorePath (mantém compatibilidade e evita mismatch)
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

# Importa módulo
Import-Module Veeam.Backup.PowerShell -ErrorAction Stop -WarningAction SilentlyContinue

# Busca jobs
$JOBS = Get-VBRJob -WarningAction SilentlyContinue

foreach ($JOB in $JOBS) {

    # Sessão pode ser null em jobs que nunca rodaram
    $JOBSESSION = $null
    try {
        $JOBSESSION = $JOB.FindLastSession()
    } catch {
        $JOBSESSION = $null
    }

    # ScheduleOptions pode ser null em alguns tipos de job
    $SCHEDULE = $null
    try {
        $SCHEDULE = $JOB.ScheduleOptions
    } catch {
        $SCHEDULE = $null
    }

    if ($null -ne $JOBSESSION -and $null -ne $JOBSESSION.JobName) {

        # Proteção para propriedades que podem não existir em todos os job types
        $OptionsDailyEnabled = $null
        $OptionsDailyKind    = $null
        $OptionsDailyDays    = $null
        $StartDateTimeLocal  = $null
        $OptionsMonthlyEnabled = $null
        $OptionsMonthly        = $null
        $OptionsPeriodicallyEnabled = $null

        if ($null -ne $SCHEDULE) {
            $StartDateTimeLocal = $SCHEDULE.StartDateTimeLocal

            if ($null -ne $SCHEDULE.OptionsDaily) {
                $OptionsDailyEnabled = $SCHEDULE.OptionsDaily.Enabled
                $OptionsDailyKind    = $SCHEDULE.OptionsDaily.Kind
                $OptionsDailyDays    = $SCHEDULE.OptionsDaily.DaysSrv
            }

            if ($null -ne $SCHEDULE.OptionsMonthly) {
                $OptionsMonthlyEnabled = $SCHEDULE.OptionsMonthly.Enabled
                $OptionsMonthly = $SCHEDULE.OptionsMonthly | Select-Object DayOfMonth, DayNumberInMonth, DayOfWeek
            }

            if ($null -ne $SCHEDULE.OptionsPeriodically) {
                $OptionsPeriodicallyEnabled = $SCHEDULE.OptionsPeriodically.Enabled
            }
        }

        #RuntimeSeconds
        $RuntimeSeconds = 0
        if ($JOBSESSION.CreationTime -and $JOBSESSION.EndTime -and $JOBSESSION.EndTime -gt $JOBSESSION.CreationTime) {
            $RuntimeSeconds = [int](($JOBSESSION.EndTime - $JOBSESSION.CreationTime).TotalSeconds)
        }

        [PSCustomObject]@{
            JobName                    = $JOBSESSION.JobName
            ScheduleEnabled            = $JOB.IsScheduleEnabled
            OptionsDailyEnabled        = $OptionsDailyEnabled
            OptionsDailyKind           = $OptionsDailyKind
            OptionsDailyDays           = $OptionsDailyDays
            StartDateTimeLocal         = $StartDateTimeLocal
            OptionsMonthlyEnabled      = $OptionsMonthlyEnabled
            OptionsMonthly             = $OptionsMonthly
            OptionsPeriodicallyEnabled = $OptionsPeriodicallyEnabled
            Platform                   = $JOBSESSION.Platform
            JobTypeString              = $JOBSESSION.JobTypeString
            CreationTime               = $JOBSESSION.CreationTime
            EndTime                    = $JOBSESSION.EndTime
            State                      = $JOBSESSION.State
            BaseProgress               = $JOBSESSION.BaseProgress
            Result                     = $JOBSESSION.Result
            RuntimeSeconds             = $RuntimeSeconds
        }
    }
}