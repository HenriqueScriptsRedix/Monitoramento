param(
    [switch]$CPU,
    [switch]$MEM,
    [switch]$USER,
    [int]$Intervalo = 1
)

# ============================================================================
# 1) Coleta de sessões RDP via QWINSTA
# ============================================================================

function Get-RDPSessions {

    $raw = qwinsta.exe 2>$null
    if (-not $raw) { return @() }

    $raw = $raw | Select-Object -Skip 1
    $sessoes = @()

    foreach ($linha in $raw) {

        $linha = $linha.Trim()
        if (-not $linha) { continue }

        $norm  = ($linha -replace '\s+',' ')
        $parts = $norm.Split(' ')

        if ($parts.Count -eq 3 -and $parts[2] -eq 'Listen') { continue }
        if ($parts.Count -eq 3 -and $parts[0] -eq 'services') { continue }

        $usuario = ''
        $sessao  = ''
        $id      = -1
        $estado  = ''

        if ($parts.Count -ge 4) {
            $sessao  = $parts[0].TrimStart('>')
            $usuario = $parts[1]
            $id      = $parts[2]
            $estado  = $parts[3]
        }
        elseif ($parts.Count -eq 3) {

            if ($parts[0] -ieq 'console') { continue }
            $sessao = ''
            $usuario = $parts[0]
            $id      = $parts[1]
            $estado  = $parts[2]
        }
        else { continue }

        if ($id -notmatch '^\d+$') { continue }
        $id = [int]$id

        if ($id -ge 65536) { continue }

        if (-not $usuario) { continue }

        $sessoes += [PSCustomObject]@{
            Usuario = $usuario
            Sessao  = $sessao
            ID      = $id
            Estado  = $estado
        }
    }

    return $sessoes
}

# ============================================================================
# 2) CPU/MEM por usuário
# ============================================================================

function Get-UserUsage {

    param([int]$Intervalo)

    $os = Get-CimInstance Win32_OperatingSystem
    $totalMemBytes = [int64]$os.TotalVisibleMemorySize * 1KB

    $cs = Get-CimInstance Win32_ComputerSystem
    $cores = [int]$cs.NumberOfLogicalProcessors

    $a1 = Get-Process -IncludeUserName -ErrorAction SilentlyContinue |
          Where-Object { $_.UserName } |
          Select-Object Id, CPU, WorkingSet64, UserName

    Start-Sleep -Seconds $Intervalo

    $a2 = Get-Process -IncludeUserName -ErrorAction SilentlyContinue |
          Where-Object { $_.UserName } |
          Select-Object Id, CPU, WorkingSet64, UserName

    $calcs = foreach ($p1 in $a1) {
        $p2 = $a2 | Where-Object Id -eq $p1.Id
        if (-not $p2) { continue }

        $delta = $p2.CPU - $p1.CPU
        if ($delta -lt 0) { continue }

        $cpuPct = if ($Intervalo -gt 0 -and $cores -gt 0) {
            (($delta / $Intervalo) / $cores) * 100
        } else { 0 }

        [PSCustomObject]@{
            Usuario   = ($p1.UserName.Split('\')[-1])
            CPU_Pct   = [math]::Round($cpuPct, 2)
            Mem_Bytes = [int64]$p2.WorkingSet64
        }
    }

    foreach ($g in ($calcs | Group-Object Usuario)) {

        $cpuTotal = ($g.Group | Measure-Object CPU_Pct -Sum).Sum
        $memBytes = ($g.Group | Measure-Object Mem_Bytes -Sum).Sum
        $memPct   = if ($totalMemBytes -gt 0) {
            ($memBytes / $totalMemBytes) * 100
        } else { 0 }

        [PSCustomObject]@{
            Usuario = $g.Name
            CPU_Pct = [math]::Round($cpuTotal, 2)
            MEM_Pct = [math]::Round($memPct, 2)
        }
    }
}

# ============================================================================
# 3) Execução
# ============================================================================

$sessoes = Get-RDPSessions

# ---------------------------------------------------------------------------
# -USER → contagem de sessões (JSON)
# ---------------------------------------------------------------------------

if ($USER) {

    if (-not $sessoes) {
        [PSCustomObject][ordered]@{
            active  = 0
            disc    = 0
            total   = 0
        } | ConvertTo-Json
        exit 0
    }

    $active = 0
    $disc = 0

    foreach ($s in $sessoes) {

        $estado = $s.Estado.ToLower()

        if ($estado -match 'active|ativo|activo|actif|aktiv') {
            $active++
        }
        elseif ($estado -match 'disc|descon|desc|déconn|getr') {
            $disc++
        }
    }

    [PSCustomObject][ordered]@{
        active  = $active
        disc    = $disc
        total   = ($active + $disc)
    } | ConvertTo-Json -Depth 2

    exit 0
}

# ---------------------------------------------------------------------------
# -CPU / -MEM → JSON
# ---------------------------------------------------------------------------

if ($CPU -or $MEM) {

    $uso = Get-UserUsage -Intervalo $Intervalo
    $usuariosValidos = $sessoes.Usuario | Select-Object -Unique
    $uso = $uso | Where-Object { $usuariosValidos -contains $_.Usuario }

    if ($CPU) {
        $uso = $uso | Sort-Object CPU_Pct -Descending
    }
    else {
        $uso = $uso | Sort-Object MEM_Pct -Descending
    }

    $result = foreach ($u in $uso) {

        $sess = $sessoes | Where-Object Usuario -eq $u.Usuario | Select-Object -First 1

        if ($CPU) {
            [PSCustomObject][ordered]@{
                usuario = $u.Usuario
                sessao  = $sess.Sessao
                id      = $sess.ID
                estado  = $sess.Estado
                cpu_pct = $u.CPU_Pct
            }
        }
        else {
            [PSCustomObject][ordered]@{
                usuario = $u.Usuario
                sessao  = $sess.Sessao
                id      = $sess.ID
                estado  = $sess.Estado
                mem_pct = $u.MEM_Pct
            }
        }
    }

    $result | ConvertTo-Json -Depth 3
    exit 0
}

# ---------------------------------------------------------------------------
# Sem parâmetros → JSON
# ---------------------------------------------------------------------------

$result = foreach ($s in $sessoes) {
    [PSCustomObject][ordered]@{
        usuario = $s.Usuario
        sessao  = $s.Sessao
        id      = $s.ID
        estado  = $s.Estado
    }
}

$result | ConvertTo-Json -Depth 3
exit 0