# TerminalServerUserChecker.ps1
# Compatible with Windows Server 2022
# - Uses Invoke-Command + Get-LocalUser for remote queries (no ADSI)
# - Uses CIM (Get-CimInstance) for profile paths (replaces WMI)
# - Per-server user count summary panel
# Requires: PowerShell 5.1+, WinRM enabled on target servers, admin rights

# ---------------------------------------------
#  SELF-ELEVATION: Als Administrator neu starten
# ---------------------------------------------
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin     = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
        -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------
#  MAIN FORM
# ---------------------------------------------
$script:form = New-Object System.Windows.Forms.Form
$script:form.Text = "Terminal Server User Checker"
$script:form.Size = New-Object System.Drawing.Size(1200, 920)
$script:form.StartPosition = "CenterScreen"
$script:form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$script:form.ForeColor = [System.Drawing.Color]::White
$script:form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$script:form.MinimumSize = New-Object System.Drawing.Size(1000, 800)
$form = $script:form

# ---------------------------------------------
#  LEFT PANEL - Server list + Credentials
# ---------------------------------------------
$panelLeft = New-Object System.Windows.Forms.Panel
$panelLeft.Size = New-Object System.Drawing.Size(250, 760)
$panelLeft.Location = New-Object System.Drawing.Point(10, 10)
$panelLeft.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$form.Controls.Add($panelLeft)

$lblServers = New-Object System.Windows.Forms.Label
$lblServers.Text = "TERMINAL SERVERS"
$lblServers.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblServers.ForeColor = [System.Drawing.Color]::FromArgb(0, 183, 235)
$lblServers.Location = New-Object System.Drawing.Point(10, 10)
$lblServers.Size = New-Object System.Drawing.Size(230, 20)
$panelLeft.Controls.Add($lblServers)

$txtIP = New-Object System.Windows.Forms.TextBox
$txtIP.Location = New-Object System.Drawing.Point(10, 38)
$txtIP.Size = New-Object System.Drawing.Size(160, 24)
$txtIP.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$txtIP.ForeColor = [System.Drawing.Color]::White
$txtIP.BorderStyle = "FixedSingle"
$panelLeft.Controls.Add($txtIP)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = "+ Hinzufuegen"
$btnAdd.Location = New-Object System.Drawing.Point(178, 37)
$btnAdd.Size = New-Object System.Drawing.Size(60, 26)
$btnAdd.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 58)
$btnAdd.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$btnAdd.FlatStyle = "Flat"
$btnAdd.FlatAppearance.BorderSize = 1
$btnAdd.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80, 80, 85)
$panelLeft.Controls.Add($btnAdd)

$listServers = New-Object System.Windows.Forms.ListBox
$listServers.Location = New-Object System.Drawing.Point(10, 72)
$listServers.Size = New-Object System.Drawing.Size(228, 240)
$listServers.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 38)
$listServers.ForeColor = [System.Drawing.Color]::White
$listServers.BorderStyle = "FixedSingle"
$listServers.SelectionMode = "MultiExtended"
$panelLeft.Controls.Add($listServers)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = "Ausgewaehlt entfernen"
$btnRemove.Location = New-Object System.Drawing.Point(10, 322)
$btnRemove.Size = New-Object System.Drawing.Size(228, 26)
$btnRemove.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 58)
$btnRemove.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$btnRemove.FlatStyle = "Flat"
$btnRemove.FlatAppearance.BorderSize = 1
$btnRemove.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80, 80, 85)
$panelLeft.Controls.Add($btnRemove)

$btnSaveList = New-Object System.Windows.Forms.Button
$btnSaveList.Text = "Serverliste speichern"
$btnSaveList.Location = New-Object System.Drawing.Point(10, 355)
$btnSaveList.Size = New-Object System.Drawing.Size(228, 24)
$btnSaveList.BackColor = [System.Drawing.Color]::FromArgb(52, 52, 55)
$btnSaveList.ForeColor = [System.Drawing.Color]::White
$btnSaveList.FlatStyle = "Flat"
$btnSaveList.FlatAppearance.BorderSize = 0
$panelLeft.Controls.Add($btnSaveList)

$btnLoadList = New-Object System.Windows.Forms.Button
$btnLoadList.Text = "Serverliste laden"
$btnLoadList.Location = New-Object System.Drawing.Point(10, 383)
$btnLoadList.Size = New-Object System.Drawing.Size(228, 24)
$btnLoadList.BackColor = [System.Drawing.Color]::FromArgb(52, 52, 55)
$btnLoadList.ForeColor = [System.Drawing.Color]::White
$btnLoadList.FlatStyle = "Flat"
$btnLoadList.FlatAppearance.BorderSize = 0
$panelLeft.Controls.Add($btnLoadList)

# Credentials im linken Panel
$lblCredTitle = New-Object System.Windows.Forms.Label
$lblCredTitle.Text = "ANMELDEDATEN"
$lblCredTitle.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblCredTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 183, 235)
$lblCredTitle.Location = New-Object System.Drawing.Point(10, 420)
$lblCredTitle.Size = New-Object System.Drawing.Size(230, 20)
$panelLeft.Controls.Add($lblCredTitle)

$btnCredential = New-Object System.Windows.Forms.Button
$btnCredential.Text = "Anmeldedaten eingeben"
$btnCredential.Location = New-Object System.Drawing.Point(10, 444)
$btnCredential.Size = New-Object System.Drawing.Size(228, 26)
$btnCredential.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 58)
$btnCredential.ForeColor = [System.Drawing.Color]::White
$btnCredential.FlatStyle = "Flat"
$btnCredential.FlatAppearance.BorderSize = 0
$panelLeft.Controls.Add($btnCredential)

$lblCredStatus = New-Object System.Windows.Forms.Label
$lblCredStatus.Text = "Nicht gesetzt"
$lblCredStatus.Location = New-Object System.Drawing.Point(10, 474)
$lblCredStatus.Size = New-Object System.Drawing.Size(228, 18)
$lblCredStatus.ForeColor = [System.Drawing.Color]::FromArgb(200, 80, 80)
$lblCredStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$panelLeft.Controls.Add($lblCredStatus)

$btnSaveCred = New-Object System.Windows.Forms.Button
$btnSaveCred.Text = "Credentials speichern"
$btnSaveCred.Location = New-Object System.Drawing.Point(10, 496)
$btnSaveCred.Size = New-Object System.Drawing.Size(228, 24)
$btnSaveCred.BackColor = [System.Drawing.Color]::FromArgb(52, 52, 55)
$btnSaveCred.ForeColor = [System.Drawing.Color]::White
$btnSaveCred.FlatStyle = "Flat"
$btnSaveCred.FlatAppearance.BorderSize = 0
$panelLeft.Controls.Add($btnSaveCred)

$btnLoadCred = New-Object System.Windows.Forms.Button
$btnLoadCred.Text = "Credentials laden"
$btnLoadCred.Location = New-Object System.Drawing.Point(10, 524)
$btnLoadCred.Size = New-Object System.Drawing.Size(228, 24)
$btnLoadCred.BackColor = [System.Drawing.Color]::FromArgb(52, 52, 55)
$btnLoadCred.ForeColor = [System.Drawing.Color]::White
$btnLoadCred.FlatStyle = "Flat"
$btnLoadCred.FlatAppearance.BorderSize = 0
$panelLeft.Controls.Add($btnLoadCred)

# Per-Server Count Summary
$lblSummaryTitle = New-Object System.Windows.Forms.Label
$lblSummaryTitle.Text = "ZUSAMMENFASSUNG DES SCANS"
$lblSummaryTitle.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblSummaryTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 183, 235)
$lblSummaryTitle.Location = New-Object System.Drawing.Point(10, 562)
$lblSummaryTitle.Size = New-Object System.Drawing.Size(230, 20)
$panelLeft.Controls.Add($lblSummaryTitle)

$listSummary = New-Object System.Windows.Forms.ListBox
$listSummary.Location = New-Object System.Drawing.Point(10, 585)
$listSummary.Size = New-Object System.Drawing.Size(228, 160)
$listSummary.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 38)
$listSummary.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$listSummary.BorderStyle = "FixedSingle"
$listSummary.SelectionMode = "None"
$listSummary.Font = New-Object System.Drawing.Font("Consolas", 8)
$listSummary.ScrollAlwaysVisible = $false
$listSummary.HorizontalScrollbar = $false
$panelLeft.Controls.Add($listSummary)

# ---------------------------------------------
#  RIGHT PANEL - Results
# ---------------------------------------------
$panelRight = New-Object System.Windows.Forms.Panel
$panelRight.Location = New-Object System.Drawing.Point(270, 10)
$panelRight.Size = New-Object System.Drawing.Size(910, 860)
$panelRight.Anchor = "Top,Bottom,Left,Right"
$panelRight.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.Controls.Add($panelRight)

# Zeile 1: Scan / Abbrechen / Status
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Server scannen"
$btnScan.Location = New-Object System.Drawing.Point(0, 0)
$btnScan.Size = New-Object System.Drawing.Size(185, 36)
$btnScan.BackColor = [System.Drawing.Color]::FromArgb(50, 65, 85)
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.FlatStyle = "Flat"
$btnScan.FlatAppearance.BorderSize = 0
$btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$panelRight.Controls.Add($btnScan)

$btnAbort = New-Object System.Windows.Forms.Button
$btnAbort.Text = "STOP"
$btnAbort.Location = New-Object System.Drawing.Point(192, 0)
$btnAbort.Size = New-Object System.Drawing.Size(70, 36)
$btnAbort.BackColor = [System.Drawing.Color]::FromArgb(75, 45, 45)
$btnAbort.ForeColor = [System.Drawing.Color]::White
$btnAbort.FlatStyle = "Flat"
$btnAbort.FlatAppearance.BorderSize = 0
$btnAbort.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnAbort.Enabled = $false
$panelRight.Controls.Add($btnAbort)

# Zeile 1 rechts: Analyse-Buttons ab X=270
$btnMultiServer = New-Object System.Windows.Forms.Button
$btnMultiServer.Text = "Multi-Server"
$btnMultiServer.Location = New-Object System.Drawing.Point(270, 0)
$btnMultiServer.Size = New-Object System.Drawing.Size(105, 36)
$btnMultiServer.BackColor = [System.Drawing.Color]::FromArgb(50, 55, 65)
$btnMultiServer.ForeColor = [System.Drawing.Color]::White
$btnMultiServer.FlatStyle = "Flat"
$btnMultiServer.FlatAppearance.BorderSize = 0
$btnMultiServer.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$panelRight.Controls.Add($btnMultiServer)

$btnOldProfiles = New-Object System.Windows.Forms.Button
$btnOldProfiles.Text = "Alte Profile"
$btnOldProfiles.Location = New-Object System.Drawing.Point(380, 0)
$btnOldProfiles.Size = New-Object System.Drawing.Size(95, 36)
$btnOldProfiles.BackColor = [System.Drawing.Color]::FromArgb(50, 55, 65)
$btnOldProfiles.ForeColor = [System.Drawing.Color]::White
$btnOldProfiles.FlatStyle = "Flat"
$btnOldProfiles.FlatAppearance.BorderSize = 0
$btnOldProfiles.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$panelRight.Controls.Add($btnOldProfiles)

$btnLargeProfiles = New-Object System.Windows.Forms.Button
$btnLargeProfiles.Text = "Grosse Profile"
$btnLargeProfiles.Location = New-Object System.Drawing.Point(480, 0)
$btnLargeProfiles.Size = New-Object System.Drawing.Size(105, 36)
$btnLargeProfiles.BackColor = [System.Drawing.Color]::FromArgb(50, 55, 65)
$btnLargeProfiles.ForeColor = [System.Drawing.Color]::White
$btnLargeProfiles.FlatStyle = "Flat"
$btnLargeProfiles.FlatAppearance.BorderSize = 0
$btnLargeProfiles.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$panelRight.Controls.Add($btnLargeProfiles)

$btnEventLogCheck = New-Object System.Windows.Forms.Button
$btnEventLogCheck.Text = "Aktivitaet"
$btnEventLogCheck.Location = New-Object System.Drawing.Point(590, 0)
$btnEventLogCheck.Size = New-Object System.Drawing.Size(85, 36)
$btnEventLogCheck.BackColor = [System.Drawing.Color]::FromArgb(50, 55, 65)
$btnEventLogCheck.ForeColor = [System.Drawing.Color]::White
$btnEventLogCheck.FlatStyle = "Flat"
$btnEventLogCheck.FlatAppearance.BorderSize = 0
$btnEventLogCheck.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$panelRight.Controls.Add($btnEventLogCheck)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear"
$btnClear.Location = New-Object System.Drawing.Point(680, 0)
$btnClear.Size = New-Object System.Drawing.Size(60, 36)
$btnClear.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$btnClear.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$btnClear.FlatStyle = "Flat"
$btnClear.FlatAppearance.BorderSize = 0
$btnClear.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$panelRight.Controls.Add($btnClear)

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "CSV"
$btnExport.Location = New-Object System.Drawing.Point(744, 0)
$btnExport.Size = New-Object System.Drawing.Size(50, 36)
$btnExport.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$btnExport.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$btnExport.FlatStyle = "Flat"
$btnExport.FlatAppearance.BorderSize = 0
$btnExport.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$panelRight.Controls.Add($btnExport)

# Zeile 2: Filter-Checkboxen + Profilgroesse-Checkbox + Suchfeld
$lblFilterStates = New-Object System.Windows.Forms.Label
$lblFilterStates.Text = "Anzeigen:"
$lblFilterStates.Location = New-Object System.Drawing.Point(3, 46)
$lblFilterStates.Size = New-Object System.Drawing.Size(58, 18)
$lblFilterStates.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$panelRight.Controls.Add($lblFilterStates)

$chkShowActive = New-Object System.Windows.Forms.CheckBox
$chkShowActive.Text = "Aktiv"
$chkShowActive.Location = New-Object System.Drawing.Point(62, 44)
$chkShowActive.Size = New-Object System.Drawing.Size(58, 20)
$chkShowActive.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 190)
$chkShowActive.Checked = $true
$panelRight.Controls.Add($chkShowActive)

$chkShowDisc = New-Object System.Windows.Forms.CheckBox
$chkShowDisc.Text = "Getrennt"
$chkShowDisc.Location = New-Object System.Drawing.Point(122, 44)
$chkShowDisc.Size = New-Object System.Drawing.Size(78, 20)
$chkShowDisc.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 190)
$chkShowDisc.Checked = $true
$panelRight.Controls.Add($chkShowDisc)

$chkShowOffline = New-Object System.Windows.Forms.CheckBox
$chkShowOffline.Text = "Offline"
$chkShowOffline.Location = New-Object System.Drawing.Point(202, 44)
$chkShowOffline.Size = New-Object System.Drawing.Size(65, 20)
$chkShowOffline.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 190)
$chkShowOffline.Checked = $true
$panelRight.Controls.Add($chkShowOffline)

$chkShowError = New-Object System.Windows.Forms.CheckBox
$chkShowError.Text = "Fehler"
$chkShowError.Location = New-Object System.Drawing.Point(269, 44)
$chkShowError.Size = New-Object System.Drawing.Size(60, 20)
$chkShowError.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 190)
$chkShowError.Checked = $true
$panelRight.Controls.Add($chkShowError)

$chkProfileSize = New-Object System.Windows.Forms.CheckBox
$chkProfileSize.Text = "Profilgroesse"
$chkProfileSize.Location = New-Object System.Drawing.Point(335, 44)
$chkProfileSize.Size = New-Object System.Drawing.Size(108, 20)
$chkProfileSize.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$chkProfileSize.Checked = $false
$panelRight.Controls.Add($chkProfileSize)

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(450, 44)
$txtFilter.Size = New-Object System.Drawing.Size(200, 22)
$txtFilter.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$txtFilter.ForeColor = [System.Drawing.Color]::White
$txtFilter.BorderStyle = "FixedSingle"
$panelRight.Controls.Add($txtFilter)

# DataGridView
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(0, 72)
$grid.Size = New-Object System.Drawing.Size(910, 570)
$grid.Anchor = "Top,Bottom,Left,Right"
$grid.BackgroundColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$grid.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 38)
$grid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(50, 65, 85)
$grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$grid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(0, 183, 235)
$grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grid.ColumnHeadersBorderStyle = "Single"
$grid.EnableHeadersVisualStyles = $false
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.RowHeadersVisible = $false
$grid.SelectionMode = "FullRowSelect"
$grid.AutoSizeColumnsMode = "Fill"
$grid.BorderStyle = "None"
$panelRight.Controls.Add($grid)

$statusBar = New-Object System.Windows.Forms.Label
$statusBar.Location = New-Object System.Drawing.Point(0, 622)
$statusBar.Size = New-Object System.Drawing.Size(910, 24)
$statusBar.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$statusBar.Text = "Bereit."
$panelRight.Controls.Add($statusBar)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(0, 650)
$progressBar.Size = New-Object System.Drawing.Size(910, 14)
$progressBar.Style = "Continuous"
$panelRight.Controls.Add($progressBar)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text = "Logdatei in Notepad"
$btnOpenLog.Location = New-Object System.Drawing.Point(0, 668)
$btnOpenLog.Size = New-Object System.Drawing.Size(150, 22)
$btnOpenLog.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$btnOpenLog.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$btnOpenLog.FlatStyle = "Flat"
$btnOpenLog.FlatAppearance.BorderSize = 0
$btnOpenLog.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$panelRight.Controls.Add($btnOpenLog)
$btnOpenLog.Add_Click({
    if (Test-Path $script:LogFile) {
        Start-Process notepad.exe $script:LogFile
    } else {
        [System.Windows.Forms.MessageBox]::Show("Logdatei nicht gefunden:`n$($script:LogFile)", "Hinweis", "OK", "Information")
    }
})

$script:txtLog = New-Object System.Windows.Forms.RichTextBox
$script:txtLog.Location = New-Object System.Drawing.Point(0, 693)
$script:txtLog.Size = New-Object System.Drawing.Size(910, 150)
$script:txtLog.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$script:txtLog.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$script:txtLog.Font = New-Object System.Drawing.Font("Consolas", 8)
$script:txtLog.ReadOnly = $true
$script:txtLog.BorderStyle = "None"
$script:txtLog.ScrollBars = "Vertical"
$script:txtLog.Visible = $true
$panelRight.Controls.Add($script:txtLog)

# ---------------------------------------------
#  DATA TABLE
# ---------------------------------------------
$script:DataTable = New-Object System.Data.DataTable
[void]$script:DataTable.Columns.Add("Server")
[void]$script:DataTable.Columns.Add("Username")
[void]$script:DataTable.Columns.Add("State")
[void]$script:DataTable.Columns.Add("Last Login")
[void]$script:DataTable.Columns.Add("Session")
[void]$script:DataTable.Columns.Add("Getrennt seit")
[void]$script:DataTable.Columns.Add("Profile Path")
[void]$script:DataTable.Columns.Add("Groesse")
[void]$script:DataTable.Columns.Add("Status")

# ---------------------------------------------
#  HELPER: Formatierungsfunktionen
# ---------------------------------------------
function Format-LastLogin {
    param([string]$Value)
    if ($Value -eq "Unbekannt" -or $Value -eq "-" -or $Value -eq "") { return $Value }
    try {
        $d = [datetime]::ParseExact($Value, "yyyy-MM-dd HH:mm",
                 [System.Globalization.CultureInfo]::InvariantCulture)
        return $d.ToString("dd.MM.yyyy HH:mm")
    } catch { return $Value }
}

function Format-ProfileSize {
    param($Value)
    if ($Value -eq "N/A" -or $Value -eq "-" -or $Value -eq "" -or $Value -eq "Error") { return $Value }
    try {
        $mb = [double]$Value
        if ($mb -ge 1024) {
            return "{0:N2} GB" -f ($mb / 1024)
        } else {
            return "{0:N0} MB" -f $mb
        }
    } catch { return $Value }
}

# ---------------------------------------------
#  HELPER: Verbose Log schreiben
# ---------------------------------------------
$script:LogFile = "$env:TEMP\TerminalServerUserChecker_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    try {
        $timestamp = Get-Date -Format "HH:mm:ss"
        $line = "[$timestamp] [$Level] $Message"
        try { Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 } catch { }

        $color = switch ($Level) {
            "OK"    { [System.Drawing.Color]::FromArgb(80, 200, 80) }
            "WARN"  { [System.Drawing.Color]::FromArgb(220, 180, 0) }
            "ERROR" { [System.Drawing.Color]::FromArgb(220, 80, 80) }
            default { [System.Drawing.Color]::FromArgb(180, 180, 180) }
        }

        if ($script:txtLog -ne $null) {
            $script:txtLog.SelectionStart = $script:txtLog.TextLength
            $script:txtLog.SelectionLength = 0
            $script:txtLog.SelectionColor = $color
            $script:txtLog.AppendText("$line`n")
            $script:txtLog.ScrollToCaret()
        }
        [System.Windows.Forms.Application]::DoEvents()
    } catch { }
}

# ---------------------------------------------
#  HELPER: Query one server via Invoke-Command
# ---------------------------------------------
function Query-Server {
    param(
        $Server,
        [System.Management.Automation.PSCredential]$Credential = $null,
        [bool]$CalcProfileSize = $false
    )
    $results = @()

    $remoteBlock = {
        param($CalcSize)
        $output = @()
        $activeSessions = @{}
        try {
            $quserRaw = & quser 2>&1
            if ($quserRaw -and $quserRaw.Count -gt 1) {
                $header = $quserRaw[0].ToString()
                $colUsername    = 0
                $colSession     = $header.IndexOf("SESSIONNAME")
                if ($colSession -lt 0) { $colSession = $header.IndexOf("SITZUNGSNAME") }
                $colID          = $header.IndexOf(" ID")
                $colState       = $header.IndexOf("STATE")
                if ($colState   -lt 0) { $colState   = $header.IndexOf("STATUS") }
                $colIdle        = $header.IndexOf("IDLE TIME")
                if ($colIdle    -lt 0) { $colIdle    = $header.IndexOf("LEERLAUF") }
                $colLogon       = $header.IndexOf("LOGON TIME")
                if ($colLogon   -lt 0) { $colLogon   = $header.IndexOf("ANMELDEZEIT") }

                foreach ($line in ($quserRaw | Select-Object -Skip 1)) {
                    $l = $line.ToString()
                    if ($l.Trim() -eq "") { continue }
                    try {
                        $uname    = if ($colSession -gt 0) { $l.Substring($colUsername, $colSession - $colUsername) } else { $l }
                        $uname    = $uname.TrimStart(">").Trim().ToLower()
                        if ($uname -eq "") { continue }
                        $sessName = if ($colSession -gt 0 -and $colID -gt 0 -and $l.Length -gt $colSession) {
                            $l.Substring($colSession, [Math]::Min($colID - $colSession, $l.Length - $colSession)).Trim()
                        } else { "" }
                        $stateStr = if ($colState -gt 0 -and $l.Length -gt $colState) {
                            $end = if ($colIdle -gt 0) { $colIdle } else { $colState + 10 }
                            $l.Substring($colState, [Math]::Min($end - $colState, $l.Length - $colState)).Trim()
                        } else { "" }
                        $idleStr  = if ($colIdle -gt 0 -and $l.Length -gt $colIdle) {
                            $end = if ($colLogon -gt 0) { $colLogon } else { $colIdle + 12 }
                            $l.Substring($colIdle, [Math]::Min($end - $colIdle, $l.Length - $colIdle)).Trim()
                        } else { "" }
                        $stateNorm = switch -Wildcard ($stateStr.ToLower()) {
                            "aktiv*"  { "Active" }
                            "active*" { "Active" }
                            "disc*"   { "Disconnected" }
                            default   { if ($sessName -eq "") { "Disconnected" } else { "Active" } }
                        }
                        $idleClean = if ($idleStr -eq "." -or $idleStr -eq "") { "-" } else { $idleStr }
                        $activeSessions[$uname] = @{
                            SessionName  = if ($sessName -ne "") { $sessName } else { "disconnected" }
                            State        = $stateNorm
                            IdleTime     = $idleClean
                        }
                    } catch { }
                }
            }
        } catch { }

        $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.Special }
        $accountMap = @{}
        try {
            Get-CimInstance -ClassName Win32_Account -ErrorAction SilentlyContinue |
                ForEach-Object { $accountMap[$_.SID] = $_.Name }
        } catch { }

        foreach ($prof in $profiles) {
            $username = ""
            if ($accountMap.ContainsKey($prof.SID)) {
                $username = $accountMap[$prof.SID]
            } else {
                try {
                    $sid = New-Object System.Security.Principal.SecurityIdentifier($prof.SID)
                    $resolved = $sid.Translate([System.Security.Principal.NTAccount]).Value
                    $username = if ($resolved -match "\\") { $resolved.Split("\")[1] } else { $resolved }
                } catch { $username = $prof.SID }
            }
            $lastLogin = "Unbekannt"
            if ($prof.LastUseTime) {
                $lastLogin = $prof.LastUseTime.ToLocalTime().ToString("yyyy-MM-dd HH:mm")
            }
            $sessionInfo = $activeSessions[$username.ToLower()]
            $state       = if ($sessionInfo) { $sessionInfo.State }       else { "Offline" }
            $sessionName = if ($sessionInfo) { $sessionInfo.SessionName } else { "-" }
            $idleTime    = if ($sessionInfo) { $sessionInfo.IdleTime }    else { "-" }

            $profileSizeMB = "N/A"
            if ($CalcSize -and $prof.LocalPath) {
                try {
                    $totalBytes = [long]0
                    $rootFiles = Get-ChildItem -Path $prof.LocalPath -File -Force -ErrorAction SilentlyContinue |
                                 Where-Object { $_ -ne $null -and $_.PSObject.Properties["Length"] -and $_.Length -ne $null }
                    foreach ($f in $rootFiles) { try { $totalBytes += [long]$f.Length } catch { } }
                    $subFolders = Get-ChildItem -Path $prof.LocalPath -Directory -Force -ErrorAction SilentlyContinue |
                                  Where-Object { $_ -ne $null -and -not $_.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) }
                    foreach ($folder in $subFolders) {
                        try {
                            $subFiles = Get-ChildItem -Path $folder.FullName -Recurse -Force -File `
                                -ErrorAction SilentlyContinue |
                                Where-Object { $_ -ne $null -and $_.PSObject.Properties["Length"] -and $_.Length -ne $null }
                            foreach ($f in $subFiles) { try { $totalBytes += [long]$f.Length } catch { } }
                        } catch { }
                    }
                    $profileSizeMB = [math]::Round($totalBytes / 1MB, 2)
                } catch { $profileSizeMB = "Error" }
            }

            $output += [PSCustomObject]@{
                Username      = $username
                SessionName   = $sessionName
                IdleTime      = $idleTime
                State         = $state
                LastLogin     = $lastLogin
                ProfilePath   = $prof.LocalPath
                ProfileSizeMB = $profileSizeMB
                Status        = "OK"
            }
        }
        return $output
    }

    $sessionOpt = New-PSSessionOption -OpenTimeout 30000 -OperationTimeout 120000
    try {
        if ($Credential) {
            $remoteData = Invoke-Command -ComputerName $Server -Credential $Credential `
                              -ScriptBlock $remoteBlock -ArgumentList $CalcProfileSize `
                              -SessionOption $sessionOpt -ErrorAction Stop
        } else {
            $remoteData = Invoke-Command -ComputerName $Server `
                              -ScriptBlock $remoteBlock -ArgumentList $CalcProfileSize `
                              -SessionOption $sessionOpt -ErrorAction Stop
        }
        foreach ($r in $remoteData) {
            $results += [PSCustomObject]@{
                Server        = $Server
                Username      = $r.Username
                State         = $r.State
                LastLogin     = $r.LastLogin
                SessionName   = $r.SessionName
                IdleTime      = $r.IdleTime
                ProfilePath   = $r.ProfilePath
                ProfileSizeMB = $r.ProfileSizeMB
                Status        = $r.Status
            }
        }
    } catch {
        $results += [PSCustomObject]@{
            Server        = $Server
            Username      = "ERROR"
            State         = "-"
            LastLogin     = "-"
            SessionName   = "-"
            SessionID     = "-"
            ProfilePath   = "-"
            ProfileSizeMB = "-"
            Status        = "ERROR: $($_.Exception.Message)"
        }
    }
    return $results
}

# ---------------------------------------------
#  HELPER: Refresh grid with optional filter
# ---------------------------------------------
function Refresh-Grid {
    $filterText = $txtFilter.Text.Trim()
    $view = $script:DataTable.DefaultView
    $stateFilters = @()
    if ($chkShowActive.Checked)  { $stateFilters += "State = 'Active'" }
    if ($chkShowDisc.Checked)    { $stateFilters += "State = 'Disconnected'" }
    if ($chkShowOffline.Checked) { $stateFilters += "State = 'Offline'" }
    if ($chkShowError.Checked)   { $stateFilters += "Status LIKE 'ERROR%'" }

    $stateExpr = if ($stateFilters.Count -gt 0) {
        "(" + ($stateFilters -join " OR ") + ")"
    } else { "1=0" }

    try {
        if ($filterText -ne "" -and $filterText -ne "Filter by username...") {
            $view.RowFilter = "$stateExpr AND (Username LIKE '%$filterText%' OR [Session] LIKE '%$filterText%')"
        } else {
            $view.RowFilter = $stateExpr
        }
        $grid.DataSource = $view.ToTable()
    } catch {
        $view.RowFilter = ""
        $grid.DataSource = $view.ToTable()
    }
}

# ---------------------------------------------
#  HELPER: Rebuild the per-server count summary
# ---------------------------------------------
function Refresh-Summary {
    $listSummary.Items.Clear()
    $servers = $script:DataTable.Rows | ForEach-Object { $_["Server"] } | Select-Object -Unique

    $totalUsers = 0
    $totalTime  = 0.0
    foreach ($srv in $servers) {
        $count = ($script:DataTable.Rows |
                  Where-Object { $_["Server"] -eq $srv -and $_["Status"] -eq "OK" }).Count
        $totalUsers += $count
        $secs = if ($script:ScanTimes.ContainsKey($srv)) { $script:ScanTimes[$srv] } else { $null }
        if ($secs) { $totalTime += $secs }
        $secsStr = if ($secs) { "${secs}s" } else { "-" }
        $listSummary.Items.Add($srv)
        $listSummary.Items.Add("  $count User   Scanzeit: $secsStr")
    }
    if ($servers.Count -gt 1) {
        $listSummary.Items.Add("-" * 26)
        $listSummary.Items.Add("GESAMT")
        $listSummary.Items.Add("  $totalUsers User   Scanzeit: ${totalTime}s")
    }
    if ($script:ScanTimePhase1 -gt 0) {
        $listSummary.Items.Add("")
        $listSummary.Items.Add("Phase 1 (User-Scan):")
        $listSummary.Items.Add("  $($script:ScanTimePhase1)s")
    }
    if ($script:ScanTimePhase2 -gt 0) {
        $listSummary.Items.Add("Phase 2 (Profilgroessen):")
        $listSummary.Items.Add("  $($script:ScanTimePhase2)s")
    }
}

# ---------------------------------------------
#  EVENTS
# ---------------------------------------------
$addServer = {
    $ip = $txtIP.Text.Trim()
    if ($ip -ne "" -and $ip -ne "IP or Hostname" -and -not $listServers.Items.Contains($ip)) {
        [void]$listServers.Items.Add($ip)
        $txtIP.Clear()
    }
}
$txtIP.Text = "IP or Hostname"
$txtIP.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
$txtIP.Add_GotFocus({
    if ($txtIP.Text -eq "IP or Hostname") {
        $txtIP.Text = ""
        $txtIP.ForeColor = [System.Drawing.Color]::White
    }
})
$txtIP.Add_LostFocus({
    if ($txtIP.Text -eq "") {
        $txtIP.Text = "IP or Hostname"
        $txtIP.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
    }
})
$btnAdd.Add_Click($addServer)
$txtIP.Add_KeyDown({
    if ($_.KeyCode -eq "Return") { & $addServer }
})

$btnRemove.Add_Click({
    $selected = @($listServers.SelectedItems)
    foreach ($item in $selected) { $listServers.Items.Remove($item) }
})

$txtFilter.Text = "Filter by username..."
$txtFilter.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
$txtFilter.Add_GotFocus({
    if ($txtFilter.Text -eq "Filter by username...") {
        $txtFilter.Text = ""
        $txtFilter.ForeColor = [System.Drawing.Color]::White
    }
})
$txtFilter.Add_LostFocus({
    if ($txtFilter.Text -eq "") {
        $txtFilter.Text = "Filter by username..."
        $txtFilter.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
    }
})
$txtFilter.Add_TextChanged({ Refresh-Grid })

$script:Cred           = $null
$script:Aborted        = $false
$script:ScanTimes      = @{}
$script:ScanTimePhase1 = 0
$script:ScanTimePhase2 = 0

$btnCredential.Add_Click({
    try {
        $c = Get-Credential -Message "Anmeldedaten fuer den Remote-Zugriff (z.B. Administrator oder DOMAIN\User)"
        if ($c) {
            $script:Cred = $c
            $lblCredStatus.Text = "Angemeldet als: $($c.UserName)"
            $lblCredStatus.ForeColor = [System.Drawing.Color]::FromArgb(80, 200, 80)
        }
    } catch { }
})

$btnSaveCred.Add_Click({
    if ($null -eq $script:Cred) {
        [System.Windows.Forms.MessageBox]::Show("Zuerst Anmeldedaten setzen.", "Hinweis", "OK", "Warning")
        return
    }
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = "Credential Files (*.cred)|*.cred"
    $dlg.FileName = "credentials.cred"
    if ($dlg.ShowDialog() -eq "OK") {
        try {
            $encPwd = $script:Cred.Password | ConvertFrom-SecureString
            "$($script:Cred.UserName)`n$encPwd" | Out-File -FilePath $dlg.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show(
                "Gespeichert.`nHinweis: Die Datei ist nur auf diesem PC mit diesem Windows-Konto lesbar.",
                "Gespeichert", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Fehler: $($_.Exception.Message)", "Fehler", "OK", "Error")
        }
    }
})

$btnLoadCred.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Credential Files (*.cred)|*.cred"
    if ($dlg.ShowDialog() -eq "OK") {
        try {
            $lines = Get-Content $dlg.FileName
            $username = $lines[0].Trim()
            $securePwd = $lines[1].Trim() | ConvertTo-SecureString
            $script:Cred = New-Object System.Management.Automation.PSCredential($username, $securePwd)
            $lblCredStatus.Text = "Angemeldet als: $username (geladen)"
            $lblCredStatus.ForeColor = [System.Drawing.Color]::FromArgb(80, 200, 80)
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Fehler beim Laden.`nHinweis: Credentials koennen nur auf dem PC geladen werden, auf dem sie gespeichert wurden.`n`n$($_.Exception.Message)",
                "Fehler", "OK", "Error")
        }
    }
})

$chkShowActive.Add_CheckedChanged({ Refresh-Grid })
$chkShowDisc.Add_CheckedChanged({ Refresh-Grid })
$chkShowOffline.Add_CheckedChanged({ Refresh-Grid })
$chkShowError.Add_CheckedChanged({ Refresh-Grid })

# =============================================
#  MULTI-SERVER-USER ANALYSE (VERBESSERT)
# =============================================
$btnMultiServer.Add_Click({
    $allRows = $script:DataTable.Rows | Where-Object { $_["Status"] -eq "OK" }
    if ($allRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Kein Scan-Ergebnis vorhanden.", "Hinweis", "OK", "Warning")
        return
    }

    $scanTime = Get-Date

    # -- Hilfsfunktion: LastLogin-String -> DateTime --------------------------
    function Parse-LoginDate {
        param([string]$s)
        if ($s -eq "Unbekannt" -or $s -eq "-" -or $s -eq "") { return $null }
        foreach ($fmt in @("dd.MM.yyyy HH:mm","yyyy-MM-dd HH:mm")) {
            try {
                return [datetime]::ParseExact($s, $fmt,
                    [System.Globalization.CultureInfo]::InvariantCulture)
            } catch { }
        }
        return $null
    }

    # -- Alle Profile je User sammeln -----------------------------------------
    $userProfiles = @{}
    foreach ($row in $allRows) {
        $u = $row["Username"]
        $s = $row["Server"]
        if (-not $userProfiles.ContainsKey($u)) { $userProfiles[$u] = @() }
        if (-not ($userProfiles[$u] | Where-Object { $_.Server -eq $s })) {
            $userProfiles[$u] += [PSCustomObject]@{
                Server    = $s
                LastLogin = $row["Last Login"]
                State     = $row["State"]
                Groesse   = $row["Groesse"]
                Path      = $row["Profile Path"]
            }
        }
    }

    # -- Nur User mit mehr als einem Server -----------------------------------
    $multiUsers = $userProfiles.GetEnumerator() |
                  Where-Object { $_.Value.Count -gt 1 } |
                  Sort-Object { $_.Value.Count } -Descending

    if ($multiUsers.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Kein User hat Profile auf mehreren Servern.", "Ergebnis", "OK", "Information")
        return
    }

    # -- Hauptfenster ---------------------------------------------------------
    $frmMulti = New-Object System.Windows.Forms.Form
    $frmMulti.Text = "Multi-Server-User Analyse"
    $frmMulti.Size = New-Object System.Drawing.Size(1060, 640)
    $frmMulti.MinimumSize = New-Object System.Drawing.Size(900, 500)
    $frmMulti.StartPosition = "CenterParent"
    $frmMulti.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
    $frmMulti.ForeColor = [System.Drawing.Color]::White

    # -- Kopfzeile ------------------------------------------------------------
    $pnlHeader = New-Object System.Windows.Forms.Panel
    $pnlHeader.Location = New-Object System.Drawing.Point(0, 0)
    $pnlHeader.Size = New-Object System.Drawing.Size(1060, 52)
    $pnlHeader.BackColor = [System.Drawing.Color]::FromArgb(38, 38, 42)
    $pnlHeader.Anchor = "Top,Left,Right"
    $frmMulti.Controls.Add($pnlHeader)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "USER MIT PROFILEN AUF MEHREREN SERVERN"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 183, 235)
    $lblTitle.Location = New-Object System.Drawing.Point(14, 10)
    $lblTitle.Size = New-Object System.Drawing.Size(500, 22)
    $pnlHeader.Controls.Add($lblTitle)

    $lblSubtitle = New-Object System.Windows.Forms.Label
    $lblSubtitle.Text = "$($multiUsers.Count) User betroffen  |  Scan: $(Get-Date -Format 'dd.MM.yyyy HH:mm')  |  Primarserver = neuester Last Login"
    $lblSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 150)
    $lblSubtitle.Location = New-Object System.Drawing.Point(14, 32)
    $lblSubtitle.Size = New-Object System.Drawing.Size(700, 16)
    $pnlHeader.Controls.Add($lblSubtitle)

    # -- Legende --------------------------------------------------------------
    $pnlLegend = New-Object System.Windows.Forms.Panel
    $pnlLegend.Location = New-Object System.Drawing.Point(0, 52)
    $pnlLegend.Size = New-Object System.Drawing.Size(1060, 28)
    $pnlLegend.BackColor = [System.Drawing.Color]::FromArgb(33, 33, 36)
    $pnlLegend.Anchor = "Top,Left,Right"
    $frmMulti.Controls.Add($pnlLegend)

    $mkLegItem = {
        param($text, $color, $x)
        $xInt = [int]$x
        $dot = New-Object System.Windows.Forms.Label
        $dot.Text = "o"
        $dot.ForeColor = $color
        $dot.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $dot.Location = New-Object System.Drawing.Point($xInt, 6)
        $dot.Size = New-Object System.Drawing.Size(16, 16)
        $pnlLegend.Controls.Add($dot)
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $text
        $lbl.ForeColor = [System.Drawing.Color]::FromArgb(170, 170, 180)
        $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 8)
        $lbl.Location = New-Object System.Drawing.Point(($xInt + 18), 8)
        $lbl.Size = New-Object System.Drawing.Size(130, 14)
        $pnlLegend.Controls.Add($lbl)
    }
    & $mkLegItem "Primar (neuester Login)"  ([System.Drawing.Color]::FromArgb(0, 183, 235))    10
    & $mkLegItem "< 30 Tage inaktiv"        ([System.Drawing.Color]::FromArgb(80, 200, 80))   175
    & $mkLegItem "30-90 Tage inaktiv"       ([System.Drawing.Color]::FromArgb(220, 180, 40))  320
    & $mkLegItem "> 90 Tage inaktiv"        ([System.Drawing.Color]::FromArgb(210, 80, 80))   455
    & $mkLegItem "Unbekanntes Login"        ([System.Drawing.Color]::FromArgb(130, 130, 140)) 595

    # -- Grid -----------------------------------------------------------------
    $gridMulti = New-Object System.Windows.Forms.DataGridView
    $gridMulti.Location = New-Object System.Drawing.Point(0, 80)
    $gridMulti.Size = New-Object System.Drawing.Size(1060, 490)
    $gridMulti.Anchor = "Top,Bottom,Left,Right"
    $gridMulti.BackgroundColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
    $gridMulti.GridColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
    $gridMulti.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 40)
    $gridMulti.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 215)
    $gridMulti.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(50, 65, 90)
    $gridMulti.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    $gridMulti.DefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $gridMulti.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
    $gridMulti.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(0, 183, 235)
    $gridMulti.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $gridMulti.ColumnHeadersHeight = 30
    $gridMulti.EnableHeadersVisualStyles = $false
    $gridMulti.ReadOnly = $true
    $gridMulti.AllowUserToAddRows = $false
    $gridMulti.RowHeadersVisible = $false
    $gridMulti.SelectionMode = "FullRowSelect"
    $gridMulti.AutoSizeColumnsMode = "Fill"
    $gridMulti.BorderStyle = "None"
    $gridMulti.RowTemplate.Height = 26
    $frmMulti.Controls.Add($gridMulti)

    # -- DataTable aufbauen ---------------------------------------------------
    $dtMulti = New-Object System.Data.DataTable
    [void]$dtMulti.Columns.Add("Typ")            # "PRIMARY" / "KOPIE"
    [void]$dtMulti.Columns.Add("Username")
    [void]$dtMulti.Columns.Add("Server")
    [void]$dtMulti.Columns.Add("Status")
    [void]$dtMulti.Columns.Add("Letzter Login")
    [void]$dtMulti.Columns.Add("Tage inaktiv")
    [void]$dtMulti.Columns.Add("Profilgroesse")
    [void]$dtMulti.Columns.Add("Profilpfad")
    [void]$dtMulti.Columns.Add("Profile auf N Servern")
    [void]$dtMulti.Columns.Add("Empfehlung")
    # Interne Sortierhilfe (wird spaeter ausgeblendet)
    [void]$dtMulti.Columns.Add("_SortKey")

    # Zeilenfarbinfo: wir speichern (RowIndex -> Color) fuer CellFormatting
    $script:MultiRowColors = @{}
    $rowIdx = 0

    foreach ($entry in $multiUsers) {
        $u        = $entry.Key
        $profiles = $entry.Value

        # Primaerserver bestimmen: neuester LastLogin (aktive Session schlaegt immer)
        $primarySrv = $null
        $newestDate = [datetime]::MinValue

        # 1. Zuerst aktive Session suchen
        $activeProf = $profiles | Where-Object { $_.State -eq "Active" } | Select-Object -First 1
        if ($activeProf) {
            $primarySrv = $activeProf.Server
        } else {
            # 2. Neuester Last Login
            foreach ($p in $profiles) {
                $d = Parse-LoginDate $p.LastLogin
                if ($d -and $d -gt $newestDate) {
                    $newestDate = $d
                    $primarySrv = $p.Server
                }
            }
        }

        # Zeilen sortieren: Primary zuerst, dann nach Login absteigend
        $sorted = @()
        $sorted += $profiles | Where-Object { $_.Server -eq $primarySrv }
        $sorted += $profiles | Where-Object { $_.Server -ne $primarySrv } |
                   Sort-Object {
                       $d = Parse-LoginDate $_.LastLogin
                       if ($d) { -$d.Ticks } else { [long]::MaxValue }
                   }

        foreach ($p in $sorted) {
            $isPrimary = ($p.Server -eq $primarySrv)
            $typ = if ($isPrimary) { "* PRIM." } else { "  Kopie" }

            # Tage inaktiv berechnen
            $daysInactive = "-"
            $loginDate    = Parse-LoginDate $p.LastLogin
            if ($loginDate) {
                $daysInactive = [math]::Round(($scanTime - $loginDate).TotalDays, 0).ToString()
            }

            # Profilgroesse (aus Haupttabelle, falls Phase 2 gelaufen)
            $groesse = if ($p.Groesse -and $p.Groesse -ne "N/A" -and $p.Groesse -ne "-") {
                $p.Groesse
            } else { "N/A" }

            # Empfehlung
            $empfehlung = ""
            if ($isPrimary) {
                if ($p.State -eq "Active") {
                    $empfehlung = "Aktiv in Verwendung"
                } else {
                    $empfehlung = "Behalten (neuester Login)"
                }
            } else {
                if ($daysInactive -ne "-" -and [int]$daysInactive -gt 90) {
                    $empfehlung = "Bereinigen empfohlen (> 90 Tage)"
                } elseif ($daysInactive -ne "-" -and [int]$daysInactive -gt 30) {
                    $empfehlung = "Pruefen (30-90 Tage inaktiv)"
                } elseif ($daysInactive -eq "-") {
                    $empfehlung = "Pruefen (Login unbekannt)"
                } else {
                    $empfehlung = "Kopie - noch aktiv genutzt"
                }
            }

            $sortPrio = if ($isPrimary) { '0' } else { '1' }
            [void]$dtMulti.Rows.Add(
                $typ, $u, $p.Server, $p.State,
                $p.LastLogin, $daysInactive, $groesse,
                $p.Path, $profiles.Count, $empfehlung,
                ($u + "_" + $sortPrio + "_" + $p.Server)
            )

            # Zeilenfarbe vorberechnen
            $rowColor = if ($isPrimary) {
                [System.Drawing.Color]::FromArgb(28, 55, 75)        # blau (Primary)
            } elseif ($daysInactive -eq "-") {
                [System.Drawing.Color]::FromArgb(36, 36, 40)        # grau
            } elseif ([int]$daysInactive -gt 90) {
                [System.Drawing.Color]::FromArgb(65, 28, 28)        # rot
            } elseif ([int]$daysInactive -gt 30) {
                [System.Drawing.Color]::FromArgb(60, 52, 20)        # gelb
            } else {
                [System.Drawing.Color]::FromArgb(22, 50, 30)        # gruen
            }
            $script:MultiRowColors[$rowIdx] = $rowColor
            $rowIdx++
        }

        # Trennzeile zwischen Usern (leer)
        $sepLine = "-" * 21
        [void]$dtMulti.Rows.Add("", "", $sepLine, "", "", "", "", "", "", "", ($u + "_9"))
        $script:MultiRowColors[$rowIdx] = [System.Drawing.Color]::FromArgb(28, 28, 30)
        $rowIdx++
    }

    $gridMulti.DataSource = $dtMulti

    # Spalten konfigurieren
    $gridMulti.Columns["_SortKey"].Visible  = $false
    $gridMulti.Columns["Typ"].FillWeight                  = 7
    $gridMulti.Columns["Username"].FillWeight             = 12
    $gridMulti.Columns["Server"].FillWeight               = 12
    $gridMulti.Columns["Status"].FillWeight               = 9
    $gridMulti.Columns["Letzter Login"].FillWeight        = 13
    $gridMulti.Columns["Tage inaktiv"].FillWeight         = 8
    $gridMulti.Columns["Profilgroesse"].FillWeight        = 9
    $gridMulti.Columns["Profilpfad"].FillWeight           = 18
    $gridMulti.Columns["Profile auf N Servern"].FillWeight = 7
    $gridMulti.Columns["Empfehlung"].FillWeight           = 16

    # Spalten-Header umbenennen
    $gridMulti.Columns["Profile auf N Servern"].HeaderText = "Anz. Server"

    # -- CellFormatting: Hintergrundfarbe + Schriftfarbe je Typ ---------------
    $gridMulti.Add_CellFormatting({
        param($s2, $e2)
        $ri = $e2.RowIndex
        if ($ri -lt 0) { return }
        if ($script:MultiRowColors.ContainsKey($ri)) {
            $e2.CellStyle.BackColor = $script:MultiRowColors[$ri]
        }

        # Typ-Spalte einfaerben
        if ($e2.ColumnIndex -eq $gridMulti.Columns["Typ"].Index) {
            $val = $gridMulti.Rows[$ri].Cells["Typ"].Value
            if ($val -match "PRIM") {
                $e2.CellStyle.ForeColor = [System.Drawing.Color]::FromArgb(0, 183, 235)
                $e2.CellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            } else {
                $e2.CellStyle.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 130)
            }
        }

        # Tage-inaktiv einfaerben
        if ($e2.ColumnIndex -eq $gridMulti.Columns["Tage inaktiv"].Index) {
            $val = $gridMulti.Rows[$ri].Cells["Tage inaktiv"].Value
            if ($val -ne "-" -and $val -ne "") {
                try {
                    $d = [int]$val
                    $e2.CellStyle.ForeColor = if ($d -gt 90) {
                        [System.Drawing.Color]::FromArgb(220, 90, 90)
                    } elseif ($d -gt 30) {
                        [System.Drawing.Color]::FromArgb(220, 180, 40)
                    } else {
                        [System.Drawing.Color]::FromArgb(80, 200, 80)
                    }
                    $e2.CellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
                } catch { }
            }
        }

        # Empfehlung einfaerben
        if ($e2.ColumnIndex -eq $gridMulti.Columns["Empfehlung"].Index) {
            $val = "$($gridMulti.Rows[$ri].Cells["Empfehlung"].Value)"
            $e2.CellStyle.ForeColor = if ($val -match "empfohlen") {
                [System.Drawing.Color]::FromArgb(220, 90, 90)
            } elseif ($val -match "Pruefen") {
                [System.Drawing.Color]::FromArgb(220, 180, 40)
            } elseif ($val -match "Behalten|Aktiv") {
                [System.Drawing.Color]::FromArgb(0, 183, 235)
            } elseif ($val -match "Kopie") {
                [System.Drawing.Color]::FromArgb(80, 200, 80)
            } else {
                [System.Drawing.Color]::FromArgb(170, 170, 180)
            }
        }

        # Status einfaerben
        if ($e2.ColumnIndex -eq $gridMulti.Columns["Status"].Index) {
            $val = "$($gridMulti.Rows[$ri].Cells["Status"].Value)"
            $e2.CellStyle.ForeColor = switch ($val) {
                "Active"       { [System.Drawing.Color]::FromArgb(80, 200, 80) }
                "Disconnected" { [System.Drawing.Color]::FromArgb(220, 180, 40) }
                "Offline"      { [System.Drawing.Color]::FromArgb(140, 140, 150) }
                default        { [System.Drawing.Color]::FromArgb(170, 170, 180) }
            }
        }
    })

    # -- Fusszeile mit Statistik + Export -------------------------------------
    $pnlFooter = New-Object System.Windows.Forms.Panel
    $pnlFooter.Location = New-Object System.Drawing.Point(0, 570)
    $pnlFooter.Size = New-Object System.Drawing.Size(1060, 40)
    $pnlFooter.BackColor = [System.Drawing.Color]::FromArgb(33, 33, 36)
    $pnlFooter.Anchor = "Bottom,Left,Right"
    $frmMulti.Controls.Add($pnlFooter)

    # Statistik berechnen
    $totalKopien       = ($dtMulti.Rows | Where-Object { $_["Typ"] -match "Kopie" }).Count
    $bereinigenCount   = ($dtMulti.Rows | Where-Object { $_["Empfehlung"] -match "empfohlen" }).Count
    $pruefenCount      = ($dtMulti.Rows | Where-Object { $_["Empfehlung"] -match "Pruefen" }).Count

    $lblStats = New-Object System.Windows.Forms.Label
    $lblStats.Text = "  $($multiUsers.Count) User  |  $totalKopien Profilkopien  |  $bereinigenCount Bereinigung empfohlen  |  $pruefenCount zu pruefen"
    $lblStats.Location = New-Object System.Drawing.Point(0, 10)
    $lblStats.Size = New-Object System.Drawing.Size(700, 20)
    $lblStats.ForeColor = [System.Drawing.Color]::FromArgb(155, 155, 165)
    $lblStats.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pnlFooter.Controls.Add($lblStats)

    $btnExportMulti = New-Object System.Windows.Forms.Button
    $btnExportMulti.Text = "Export CSV"
    $btnExportMulti.Location = New-Object System.Drawing.Point(830, 7)
    $btnExportMulti.Size = New-Object System.Drawing.Size(100, 26)
    $btnExportMulti.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
    $btnExportMulti.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 215)
    $btnExportMulti.FlatStyle = "Flat"
    $btnExportMulti.FlatAppearance.BorderSize = 1
    $btnExportMulti.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(75, 75, 80)
    $btnExportMulti.Anchor = "Bottom,Right"
    $pnlFooter.Controls.Add($btnExportMulti)

    $btnExportMulti.Add_Click({
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter = "CSV Files (*.csv)|*.csv"
        $dlg.FileName = "MultiServer_Users_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        if ($dlg.ShowDialog() -eq "OK") {
            # _SortKey aus Export entfernen
            $exportTable = $dtMulti.Copy()
            $exportTable.Columns.Remove("_SortKey")
            $exportTable | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Exportiert nach:`n$($dlg.FileName)", "OK", "OK", "Information")
        }
    })

    $btnExportNurBereinigen = New-Object System.Windows.Forms.Button
    $btnExportNurBereinigen.Text = "Nur: Bereinigen"
    $btnExportNurBereinigen.Location = New-Object System.Drawing.Point(935, 7)
    $btnExportNurBereinigen.Size = New-Object System.Drawing.Size(110, 26)
    $btnExportNurBereinigen.BackColor = [System.Drawing.Color]::FromArgb(70, 30, 30)
    $btnExportNurBereinigen.ForeColor = [System.Drawing.Color]::FromArgb(220, 160, 160)
    $btnExportNurBereinigen.FlatStyle = "Flat"
    $btnExportNurBereinigen.FlatAppearance.BorderSize = 1
    $btnExportNurBereinigen.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(120, 50, 50)
    $btnExportNurBereinigen.Anchor = "Bottom,Right"
    $pnlFooter.Controls.Add($btnExportNurBereinigen)

    $btnExportNurBereinigen.Add_Click({
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter = "CSV Files (*.csv)|*.csv"
        $dlg.FileName = "ZuBereinigen_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        if ($dlg.ShowDialog() -eq "OK") {
            $exportTable = $dtMulti.Copy()
            $exportTable.Columns.Remove("_SortKey")
            $filtered = $exportTable.Select("Empfehlung LIKE '%empfohlen%' OR Empfehlung LIKE '%Pruefen%'")
            if ($filtered.Count -gt 0) {
                $filtered | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
                [System.Windows.Forms.MessageBox]::Show(
                    "$($filtered.Count) Eintraege exportiert nach:`n$($dlg.FileName)", "OK", "OK", "Information")
            } else {
                [System.Windows.Forms.MessageBox]::Show("Keine Eintraege fuer Bereinigung gefunden.", "Hinweis", "OK", "Information")
            }
        }
    })

    # Anker fuer Grid korrigieren wenn Fenster groesser gezogen wird
    $frmMulti.Add_Resize({
        $gridMulti.Size = New-Object System.Drawing.Size(
            ($frmMulti.ClientSize.Width),
            ($frmMulti.ClientSize.Height - 80 - 40))
        $pnlHeader.Width  = $frmMulti.ClientSize.Width
        $pnlLegend.Width  = $frmMulti.ClientSize.Width
        $pnlFooter.Width  = $frmMulti.ClientSize.Width
        $pnlFooter.Top    = $frmMulti.ClientSize.Height - 40
        $lblStats.Width   = $frmMulti.ClientSize.Width - 240
    })

    [void]$frmMulti.ShowDialog()
})
# =============================================
#  ENDE MULTI-SERVER-USER ANALYSE
# =============================================

$btnAbort.Add_Click({
    $script:Aborted = $true
    Write-Log "Abbruch angefordert..." "WARN"
    $statusBar.Text = "Wird abgebrochen..."
})

$btnClear.Add_Click({
    $script:DataTable.Rows.Clear()
    $listSummary.Items.Clear()
    $script:ScanTimes      = @{}
    $script:ScanTimePhase1 = 0
    $script:ScanTimePhase2 = 0
    Refresh-Grid
    $statusBar.Text = "Results cleared."
    $progressBar.Value = 0
})

$btnExport.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = "CSV Files (*.csv)|*.csv"
    $dlg.FileName = "TS_Users_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    if ($dlg.ShowDialog() -eq "OK") {
        $script:DataTable | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Exported to:`n$($dlg.FileName)", "Export OK",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

$btnSaveList.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = "Text Files (*.txt)|*.txt"
    $dlg.FileName = "ServerList.txt"
    if ($dlg.ShowDialog() -eq "OK") {
        $listServers.Items | Out-File -FilePath $dlg.FileName -Encoding UTF8
    }
})

$btnLoadList.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Text Files (*.txt)|*.txt"
    if ($dlg.ShowDialog() -eq "OK") {
        $lines = Get-Content $dlg.FileName | Where-Object { $_.Trim() -ne "" }
        foreach ($line in $lines) {
            if (-not $listServers.Items.Contains($line.Trim())) {
                [void]$listServers.Items.Add($line.Trim())
            }
        }
    }
})

# -- HELPER: TrustedHosts sicherstellen -------
function Ensure-TrustedHosts {
    param([string[]]$Servers)
    try {
        $current = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Client" `
                        -Name "TrustedHosts" -ErrorAction SilentlyContinue).TrustedHosts
        if ($null -eq $current) { $current = "" }
    } catch { $current = "" }

    $missing = $Servers | Where-Object {
        $current -ne "*" -and $current -notmatch [regex]::Escape($_)
    }
    if ($missing.Count -eq 0) { return $true }

    $msg  = "Folgende Server sind noch nicht in der WinRM TrustedHosts-Liste:`n`n"
    $msg += ($missing -join "`n")
    $msg += "`n`nSollen diese jetzt automatisch hinzugefuegt werden?"
    $result = [System.Windows.Forms.MessageBox]::Show(
        $msg, "TrustedHosts konfigurieren",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)

    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return $false }
    try {
        $newList = if ($current -eq "") { $missing -join "," } else { "$current," + ($missing -join ",") }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Client" `
            -Name "TrustedHosts" -Value $newList -ErrorAction Stop
        Write-Log "TrustedHosts gesetzt: $newList" "OK"
        return $true
    } catch {
        try {
            $winrmResult = & winrm.cmd set winrm/config/client "@{TrustedHosts=`"$newList`"}" 2>&1
            if ($LASTEXITCODE -ne 0) { throw $winrmResult }
            Write-Log "TrustedHosts gesetzt via winrm.cmd" "OK"
            return $true
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Fehler:`n$($_.Exception.Message)`n`nManuell ausfuehren:`nwinrm set winrm/config/client `"@{TrustedHosts=`"*`"}`"",
                "Fehler", "OK", "Error")
            return $false
        }
    }
}

# -- HELPER: Profilgroesse async nachladen --
function Start-ProfileSizeJob {
    param($Server, [System.Management.Automation.PSCredential]$Credential)

    $sizeBlock = {
        param($Srv, $Cred)
        $sessionOpt = New-PSSessionOption -OpenTimeout 30000 -OperationTimeout 1800000
        $remoteSize = {
            $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
                        Where-Object { -not $_.Special -and $_.LocalPath }
            $total = @($profiles).Count
            $i = 0
            foreach ($prof in $profiles) {
                $i++
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sizeMB = -1
                try {
                    $totalBytes = [long]0
                    # Nur echte Dateien mit gueltiger Length (keine Junctions/Symlinks/gesperrte Objekte)
                    $rootFiles = Get-ChildItem -Path $prof.LocalPath -File -Force -ErrorAction SilentlyContinue |
                                 Where-Object { $_ -ne $null -and $_.PSObject.Properties["Length"] -and $_.Length -ne $null }
                    foreach ($f in $rootFiles) {
                        try { $totalBytes += [long]$f.Length } catch { }
                    }
                    $subFolders = Get-ChildItem -Path $prof.LocalPath -Directory -Force -ErrorAction SilentlyContinue |
                                  Where-Object { $_ -ne $null -and -not $_.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) }
                    foreach ($folder in $subFolders) {
                        try {
                            $subFiles = Get-ChildItem -Path $folder.FullName -Recurse -Force -File `
                                -ErrorAction SilentlyContinue |
                                Where-Object { $_ -ne $null -and $_.PSObject.Properties["Length"] -and $_.Length -ne $null }
                            foreach ($f in $subFiles) {
                                try { $totalBytes += [long]$f.Length } catch { }
                            }
                        } catch { }
                    }
                    $sizeMB = [math]::Round($totalBytes / 1MB, 2)
                } catch { $sizeMB = -1 }
                $sw.Stop()
                [PSCustomObject]@{
                    Path   = $prof.LocalPath
                    SizeMB = $sizeMB
                    Index  = $i
                    Total  = $total
                    Secs   = [math]::Round($sw.Elapsed.TotalSeconds, 1)
                }
            }
        }
        try {
            if ($Cred) {
                Invoke-Command -ComputerName $Srv -Credential $Cred `
                    -ScriptBlock $remoteSize -SessionOption $sessionOpt -ErrorAction Stop
            } else {
                Invoke-Command -ComputerName $Srv `
                    -ScriptBlock $remoteSize -SessionOption $sessionOpt -ErrorAction Stop
            }
            # Abschluss-Sentinel damit der aufrufende Code weiss: kein Fehler
            [PSCustomObject]@{ Path = "DONE"; SizeMB = 0; Index = -1; Total = 0; Secs = 0 }
        } catch {
            [PSCustomObject]@{ Path = "ERROR"; SizeMB = -1; Index = 0; Total = 0; Secs = 0;
                               ErrorMsg = $_.Exception.Message }
        }
    }
    return Start-Job -ScriptBlock $sizeBlock -ArgumentList $Server, $Credential
}

# --- Hilfsfunktion: Ergebnis-Grid-Fenster anzeigen ---
function Show-ProfileResultWindow {
    param(
        [string]$Title,
        [string]$InfoText,
        [string]$ExportPrefix,
        $DataRows,
        [datetime]$ScanTime
    )

    $frmR = New-Object System.Windows.Forms.Form
    $frmR.Text = $Title
    $frmR.Size = New-Object System.Drawing.Size(900, 560)
    $frmR.StartPosition = "CenterParent"
    $frmR.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $frmR.ForeColor = [System.Drawing.Color]::White

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = $InfoText
    $lblInfo.Location = New-Object System.Drawing.Point(10, 10)
    $lblInfo.Size = New-Object System.Drawing.Size(860, 20)
    $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $frmR.Controls.Add($lblInfo)

    $g = New-Object System.Windows.Forms.DataGridView
    $g.Location = New-Object System.Drawing.Point(10, 38)
    $g.Size = New-Object System.Drawing.Size(865, 460)
    $g.Anchor = "Top,Bottom,Left,Right"
    $g.BackgroundColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $g.GridColor = [System.Drawing.Color]::FromArgb(55, 55, 58)
    $g.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 40)
    $g.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
    $g.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(50, 65, 85)
    $g.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    $g.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(42, 42, 45)
    $g.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(0, 183, 235)
    $g.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $g.EnableHeadersVisualStyles = $false
    $g.ReadOnly = $true
    $g.AllowUserToAddRows = $false
    $g.RowHeadersVisible = $false
    $g.SelectionMode = "FullRowSelect"
    $g.AutoSizeColumnsMode = "Fill"
    $g.BorderStyle = "None"
    $frmR.Controls.Add($g)

    $dt = New-Object System.Data.DataTable
    [void]$dt.Columns.Add("Server")
    [void]$dt.Columns.Add("Username")
    [void]$dt.Columns.Add("Status")
    [void]$dt.Columns.Add("Letzter Login")
    [void]$dt.Columns.Add("Tage inaktiv")
    [void]$dt.Columns.Add("Profilgroesse")
    [void]$dt.Columns.Add("Profilpfad")

    foreach ($row in $DataRows) {
        $days = "-"
        try {
            $d = [datetime]::ParseExact($row["Last Login"], "dd.MM.yyyy HH:mm",
                     [System.Globalization.CultureInfo]::InvariantCulture)
            $days = [math]::Round(($ScanTime - $d).TotalDays, 0).ToString()
        } catch { }
        [void]$dt.Rows.Add(
            $row["Server"], $row["Username"], $row["State"],
            $row["Last Login"], $days, $row["Groesse"], $row["Profile Path"])
    }
    $g.DataSource = $dt

    # Tage-Spalte einfaerben
    $g.Add_CellFormatting({
        param($s2,$e2)
        if ($e2.ColumnIndex -eq $g.Columns["Tage inaktiv"].Index -and $e2.RowIndex -ge 0) {
            $val = "$($g.Rows[$e2.RowIndex].Cells["Tage inaktiv"].Value)"
            try {
                $d = [int]$val
                $e2.CellStyle.ForeColor = if ($d -gt 180) { [System.Drawing.Color]::FromArgb(220,80,80) }
                    elseif ($d -gt 90)   { [System.Drawing.Color]::FromArgb(220,160,40) }
                    else                 { [System.Drawing.Color]::FromArgb(180,180,180) }
            } catch { }
        }
    })

    $btnExp = New-Object System.Windows.Forms.Button
    $btnExp.Text = "Export CSV"
    $btnExp.Location = New-Object System.Drawing.Point(10, 508)
    $btnExp.Size = New-Object System.Drawing.Size(100, 26)
    $btnExp.BackColor = [System.Drawing.Color]::FromArgb(52, 52, 55)
    $btnExp.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
    $btnExp.FlatStyle = "Flat"
    $btnExp.FlatAppearance.BorderSize = 1
    $btnExp.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80, 80, 85)
    $frmR.Controls.Add($btnExp)
    $btnExp.Add_Click({
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter = "CSV Files (*.csv)|*.csv"
        $dlg.FileName = "${ExportPrefix}_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        if ($dlg.ShowDialog() -eq "OK") {
            $dt | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
        }
    })
    [void]$frmR.ShowDialog()
}

# -- Alte Profile (nur Datum-Filter) --
$btnOldProfiles.Add_Click({
    $allRows = $script:DataTable.Rows | Where-Object { $_["Status"] -eq "OK" }
    if ($allRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Kein Scan-Ergebnis vorhanden.", "Hinweis", "OK", "Warning")
        return
    }
    $frmCfg = New-Object System.Windows.Forms.Form
    $frmCfg.Text = "Schwellwert: Alte Profile"
    $frmCfg.Size = New-Object System.Drawing.Size(300, 150)
    $frmCfg.StartPosition = "CenterParent"
    $frmCfg.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 40)
    $frmCfg.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
    $frmCfg.FormBorderStyle = "FixedDialog"
    $frmCfg.MaximizeBox = $false

    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = "Nicht genutzt seit (Tage):"
    $l1.Location = New-Object System.Drawing.Point(15,20); $l1.Size = New-Object System.Drawing.Size(180,20)
    $l1.ForeColor = [System.Drawing.Color]::FromArgb(180,180,180); $frmCfg.Controls.Add($l1)
    $txtDays = New-Object System.Windows.Forms.TextBox; $txtDays.Text = "90"
    $txtDays.Location = New-Object System.Drawing.Point(205,18); $txtDays.Size = New-Object System.Drawing.Size(60,22)
    $txtDays.BackColor = [System.Drawing.Color]::FromArgb(52,52,55); $txtDays.ForeColor = [System.Drawing.Color]::White
    $txtDays.BorderStyle = "FixedSingle"; $frmCfg.Controls.Add($txtDays)
    $btnOk = New-Object System.Windows.Forms.Button; $btnOk.Text = "Analysieren"
    $btnOk.Location = New-Object System.Drawing.Point(80,70); $btnOk.Size = New-Object System.Drawing.Size(120,28)
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(52,52,55); $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.FlatStyle = "Flat"; $btnOk.DialogResult = "OK"; $frmCfg.Controls.Add($btnOk)
    $frmCfg.AcceptButton = $btnOk
    if ($frmCfg.ShowDialog() -ne "OK") { return }

    $minDays = [int]$txtDays.Text
    $scanTime = Get-Date
    $filtered = $allRows | Where-Object {
        if ($minDays -gt 0 -and $_["Last Login"] -ne "Unbekannt") {
            try {
                $d = [datetime]::ParseExact($_["Last Login"], "dd.MM.yyyy HH:mm",
                         [System.Globalization.CultureInfo]::InvariantCulture)
                return ($scanTime - $d).TotalDays -ge $minDays
            } catch { }
        }
        return $false
    }
    if ($filtered.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Keine Profile aelter als $minDays Tage gefunden.", "Kein Ergebnis", "OK", "Information")
        return
    }
    $sorted = $filtered | Sort-Object { $_["Last Login"] }
    Show-ProfileResultWindow -Title "Alte Profile (>= $minDays Tage)" `
        -InfoText "$($filtered.Count) Profile nicht genutzt seit >= $minDays Tagen" `
        -ExportPrefix "AlteProfile" -DataRows $sorted -ScanTime $scanTime
})

# -- Grosse Profile (nur Groessen-Filter) --
$btnLargeProfiles.Add_Click({
    $allRows = $script:DataTable.Rows | Where-Object { $_["Status"] -eq "OK" }
    if ($allRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Kein Scan-Ergebnis vorhanden.", "Hinweis", "OK", "Warning")
        return
    }
    $hasSizes = ($allRows | Where-Object { $_["Groesse"] -ne "N/A" -and $_["Groesse"] -ne "-" -and $_["Groesse"] -ne "" }).Count -gt 0
    if (-not $hasSizes) {
        [System.Windows.Forms.MessageBox]::Show(
            "Keine Profilgroessen vorhanden.`nBitte Scan mit aktivierter 'Profilgroesse'-Checkbox wiederholen.",
            "Keine Daten", "OK", "Warning")
        return
    }
    $frmCfg = New-Object System.Windows.Forms.Form
    $frmCfg.Text = "Schwellwert: Grosse Profile"
    $frmCfg.Size = New-Object System.Drawing.Size(300, 150)
    $frmCfg.StartPosition = "CenterParent"
    $frmCfg.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 40)
    $frmCfg.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
    $frmCfg.FormBorderStyle = "FixedDialog"
    $frmCfg.MaximizeBox = $false

    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = "Groesser als (MB):"
    $l1.Location = New-Object System.Drawing.Point(15,20); $l1.Size = New-Object System.Drawing.Size(180,20)
    $l1.ForeColor = [System.Drawing.Color]::FromArgb(180,180,180); $frmCfg.Controls.Add($l1)
    $txtMB = New-Object System.Windows.Forms.TextBox; $txtMB.Text = "1024"
    $txtMB.Location = New-Object System.Drawing.Point(205,18); $txtMB.Size = New-Object System.Drawing.Size(60,22)
    $txtMB.BackColor = [System.Drawing.Color]::FromArgb(52,52,55); $txtMB.ForeColor = [System.Drawing.Color]::White
    $txtMB.BorderStyle = "FixedSingle"; $frmCfg.Controls.Add($txtMB)
    $btnOk = New-Object System.Windows.Forms.Button; $btnOk.Text = "Analysieren"
    $btnOk.Location = New-Object System.Drawing.Point(80,70); $btnOk.Size = New-Object System.Drawing.Size(120,28)
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(52,52,55); $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.FlatStyle = "Flat"; $btnOk.DialogResult = "OK"; $frmCfg.Controls.Add($btnOk)
    $frmCfg.AcceptButton = $btnOk
    if ($frmCfg.ShowDialog() -ne "OK") { return }

    $minMB = [int]$txtMB.Text
    $scanTime = Get-Date
    $filtered = $allRows | Where-Object {
        $sizeStr = $_["Groesse"]
        if ($sizeStr -eq "N/A" -or $sizeStr -eq "-" -or $sizeStr -eq "") { return $false }
        try {
            $sizeVal = 0.0
            if ($sizeStr -match "([\d.,]+)\s*GB") { $sizeVal = [double]($Matches[1] -replace ",",".") * 1024 }
            elseif ($sizeStr -match "([\d.,]+)\s*MB") { $sizeVal = [double]($Matches[1] -replace ",",".") }
            return $sizeVal -ge $minMB
        } catch { return $false }
    }
    if ($filtered.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Keine Profile groesser als $minMB MB gefunden.", "Kein Ergebnis", "OK", "Information")
        return
    }
    # Absteigend nach Groesse sortieren
    $sorted = $filtered | Sort-Object {
        $s = $_["Groesse"]
        $v = 0.0
        if ($s -match "([\d.,]+)\s*GB") { $v = [double]($Matches[1] -replace ",",".") * 1024 }
        elseif ($s -match "([\d.,]+)\s*MB") { $v = [double]($Matches[1] -replace ",",".") }
        -$v
    }
    Show-ProfileResultWindow -Title "Grosse Profile (>= $minMB MB)" `
        -InfoText "$($filtered.Count) Profile groesser als $minMB MB  |  absteigend sortiert" `
        -ExportPrefix "GrosseProfile" -DataRows $sorted -ScanTime $scanTime
})

# -- Aktivitaetsanalyse via EventLog (4624/4634) --
$btnEventLogCheck.Add_Click({
    $allRows = $script:DataTable.Rows | Where-Object { $_["Status"] -eq "OK" }
    $serverList = @($listServers.Items)
    if ($serverList.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Bitte zuerst Server hinzufuegen.", "Hinweis", "OK", "Warning")
        return
    }
    if ($null -eq $script:Cred) {
        [System.Windows.Forms.MessageBox]::Show("Bitte zuerst Anmeldedaten setzen.", "Hinweis", "OK", "Warning")
        return
    }

    # Konfig-Dialog: Zeitraum
    $frmCfg = New-Object System.Windows.Forms.Form
    $frmCfg.Text = "Aktivitaetsanalyse - Einstellungen"
    $frmCfg.Size = New-Object System.Drawing.Size(340, 170)
    $frmCfg.StartPosition = "CenterParent"
    $frmCfg.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 40)
    $frmCfg.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
    $frmCfg.FormBorderStyle = "FixedDialog"
    $frmCfg.MaximizeBox = $false

    $mkL = { param($t,$x,$y,$w=200)
        $l = New-Object System.Windows.Forms.Label; $l.Text=$t
        $l.Location=New-Object System.Drawing.Point([int]$x,[int]$y)
        $l.Size=New-Object System.Drawing.Size([int]$w,20)
        $l.ForeColor=[System.Drawing.Color]::FromArgb(180,180,180); $frmCfg.Controls.Add($l) }
    $mkT = { param($v,$x,$y)
        $t = New-Object System.Windows.Forms.TextBox; $t.Text=$v
        $t.Location=New-Object System.Drawing.Point([int]$x,[int]$y)
        $t.Size=New-Object System.Drawing.Size(60,22)
        $t.BackColor=[System.Drawing.Color]::FromArgb(52,52,55); $t.ForeColor=[System.Drawing.Color]::White
        $t.BorderStyle="FixedSingle"; $frmCfg.Controls.Add($t); $t }

    & $mkL "Zeitraum (Tage zurueck):" 15 20
    $txtDaysBack = & $mkT "30" 250 18
    & $mkL "Als inaktiv markieren ab (Tage):" 15 50
    $txtInactiveDays = & $mkT "30" 250 48
    & $mkL "(0 Events in Zeitraum = inaktiv)" 15 72 260

    $btnOk = New-Object System.Windows.Forms.Button; $btnOk.Text = "Analysieren"
    $btnOk.Location = New-Object System.Drawing.Point(100, 100); $btnOk.Size = New-Object System.Drawing.Size(120,28)
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(52,52,55); $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.FlatStyle = "Flat"; $btnOk.DialogResult = "OK"; $frmCfg.Controls.Add($btnOk)
    $frmCfg.AcceptButton = $btnOk
    if ($frmCfg.ShowDialog() -ne "OK") { return }

    $daysBack     = [int]$txtDaysBack.Text
    $inactiveDays = [int]$txtInactiveDays.Text

    # Ergebnis-Fenster
    $frmAkt = New-Object System.Windows.Forms.Form
    $frmAkt.Text = "Aktivitaetsanalyse (letzte $daysBack Tage)"
    $frmAkt.Size = New-Object System.Drawing.Size(1060, 660)
    $frmAkt.MinimumSize = New-Object System.Drawing.Size(900, 500)
    $frmAkt.StartPosition = "CenterParent"
    $frmAkt.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
    $frmAkt.ForeColor = [System.Drawing.Color]::White

    # Header
    $pnlH = New-Object System.Windows.Forms.Panel
    $pnlH.Location = New-Object System.Drawing.Point(0,0); $pnlH.Size = New-Object System.Drawing.Size(1060,44)
    $pnlH.BackColor = [System.Drawing.Color]::FromArgb(38,38,42); $pnlH.Anchor = "Top,Left,Right"
    $frmAkt.Controls.Add($pnlH)
    $lblHdr = New-Object System.Windows.Forms.Label
    $lblHdr.Text = "AKTIVITAETSANALYSE  -  Zeitraum: letzte $daysBack Tage  |  Inaktiv ab: $inactiveDays Tagen ohne Login"
    $lblHdr.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblHdr.ForeColor = [System.Drawing.Color]::FromArgb(0,183,235)
    $lblHdr.Location = New-Object System.Drawing.Point(12,12); $lblHdr.Size = New-Object System.Drawing.Size(900,20)
    $pnlH.Controls.Add($lblHdr)

    # Tabs
    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Location = New-Object System.Drawing.Point(0,44)
    $tabs.Size = New-Object System.Drawing.Size(1060, 560)
    $tabs.Anchor = "Top,Bottom,Left,Right"
    $tabs.BackColor = [System.Drawing.Color]::FromArgb(28,28,30)
    $tabs.DrawMode = "OwnerDrawFixed"
    $tabs.ItemSize = New-Object System.Drawing.Size(140, 26)
    $frmAkt.Controls.Add($tabs)

    # Tab-Styling
    $tabs.Add_DrawItem({
        param($s2,$e2)
        $tab = $tabs.TabPages[$e2.Index]
        $brush = if ($e2.Index -eq $tabs.SelectedIndex) {
            New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50,65,85))
        } else {
            New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(38,38,42))
        }
        $e2.Graphics.FillRectangle($brush, $e2.Bounds)
        $brush.Dispose()
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,200,210))
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = "Center"; $sf.LineAlignment = "Center"
        $rectF = New-Object System.Drawing.RectangleF(
            [float]$e2.Bounds.X, [float]$e2.Bounds.Y,
            [float]$e2.Bounds.Width, [float]$e2.Bounds.Height)
        $e2.Graphics.DrawString($tab.Text, $tabs.Font, $textBrush, $rectF, $sf)
        $textBrush.Dispose()
    })

    function New-DarkTab {
        param([string]$Name)
        $tp = New-Object System.Windows.Forms.TabPage
        $tp.Text = $Name
        $tp.BackColor = [System.Drawing.Color]::FromArgb(28,28,30)
        $tp.ForeColor = [System.Drawing.Color]::White
        $tp.Padding = New-Object System.Windows.Forms.Padding(0)
        $tabs.TabPages.Add($tp)
        return $tp
    }

    function New-ResultGrid {
        param($Parent)
        $g = New-Object System.Windows.Forms.DataGridView
        $g.Dock = "Fill"
        $g.BackgroundColor = [System.Drawing.Color]::FromArgb(28,28,30)
        $g.GridColor = [System.Drawing.Color]::FromArgb(50,50,55)
        $g.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(36,36,40)
        $g.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(210,210,215)
        $g.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(50,65,90)
        $g.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
        $g.DefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI",9)
        $g.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(40,40,45)
        $g.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(0,183,235)
        $g.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
        $g.ColumnHeadersHeight = 28
        $g.EnableHeadersVisualStyles = $false
        $g.ReadOnly = $true
        $g.AllowUserToAddRows = $false
        $g.RowHeadersVisible = $false
        $g.SelectionMode = "FullRowSelect"
        $g.AutoSizeColumnsMode = "Fill"
        $g.BorderStyle = "None"
        $g.RowTemplate.Height = 24
        $Parent.Controls.Add($g)
        return $g
    }

    # Tab 1: Pro User
    $tabUser = New-DarkTab "Pro User"
    $gridUser = New-ResultGrid $tabUser

    $dtUser = New-Object System.Data.DataTable
    [void]$dtUser.Columns.Add("Server")
    [void]$dtUser.Columns.Add("Username")
    [void]$dtUser.Columns.Add("Logins (4624)")
    [void]$dtUser.Columns.Add("Letzter Login (Event)")
    [void]$dtUser.Columns.Add("Abmeldungen (4634)")
    [void]$dtUser.Columns.Add("Letzte Abmeldung")
    [void]$dtUser.Columns.Add("Tage seit Login")
    [void]$dtUser.Columns.Add("Bewertung")

    # Tab 2: Pro Server Zusammenfassung
    $tabSrv = New-DarkTab "Pro Server"
    $gridSrv = New-ResultGrid $tabSrv

    $dtSrv = New-Object System.Data.DataTable
    [void]$dtSrv.Columns.Add("Server")
    [void]$dtSrv.Columns.Add("Log-Groesse")
    [void]$dtSrv.Columns.Add("Logins gesamt")
    [void]$dtSrv.Columns.Add("Aktive User")
    [void]$dtSrv.Columns.Add("Inaktive User")
    [void]$dtSrv.Columns.Add("Log-Status")

    # Tab 3: Inaktive User
    $tabInact = New-DarkTab "Inaktive User"
    $gridInact = New-ResultGrid $tabInact

    $dtInact = New-Object System.Data.DataTable
    [void]$dtInact.Columns.Add("Server")
    [void]$dtInact.Columns.Add("Username")
    [void]$dtInact.Columns.Add("Letzter Login (Profil)")
    [void]$dtInact.Columns.Add("Logins im Zeitraum")
    [void]$dtInact.Columns.Add("Tage ohne Login")
    [void]$dtInact.Columns.Add("Profilgroesse")
    [void]$dtInact.Columns.Add("Empfehlung")

    # Statuszeile
    $pnlFoot = New-Object System.Windows.Forms.Panel
    $pnlFoot.Location = New-Object System.Drawing.Point(0,604)
    $pnlFoot.Size = New-Object System.Drawing.Size(1060,40)
    $pnlFoot.BackColor = [System.Drawing.Color]::FromArgb(33,33,36)
    $pnlFoot.Anchor = "Bottom,Left,Right"
    $frmAkt.Controls.Add($pnlFoot)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Analyse laeuft..."
    $lblStatus.Location = New-Object System.Drawing.Point(10,10)
    $lblStatus.Size = New-Object System.Drawing.Size(700,20)
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(140,140,150)
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI",8)
    $pnlFoot.Controls.Add($lblStatus)

    $btnExpAll = New-Object System.Windows.Forms.Button
    $btnExpAll.Text = "Export CSV"
    $btnExpAll.Location = New-Object System.Drawing.Point(840,7)
    $btnExpAll.Size = New-Object System.Drawing.Size(100,26)
    $btnExpAll.BackColor = [System.Drawing.Color]::FromArgb(50,50,55)
    $btnExpAll.ForeColor = [System.Drawing.Color]::FromArgb(210,210,215)
    $btnExpAll.FlatStyle = "Flat"
    $btnExpAll.FlatAppearance.BorderSize = 1
    $btnExpAll.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(75,75,80)
    $btnExpAll.Anchor = "Bottom,Right"
    $pnlFoot.Controls.Add($btnExpAll)

    $btnExpAll.Add_Click({
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter = "CSV Files (*.csv)|*.csv"
        $dlg.FileName = "Aktivitaet_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        if ($dlg.ShowDialog() -eq "OK") {
            $dtUser | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Exportiert: $($dlg.FileName)", "OK", "OK", "Information")
        }
    })

    # CellFormatting fuer User-Grid
    $gridUser.Add_CellFormatting({
        param($s2,$e2)
        if ($e2.RowIndex -lt 0) { return }
        if ($gridUser.Columns.Count -eq 0) { return }
        if ($null -eq $gridUser.Columns["Bewertung"]) { return }

        try {
            $bewCell = $gridUser.Rows[$e2.RowIndex].Cells["Bewertung"]
            if ($null -eq $bewCell) { return }
            $bew = "$($bewCell.Value)"

            $rowColor = if ($bew -eq "Aktiv") {
                [System.Drawing.Color]::FromArgb(22,50,30)
            } elseif ($bew -eq "Inaktiv") {
                [System.Drawing.Color]::FromArgb(65,28,28)
            } else {
                [System.Drawing.Color]::FromArgb(36,36,40)
            }
            $e2.CellStyle.BackColor = $rowColor

            $colBew = $gridUser.Columns["Bewertung"]
            if ($null -ne $colBew -and $e2.ColumnIndex -eq $colBew.Index) {
                $e2.CellStyle.ForeColor = if ($bew -eq "Aktiv") { [System.Drawing.Color]::FromArgb(80,200,80) }
                    elseif ($bew -eq "Inaktiv") { [System.Drawing.Color]::FromArgb(220,80,80) }
                    else { [System.Drawing.Color]::FromArgb(180,180,180) }
                $e2.CellStyle.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
            }

            $colTage = $gridUser.Columns["Tage seit Login"]
            if ($null -ne $colTage -and $e2.ColumnIndex -eq $colTage.Index) {
                try {
                    $d = [int]"$($gridUser.Rows[$e2.RowIndex].Cells["Tage seit Login"].Value)"
                    $e2.CellStyle.ForeColor = if ($d -gt $inactiveDays) { [System.Drawing.Color]::FromArgb(220,80,80) }
                        elseif ($d -gt 14) { [System.Drawing.Color]::FromArgb(220,160,40) }
                        else { [System.Drawing.Color]::FromArgb(80,200,80) }
                } catch { }
            }
        } catch { }
    })

    [void]$frmAkt.Show()
    $frmAkt.Refresh()
    [System.Windows.Forms.Application]::DoEvents()

    # Remote-Block: Alle Events eines Servers abfragen
    $evtBlock = {
        param($DaysBack)
        $since = (Get-Date).AddDays(-$DaysBack)
        $out = @{}

        # Log-Info
        try {
            $log = Get-WinEvent -ListLog Security -ErrorAction Stop
            $out["LogOK"]    = $true
            $out["LogSizeMB"] = [math]::Round($log.FileSize / 1MB, 1)
            $out["LogMaxMB"]  = [math]::Round($log.MaximumSizeInBytes / 1MB, 1)
        } catch {
            $out["LogOK"] = $false
            $out["LogError"] = $_.Exception.Message
            return $out
        }

        # Login-Events 4624 (nur interaktive + RemoteInteractive, LogonType 2, 10)
        $logins = @()
        try {
            $evts = Get-WinEvent -FilterHashtable @{
                LogName   = "Security"
                Id        = 4624
                StartTime = $since
            } -MaxEvents 5000 -ErrorAction Stop
            foreach ($e in $evts) {
                try {
                    $xml = [xml]$e.ToXml()
                    $ns  = @{e="http://schemas.microsoft.com/win/2004/08/events/event"}
                    $logonType = ($xml.SelectNodes("//e:Data[@Name='LogonType']",$ns) | Select-Object -First 1).'#text'
                    $user      = ($xml.SelectNodes("//e:Data[@Name='TargetUserName']",$ns) | Select-Object -First 1).'#text'
                    # Nur echte Benutzer-Logins (Type 2=Interaktiv, 10=RemoteInteraktiv)
                    if ($logonType -in @("2","10") -and $user -and
                        $user -ne "-" -and $user -notmatch '\$$' -and
                        $user -ne "ANONYMOUS LOGON" -and $user.Length -gt 1) {
                        $logins += [PSCustomObject]@{
                            User = $user.ToLower()
                            Time = $e.TimeCreated
                        }
                    }
                } catch { }
            }
        } catch { }

        # Logoff-Events 4634
        $logoffs = @()
        try {
            $evts = Get-WinEvent -FilterHashtable @{
                LogName   = "Security"
                Id        = 4634
                StartTime = $since
            } -MaxEvents 5000 -ErrorAction Stop
            foreach ($e in $evts) {
                try {
                    $xml = [xml]$e.ToXml()
                    $ns  = @{e="http://schemas.microsoft.com/win/2004/08/events/event"}
                    $logonType = ($xml.SelectNodes("//e:Data[@Name='LogonType']",$ns) | Select-Object -First 1).'#text'
                    $user      = ($xml.SelectNodes("//e:Data[@Name='TargetUserName']",$ns) | Select-Object -First 1).'#text'
                    if ($logonType -in @("2","10") -and $user -and
                        $user -ne "-" -and $user -notmatch '\$$' -and
                        $user -ne "ANONYMOUS LOGON" -and $user.Length -gt 1) {
                        $logoffs += [PSCustomObject]@{
                            User = $user.ToLower()
                            Time = $e.TimeCreated
                        }
                    }
                } catch { }
            }
        } catch { }

        $out["Logins"]  = $logins
        $out["Logoffs"] = $logoffs
        return $out
    }

    $sessionOpt = New-PSSessionOption -OpenTimeout 30000 -OperationTimeout 120000
    $now = Get-Date

    foreach ($srv in $serverList) {
        $lblStatus.Text = "Frage Events ab: $srv ..."
        $frmAkt.Refresh()
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $r = if ($script:Cred) {
                Invoke-Command -ComputerName $srv -Credential $script:Cred `
                    -ScriptBlock $evtBlock -ArgumentList $daysBack `
                    -SessionOption $sessionOpt -ErrorAction Stop
            } else {
                Invoke-Command -ComputerName $srv `
                    -ScriptBlock $evtBlock -ArgumentList $daysBack `
                    -SessionOption $sessionOpt -ErrorAction Stop
            }

            if (-not $r["LogOK"]) {
                [void]$dtSrv.Rows.Add($srv, "-", "-", "-", "-", "Fehler: $($r['LogError'])")
                continue
            }

            $logins  = @($r["Logins"])
            $logoffs = @($r["Logoffs"])

            # Pro User aggregieren
            $userLogins = @{}
            foreach ($ev in $logins) {
                $u = $ev.User
                if (-not $userLogins.ContainsKey($u)) {
                    $userLogins[$u] = @{ Count=0; Last=$null }
                }
                $userLogins[$u].Count++
                if ($null -eq $userLogins[$u].Last -or $ev.Time -gt $userLogins[$u].Last) {
                    $userLogins[$u].Last = $ev.Time
                }
            }
            $userLogoffs = @{}
            foreach ($ev in $logoffs) {
                $u = $ev.User
                if (-not $userLogoffs.ContainsKey($u)) {
                    $userLogoffs[$u] = @{ Count=0; Last=$null }
                }
                $userLogoffs[$u].Count++
                if ($null -eq $userLogoffs[$u].Last -or $ev.Time -gt $userLogoffs[$u].Last) {
                    $userLogoffs[$u].Last = $ev.Time
                }
            }

            # Alle bekannten User aus Profil-Scan
            $knownUsers = @($allRows | Where-Object { $_["Server"] -eq $srv } |
                ForEach-Object { $_["Username"].ToLower() } | Select-Object -Unique)

            # Alle User die in Events aufgetaucht sind, auch wenn kein Profil
            $allEventUsers = @($userLogins.Keys) + @($userLogoffs.Keys) | Select-Object -Unique
            $allUsers = (@($knownUsers) + @($allEventUsers)) | Select-Object -Unique | Sort-Object

            $activeCount  = 0
            $inactiveCount = 0

            foreach ($u in $allUsers) {
                $loginCount   = if ($userLogins.ContainsKey($u))  { $userLogins[$u].Count }  else { 0 }
                $logoffCount  = if ($userLogoffs.ContainsKey($u)) { $userLogoffs[$u].Count } else { 0 }
                $lastLoginEvt = if ($userLogins.ContainsKey($u))  { $userLogins[$u].Last }   else { $null }
                $lastLogoff   = if ($userLogoffs.ContainsKey($u)) { $userLogoffs[$u].Last }  else { $null }

                $daysSince = "-"
                if ($lastLoginEvt) {
                    $daysSince = [math]::Round(($now - $lastLoginEvt).TotalDays, 0).ToString()
                }

                $bewertung = if ($loginCount -gt 0 -and $daysSince -ne "-" -and [int]$daysSince -le $inactiveDays) {
                    "Aktiv"
                } elseif ($loginCount -eq 0) {
                    "Inaktiv"
                } else {
                    "Inaktiv"
                }

                if ($bewertung -eq "Aktiv") { $activeCount++ } else { $inactiveCount++ }

                $lastLoginStr = if ($lastLoginEvt) { $lastLoginEvt.ToString("dd.MM.yyyy HH:mm") } else { "Kein Login" }
                $lastLogoffStr = if ($lastLogoff)  { $lastLogoff.ToString("dd.MM.yyyy HH:mm") }   else { "-" }

                [void]$dtUser.Rows.Add(
                    $srv, $u,
                    $loginCount.ToString(), $lastLoginStr,
                    $logoffCount.ToString(), $lastLogoffStr,
                    $daysSince, $bewertung)

                # Inaktive User Tab
                if ($bewertung -eq "Inaktiv") {
                    $profRow = $allRows | Where-Object { $_["Server"] -eq $srv -and $_["Username"].ToLower() -eq $u } | Select-Object -First 1
                    $profLogin = if ($profRow) { $profRow["Last Login"] } else { "-" }
                    $groesse   = if ($profRow) { $profRow["Groesse"] }    else { "-" }
                    $empf = if ($loginCount -eq 0) { "Kein Login in $daysBack Tagen - pruefen" }
                            else { "Zuletzt aktiv vor > $inactiveDays Tagen" }
                    [void]$dtInact.Rows.Add($srv, $u, $profLogin, $loginCount.ToString(), $daysSince, $groesse, $empf)
                }
            }

            $logSizeStr = "$($r['LogSizeMB']) MB / $($r['LogMaxMB']) MB"
            [void]$dtSrv.Rows.Add($srv, $logSizeStr, $logins.Count.ToString(),
                $activeCount.ToString(), $inactiveCount.ToString(), "OK")

        } catch {
            [void]$dtSrv.Rows.Add($srv, "-", "-", "-", "-", "Fehler: $($_.Exception.Message)")
        }

        $gridUser.DataSource  = $dtUser
        $gridSrv.DataSource   = $dtSrv
        $gridInact.DataSource = $dtInact

        # Spaltenbreiten - nur setzen wenn Spalten vorhanden und nicht null
        if ($gridUser.Columns.Count -gt 0) {
            $colMap = @{
                "Server"               = 12
                "Username"             = 14
                "Logins (4624)"        = 9
                "Letzter Login (Event)"= 14
                "Abmeldungen (4634)"   = 9
                "Letzte Abmeldung"     = 14
                "Tage seit Login"      = 10
                "Bewertung"            = 9
            }
            foreach ($colName in $colMap.Keys) {
                $col = $gridUser.Columns[$colName]
                if ($null -ne $col) { $col.FillWeight = $colMap[$colName] }
            }
        }

        $frmAkt.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    }

    $totalActive   = ($dtUser.Rows | Where-Object { $_["Bewertung"] -eq "Aktiv"   }).Count
    $totalInactive = ($dtUser.Rows | Where-Object { $_["Bewertung"] -eq "Inaktiv" }).Count
    $lblStatus.Text = "Fertig.  Aktiv: $totalActive  |  Inaktiv: $totalInactive  |  Zeitraum: letzte $daysBack Tage"
    $tabs.SelectedIndex = 0
})

# -- SCAN (parallel) --------------------------
$btnScan.Add_Click({
    try {
        if ($listServers.Items.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Bitte mindestens einen Server hinzufuegen.",
                "Keine Server", "OK", "Warning")
            return
        }
        if ($null -eq $script:Cred) {
            [System.Windows.Forms.MessageBox]::Show("Bitte zuerst Anmeldedaten setzen.",
                "Keine Anmeldedaten", "OK", "Warning")
            return
        }

        $btnScan.Enabled  = $false
        $btnAbort.Enabled = $true
        $script:Aborted   = $false
        $script:DataTable.Rows.Clear()
        $listSummary.Items.Clear()
        $script:ScanTimes      = @{}
        $script:ScanTimePhase1 = 0
        $script:ScanTimePhase2 = 0
        if ($script:txtLog -ne $null) { $script:txtLog.Clear() }
        $progressBar.Value   = 0
        $progressBar.Maximum = $listServers.Items.Count
        $calcSize = $chkProfileSize.Checked
        $statusBar.Text = "Phase 1: User-Scan laeuft..."
        $scanStartTime = Get-Date
        $form.Refresh()

        Write-Log "=== SCAN GESTARTET ==="
        Write-Log "Server: $($listServers.Items.Count)  |  Profilgroesse: $(if ($calcSize){'JA (async)'}else{'NEIN'})"
        Write-Log "Benutzer: $($script:Cred.UserName)"

        Write-Log "Pruefe TrustedHosts..."
        try {
            $serverList = @($listServers.Items)
            $ok = Ensure-TrustedHosts -Servers $serverList
            if (-not $ok) {
                Write-Log "TrustedHosts abgebrochen." "WARN"
                $statusBar.Text = "Scan abgebrochen."
                return
            }
            Write-Log "TrustedHosts OK" "OK"
        } catch { Write-Log "TrustedHosts Fehler: $($_.Exception.Message)" "ERROR" }

        Write-Log "Phase 1: Starte parallele Abfragen..."
        $jobs = @{}
        $jobStart = @{}
        $credForJob = $script:Cred

        foreach ($server in $listServers.Items) {
            [System.Windows.Forms.Application]::DoEvents()
            if ($script:Aborted) { break }
            Write-Log "  Job gestartet: $server"
            $jobStart[$server] = Get-Date

            $jobBlock = {
                param($Srv, $Cred)
                $sessionOpt = New-PSSessionOption -OpenTimeout 30000 -OperationTimeout 120000
                $remoteBlock = {
                    param($CalcSize)
                    $output = @()
                    $activeSessions = @{}
                    try {
                        $quserRaw = & quser 2>&1
                        if ($quserRaw -and $quserRaw.Count -gt 1) {
                            $header = $quserRaw[0].ToString()
                            $colSession = $header.IndexOf("SESSIONNAME")
                            if ($colSession -lt 0) { $colSession = $header.IndexOf("SITZUNGSNAME") }
                            $colID    = $header.IndexOf(" ID")
                            $colState = $header.IndexOf("STATE")
                            if ($colState -lt 0) { $colState = $header.IndexOf("STATUS") }
                            $colIdle  = $header.IndexOf("IDLE TIME")
                            if ($colIdle -lt 0) { $colIdle = $header.IndexOf("LEERLAUF") }
                            $colLogon = $header.IndexOf("LOGON TIME")
                            if ($colLogon -lt 0) { $colLogon = $header.IndexOf("ANMELDEZEIT") }
                            foreach ($line in ($quserRaw | Select-Object -Skip 1)) {
                                $l = $line.ToString()
                                if ($l.Trim() -eq "") { continue }
                                try {
                                    $uname = if ($colSession -gt 0) {
                                        $l.Substring(0, $colSession - 0)
                                    } else { $l }
                                    $uname = $uname.TrimStart(">").Trim().ToLower()
                                    if ($uname -eq "") { continue }
                                    $sessName = if ($colSession -gt 0 -and $colID -gt 0 -and $l.Length -gt $colSession) {
                                        $l.Substring($colSession, [Math]::Min($colID - $colSession, $l.Length - $colSession)).Trim()
                                    } else { "" }
                                    $stateStr = if ($colState -gt 0 -and $l.Length -gt $colState) {
                                        $end = if ($colIdle -gt 0) { $colIdle } else { $colState + 10 }
                                        $l.Substring($colState, [Math]::Min($end - $colState, $l.Length - $colState)).Trim()
                                    } else { "" }
                                    $idleStr = if ($colIdle -gt 0 -and $l.Length -gt $colIdle) {
                                        $end = if ($colLogon -gt 0) { $colLogon } else { $colIdle + 12 }
                                        $l.Substring($colIdle, [Math]::Min($end - $colIdle, $l.Length - $colIdle)).Trim()
                                    } else { "" }
                                    $stateNorm = switch -Wildcard ($stateStr.ToLower()) {
                                        "aktiv*"  { "Active" }
                                        "active*" { "Active" }
                                        "disc*"   { "Disconnected" }
                                        default   { if ($sessName -eq "") { "Disconnected" } else { "Active" } }
                                    }
                                    $activeSessions[$uname] = @{
                                        SessionName = if ($sessName -ne "") { $sessName } else { "disconnected" }
                                        State       = $stateNorm
                                        IdleTime    = if ($idleStr -eq "." -or $idleStr -eq "") { "-" } else { $idleStr }
                                    }
                                } catch { }
                            }
                        }
                    } catch { }

                    $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
                                Where-Object { -not $_.Special }
                    $accountMap = @{}
                    try {
                        Get-CimInstance -ClassName Win32_Account -ErrorAction SilentlyContinue |
                            ForEach-Object { $accountMap[$_.SID] = $_.Name }
                    } catch { }

                    foreach ($prof in $profiles) {
                        $username = ""
                        if ($accountMap.ContainsKey($prof.SID)) {
                            $username = $accountMap[$prof.SID]
                        } else {
                            try {
                                $sid = New-Object System.Security.Principal.SecurityIdentifier($prof.SID)
                                $resolved = $sid.Translate([System.Security.Principal.NTAccount]).Value
                                $username = if ($resolved -match "\\") { $resolved.Split("\")[1] } else { $resolved }
                            } catch { $username = $prof.SID }
                        }
                        $lastLogin = "Unbekannt"
                        if ($prof.LastUseTime) {
                            $lastLogin = $prof.LastUseTime.ToLocalTime().ToString("yyyy-MM-dd HH:mm")
                        }
                        $si = $activeSessions[$username.ToLower()]
                        $output += [PSCustomObject]@{
                            Username      = $username
                            SessionName   = if ($si) { $si.SessionName } else { "-" }
                            IdleTime      = if ($si) { $si.IdleTime }    else { "-" }
                            State         = if ($si) { $si.State }       else { "Offline" }
                            LastLogin     = $lastLogin
                            ProfilePath   = $prof.LocalPath
                            ProfileSizeMB = "N/A"
                            Status        = "OK"
                        }
                    }
                    return $output
                }
                try {
                    if ($Cred) {
                        $r = Invoke-Command -ComputerName $Srv -Credential $Cred `
                            -ScriptBlock $remoteBlock -ArgumentList $false `
                            -SessionOption $sessionOpt -ErrorAction Stop
                    } else {
                        $r = Invoke-Command -ComputerName $Srv `
                            -ScriptBlock $remoteBlock -ArgumentList $false `
                            -SessionOption $sessionOpt -ErrorAction Stop
                    }
                    return @{ Server = $Srv; Data = $r; Error = $null }
                } catch {
                    return @{ Server = $Srv; Data = @(); Error = $_.Exception.Message }
                }
            }
            $jobs[$server] = Start-Job -ScriptBlock $jobBlock -ArgumentList $server, $credForJob
        }

        Write-Log "Warte auf $($jobs.Count) parallele Jobs..." "OK"
        $done = @{}
        $totalJobs = $jobs.Count
        while ($done.Count -lt $totalJobs) {
            [System.Windows.Forms.Application]::DoEvents()
            if ($script:Aborted) {
                $jobs.Values | Stop-Job
                Write-Log "Abbruch - alle Jobs gestoppt." "WARN"
                break
            }
            foreach ($srv in @($jobs.Keys)) {
                if ($done.ContainsKey($srv)) { continue }
                $job = $jobs[$srv]
                if ($job.State -in "Completed","Failed","Stopped") {
                    $elapsed = [math]::Round(((Get-Date) - $jobStart[$srv]).TotalSeconds, 1)
                    $script:ScanTimes[$srv] = $elapsed
                    try {
                        $result = Receive-Job -Job $job -ErrorAction Stop
                        if ($result.Error) {
                            Write-Log "FEHLER $srv`: $($result.Error)" "ERROR"
                            [void]$script:DataTable.Rows.Add(
                                $srv, "ERROR", "-", "-", "-", "-", "-", "-",
                                "ERROR: $($result.Error)")
                        } else {
                            $rows = $result.Data
                            Write-Log "$srv`: $($rows.Count) Profile in ${elapsed}s" "OK"
                            foreach ($r in $rows) {
                                try {
                                    [void]$script:DataTable.Rows.Add(
                                        $srv, $r.Username, $r.State,
                                        (Format-LastLogin $r.LastLogin),
                                        $r.SessionName, $r.IdleTime, $r.ProfilePath,
                                        (Format-ProfileSize $r.ProfileSizeMB),
                                        $r.Status)
                                } catch { }
                            }
                        }
                    } catch {
                        Write-Log "Job-Fehler $srv`: $($_.Exception.Message)" "ERROR"
                    }
                    Remove-Job -Job $job -Force
                    $done[$srv] = $true
                    $progressBar.Value = $done.Count
                    Refresh-Grid
                    Refresh-Summary
                    $form.Refresh()
                }
            }
            if ($done.Count -lt $totalJobs) { Start-Sleep -Milliseconds 300 }
        }

        $totalUsers = ($script:DataTable.Rows | Where-Object { $_["Status"] -eq "OK" }).Count
        Write-Log "=== Phase 1 abgeschlossen. $totalUsers User ===" "OK"
        $script:ScanTimePhase1 = [math]::Round(((Get-Date) - $scanStartTime).TotalSeconds, 1)
        $progressBar.Value = $progressBar.Maximum
        $statusBar.Text = "Phase 1 fertig in $($script:ScanTimePhase1)s. $totalUsers User."
        Refresh-Summary

        Write-Log "calcSize=$calcSize  Aborted=$($script:Aborted)  -> Phase2 startet: $($calcSize -and -not $script:Aborted)"
        if ($calcSize -and -not $script:Aborted) {
            Write-Log "Phase 2: Lade Profilgroessen nach (parallel)..."
            $statusBar.Text = "Phase 2: Profilgroessen werden berechnet..."
            $progressBar.Value = 0
            $progressBar.Maximum = $listServers.Items.Count
            $phase2Start = Get-Date

            $sizeJobs = @{}
            foreach ($srv in @($listServers.Items)) {
                [System.Windows.Forms.Application]::DoEvents()
                if ($script:Aborted) { break }
                Write-Log "  Groessen-Job gestartet: $srv"
                $sizeJobs[$srv] = Start-ProfileSizeJob -Server $srv -Credential $credForJob
            }

            $sizeDone = @{}
            $sizeProgress = @{}

            while ($sizeDone.Count -lt $sizeJobs.Count) {
                [System.Windows.Forms.Application]::DoEvents()
                if ($script:Aborted) { $sizeJobs.Values | Stop-Job; break }

                foreach ($srv in @($sizeJobs.Keys)) {
                    if ($sizeDone.ContainsKey($srv)) { continue }
                    $job = $sizeJobs[$srv]
                    $newItems = @(Receive-Job -Job $job -Keep -ErrorAction SilentlyContinue)
                    $alreadyDone = if ($sizeProgress.ContainsKey($srv)) { $sizeProgress[$srv] } else { 0 }
                    $newItems = $newItems | Select-Object -Skip $alreadyDone

                    foreach ($item in $newItems) {
                        if (-not $item -or -not $item.PSObject.Properties["Path"]) { continue }
                        if ($item.Path -eq "DONE") { continue }   # Abschluss-Sentinel
                        if ($item.Index -lt 0)     { continue }   # interne Metadaten
                        if ($item.Path -eq "ERROR") {
                            $errDetail = if ($item.PSObject.Properties["ErrorMsg"]) { $item.ErrorMsg } else { "" }
                            Write-Log "  [$srv] Fehler bei Profilgroessen-Berechnung: $errDetail" "ERROR"
                            continue
                        }
                        $profName = Split-Path $item.Path -Leaf
                        $sizeStr  = if ($item.SizeMB -ge 0) { "$($item.SizeMB) MB" } else { "Fehler" }
                        Write-Log "  [$srv] $($item.Index) von $($item.Total): $profName  ->  $sizeStr  ($($item.Secs)s)"
                        foreach ($row in $script:DataTable.Rows) {
                            if ($row["Server"] -eq $srv -and $row["Profile Path"] -eq $item.Path) {
                                $row.BeginEdit()
                                $sizeVal = if ($item.SizeMB -ge 0) { $item.SizeMB } else { "Error" }
                                $row["Groesse"] = Format-ProfileSize $sizeVal
                                $row.EndEdit()
                            }
                        }
                        $sizeProgress[$srv] = $item.Index
                        [System.Windows.Forms.Application]::DoEvents()
                    }

                    if ($newItems.Count -gt 0) {
                        $view = $script:DataTable.DefaultView
                        $savedFilter = $view.RowFilter
                        $view.RowFilter = ""
                        $view.RowFilter = $savedFilter
                        $grid.DataSource = $view.ToTable()
                        $form.Refresh()
                    }

                    if ($job.State -in "Completed","Failed","Stopped") {
                        $finalItems = @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
                        foreach ($item in $finalItems) {
                            if (-not $item -or -not $item.PSObject.Properties["Path"]) { continue }
                            if ($item.Path -eq "DONE") { continue }
                            if ($item.Index -lt 0)     { continue }
                            if ($item.Path -eq "ERROR") {
                                $errDetail = if ($item.PSObject.Properties["ErrorMsg"]) { $item.ErrorMsg } else { "" }
                                Write-Log "  [$srv] Fehler (final): $errDetail" "ERROR"
                                continue
                            }
                            $alreadyDone2 = if ($sizeProgress.ContainsKey($srv)) { $sizeProgress[$srv] } else { 0 }
                            if ($item.Index -le $alreadyDone2) { continue }
                            $profName = Split-Path $item.Path -Leaf
                            $sizeStr  = if ($item.SizeMB -ge 0) { "$($item.SizeMB) MB" } else { "Fehler" }
                            Write-Log "  [$srv] $($item.Index) von $($item.Total): $profName  ->  $sizeStr  ($($item.Secs)s)"
                            foreach ($row in $script:DataTable.Rows) {
                                if ($row["Server"] -eq $srv -and $row["Profile Path"] -eq $item.Path) {
                                    $row.BeginEdit()
                                    $sizeVal = if ($item.SizeMB -ge 0) { $item.SizeMB } else { "Error" }
                                    $row["Groesse"] = Format-ProfileSize $sizeVal
                                    $row.EndEdit()
                                }
                            }
                            $sizeProgress[$srv] = $item.Index
                        }
                        $elapsed = [math]::Round(((Get-Date) - $phase2Start).TotalSeconds, 1)
                        Write-Log "  [$srv] Abgeschlossen. $elapsed s gesamt" "OK"
                        $view = $script:DataTable.DefaultView
                        $savedFilter = $view.RowFilter
                        $view.RowFilter = ""
                        $view.RowFilter = $savedFilter
                        $grid.DataSource = $view.ToTable()
                        Refresh-Summary
                        Remove-Job -Job $job -Force
                        $sizeDone[$srv] = $true
                        $progressBar.Value = $sizeDone.Count
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                }
                if ($sizeDone.Count -lt $sizeJobs.Count) { Start-Sleep -Milliseconds 500 }
            }
            $script:ScanTimePhase2 = [math]::Round(((Get-Date) - $phase2Start).TotalSeconds, 1)
            Write-Log "=== Phase 2 abgeschlossen in $($script:ScanTimePhase2)s ===" "OK"
        }

        Refresh-Grid
        Refresh-Summary
        $totalUsers = ($script:DataTable.Rows | Where-Object { $_["Status"] -eq "OK" }).Count
        $statusBar.Text = "Fertig. $totalUsers User auf $($listServers.Items.Count) Server(n)."
        Write-Log "=== SCAN KOMPLETT. $totalUsers User ===" "OK"

    } catch {
        $errMsg = $_.Exception.Message
        Write-Log "KRITISCHER FEHLER: $errMsg" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Fehler:`n`n$errMsg", "Fehler", "OK", "Error")
    } finally {
        $btnScan.Enabled  = $true
        $btnAbort.Enabled = $false
        $script:Aborted   = $false
        Get-Job | Where-Object { $_.State -in "Completed","Failed","Stopped" } | Remove-Job -Force
    }
})

# ---------------------------------------------
#  LAUNCH
# ---------------------------------------------
[void]$form.ShowDialog()
