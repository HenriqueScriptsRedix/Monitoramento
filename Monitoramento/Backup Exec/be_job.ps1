[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Import-Module BEMCLI -ErrorAction Stop

$hist = Get-BEJobHistory -Jobtype Backup -FromLastJobRun
$histByName = @{}
foreach ($h in $hist) { if ($h.Name) { $histByName[$h.Name] = $h } }

$active = @()
try { $active = Get-BEActiveJobDetail } catch { $active = @() }

$activeByName = @{}
foreach ($a in $active) {

    $n = $null

    if ($a.PSObject.Properties.Name -contains 'JobName') { $n = $a.JobName }
    elseif ($a.PSObject.Properties.Name -contains 'Name') { $n = $a.Name }

    if ($n -and -not $activeByName.ContainsKey($n)) { $activeByName[$n] = $a }

}

$jobs = Get-BEJob

foreach ($job in $jobs) {

    if (-not $job.Name) { continue }

    # >>> FILTRO: ignora qualquer coisa que NÃO seja BACKUP (ex.: Restore)
    if ($job.JobType -ne 'Backup') { continue }

    # ScheduleEnabled (inferido pelo Status)
    $scheduleEnabled = ($job.Status -notmatch 'Unscheduled|Disabled|NotScheduled')

    # Last run (history)
    $h = $null
    if ($histByName.ContainsKey($job.Name)) { $h = $histByName[$job.Name] }

    $start  = if ($h) { $h.StartTime } else { $null }
    $end    = if ($h) { $h.EndTime } else { $null }
    $result = if ($h) { $h.JobStatus } else { $null }

    $runtime = 0
    if ($start -and $end -and $end -gt $start) {
        $runtime = [int]([TimeSpan]($end - $start)).TotalSeconds
    }

    # Frequence (inferido pelo Schedule)
    $frequence = 'Other'
    $scheduleText = [string]$job.Schedule
    if ($scheduleText -match 'Every 1 month') {
        $frequence = 'Monthly'
    }
    elseif ($scheduleText -match 'Every 1 day') {
        $frequence = 'Daily'
    }
    elseif ($scheduleText -match 'Every 1 week') {
        $frequence = 'Weekly'
    }

    # Active state/progress
    $state = $result
    $progress = $null
    if ($activeByName.ContainsKey($job.Name)) {

        $a = $activeByName[$job.Name]

        if ($a.PSObject.Properties.Name -contains 'State') { $state = $a.State }
        elseif ($a.PSObject.Properties.Name -contains 'Status') { $state = $a.Status }
        else { $state = 'Running' }

        if ($a.PSObject.Properties.Name -contains 'BaseProgress') { $progress = $a.BaseProgress }
        elseif ($a.PSObject.Properties.Name -contains 'Progress') { $progress = $a.Progress }
        elseif ($a.PSObject.Properties.Name -contains 'PercentComplete') { $progress = $a.PercentComplete }
         
        if ($state -eq 'Running') { $result = 'Running' }

    }

    # Output final
    [PSCustomObject]@{
        JobName          = $job.Name
        ScheduleEnabled  = $scheduleEnabled
        Schedule         = $job.Schedule
        Frequence        = $frequence
        NextStartDate    = $job.NextStartDate
        JobTypeString    = $job.JobType
        TaskType         = $job.TaskType
        StartTime        = $start
        EndTime          = $end
        State            = $state
	    Status 		 = $job.Status
        BaseProgress     = $progress
        Result           = $result
        RuntimeSeconds   = $runtime
        IsActive         = $job.IsActive
        SubStatus        = $job.SubStatus
        Priority         = $job.Priority
        Storage          = $job.Storage
    }

}