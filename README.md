# TerminalServerUserChecker

A PowerShell GUI tool for auditing user profiles across multiple Windows Terminal Servers (RDS). Identifies large profiles, inactive accounts, duplicate profiles across servers, and analyzes user activity via Windows Security Event Logs — all from a single dark-themed interface.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2016%2F2019%2F2022-0078D4?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Features

**Profile Scan**
- Queries all user profiles remotely via WinRM / `Invoke-Command`
- Resolves profile SIDs to usernames using CIM (`Win32_UserProfile`, `Win32_Account`)
- Detects active, disconnected, and offline sessions via `quser`
- Optional profile size calculation (Phase 2, async, parallel per server)
- Parallel multi-server scanning with live progress updates

**Multi-Server User Detection**
- Identifies users with profiles on more than one server
- Marks the primary server (newest Last Login or active session)
- Color-coded inactivity (green / yellow / red per row)
- Cleanup recommendation per profile copy
- Export: full list or "cleanup candidates only" as CSV

**Old Profiles**
- Filters profiles not used for N days (configurable threshold)
- Sorted oldest-first with inactivity duration in days
- CSV export

**Large Profiles**
- Filters profiles exceeding a configurable size threshold (MB)
- Sorted largest-first
- Requires Phase 2 (profile size scan) to be enabled
- CSV export

**Activity Analysis**
- Reads Windows Security Event Log remotely (Event IDs 4624 / 4634)
- Filters only interactive and RDP logons (LogonType 2 and 10)
- Configurable lookback period and inactivity threshold
- Three result tabs: Per User, Per Server summary, Inactive Users only
- Cross-references Event Log data with profile scan results (size, last profile use)
- CSV export

**Credential & Server Management**
- Encrypted credential storage (DPAPI, current Windows user only)
- Server list save / load (plain text)
- Automatic WinRM TrustedHosts configuration
- Self-elevating (UAC prompt on launch if not running as Administrator)

**UI**
- Dark theme throughout (WinForms, no external dependencies)
- Verbose log panel with color-coded levels (INFO / OK / WARN / ERROR)
- Log file written to `%TEMP%` on every run, openable in Notepad
- Per-server scan summary with timing
- Username filter / state filter checkboxes

---

## Requirements

| Requirement | Details |
|---|---|
| PowerShell | 5.1 or higher |
| OS (management host) | Windows 10 / 11 or Windows Server 2016+ |
| OS (target servers) | Windows Server 2016 / 2019 / 2022 |
| WinRM | Enabled and reachable on all target servers |
| Permissions | Local Administrator on target servers |
| .NET Framework | 4.5+ (included with Windows Server 2016+) |

No third-party modules required. No installation needed.

---

## Quick Start

```powershell
# Run directly (will self-elevate to Administrator)
.\TerminalServerUserChecker.ps1

# If execution policy blocks the script:
powershell.exe -ExecutionPolicy Bypass -File .\TerminalServerUserChecker.ps1
```

### First Steps

1. Add one or more Terminal Server hostnames or IPs in the left panel
2. Click **Anmeldedaten eingeben** to enter remote credentials
3. Optionally enable **Profilgroesse** checkbox for profile size calculation
4. Click **Server scannen** — results appear live as each server completes
5. Use the analysis buttons to drill down:
   - **Multi-Server** — users with profiles on more than one server
   - **Alte Profile** — profiles inactive beyond a configurable number of days
   - **Grosse Profile** — profiles exceeding a configurable size in MB
   - **Aktivitaet** — activity analysis based on Security Event Log

---

## WinRM Setup (Target Servers)

Run on each target server if WinRM is not already enabled:

```powershell
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

The tool will prompt to add servers to the local TrustedHosts list automatically on first scan.

---

## Notes

- **Credential files** (`.cred`) are encrypted with Windows DPAPI and can only be decrypted by the same Windows user account on the same machine.
- **Profile size calculation** scans file system recursively and skips junction points / reparse points to avoid loops. Large profiles (tens of GB) may take several minutes.
- **Activity Analysis** requires the Security Audit Policy on target servers to log Logon/Logoff events (enabled by default on most Windows Server installations). Check via `auditpol /get /subcategory:"Logon"`.
- The tool reads up to 5,000 login and 5,000 logoff events per server per query. Extend `MaxEvents` in the script if your environment requires a longer lookback with high login frequency.

---

## File Structure

```
TerminalServerUserChecker.ps1   # Single-file application, no dependencies
README.md
LICENSE
```

---

## License

MIT License — free to use, modify, and distribute.
