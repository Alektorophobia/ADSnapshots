# How to mount a snapshot

# Connect to the Domain Controller that has the snapshot you want to view.
# Paste the Mount-ADSnapshot function into an administrative powershell window.
# Run the function giving it an LDAP port as well as the date you want to mount.  'Mount-ADSnapshot -LDAPPort 31337 -Date 2.2'
# A new window of dsamain.exe will open up and the powershell window will provide a note saying you can connect to the mounted snapshot using '-Server localhost:port' and a note to stop the dsamain.exe process when you are finished.
# Stop the Process by closing the window or run (Stop-Process dsamain)

Function Mount-ADSnapshot {
<#
    .SYNOPSIS
       Mounts an Active Directory snapshot and the database it contains.
    .DESCRIPTION
       Uses DSAMAIN.EXE to mount the database contained in the snapshot.
       Parameters define which snapshot and port to use.
    .PARAMETER LDAPPort
       Port for DSAMAIN to advertise the database.
       Must be in the range 1025 to 65535.
       Checks to make sure another database is not already using the port.
       The other ports use (SSL) LDAP+1, (GC) LDAP+2, and (GC-SSL) LDAP+3.
    .PARAMETER Date
       The Date of snapshot
    .NOTES
       This cmdlet will launch the DSAMAIN process in a separate window.  This window must remain open throughout the snapshot usage.
#>
    [cmdletbinding(ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$True)][ValidateScript({$x = $null;Try {$x = Get-ADRootDSE -Server localhost:$_} Catch {$null};If ($x) {$false} Else {$true}})][ValidateRange(1025,65535)][int]$LDAPPort,
        [Parameter(Mandatory=$True,Position=0)][Datetime]$Date
    )
    Begin {
        $CurrentYear = (Get-Date).Year
        $CurrentMonth = (Get-Date).Month
        $SearchYear = $Date.Year
        $SearchMonth = $Date.Month
        $SearchDay = $Date.Day
       
        If ($SearchMonth -eq 12 -And $CurrentMonth -lt 3) {
            $SearchYear = $SearchYear - 1
        }
       
        If ($SearchMonth -lt 10) { $SearchMonth = "0$($SearchMonth)" }
        If ($SearchDay -lt 10) { $SearchDay = "0$($SearchDay)" }
       
        $SnapshotDate = "$($SearchYear)-$($SearchMonth)-$($SearchDay)"
       
        If (-NOT (Test-Path -Path "D:\Snapshots\$($SnapshotDate)\NTDS\ntds.dit")) {
            Write-Warning "Unable to Locate the Snapshot for $SnapshotDate"
            Break
        }
    }
    Process {
        $NTDSdit = "D:\Snapshots\$($SnapshotDate)\NTDS\ntds.dit"
       
        Write-Host 'Mounting database: .' -NoNewline
        $DSAMAIN = Start-Process -FilePath dsamain.exe -ArgumentList "-dbpath $NTDSdit -ldapport $LDAPPort" -PassThru
       
        # Wait for database mount to complete
        # Get-ADRootDSE does not seem to obey the ErrorAction parameter
        $ErrorActionPreference = 'SilentlyContinue'
        $do = $null
        Do {
            $do = Get-ADRootDSE -Server localhost:$LDAPPort
            Start-Sleep -Seconds 1
            Write-Host '.' -NoNewline
        }
        Until ($do)
        Write-Host '.'
        $ErrorActionPreference = 'Continue'
       
        Write-Warning "Use '-Server localhost:$($LDAPPort)' on any powershell cmdlet to search the Snapshot."
       
        Write-Warning "Be sure to stop the dsamain.exe process when finished.  (Stop-Process dsamain)"
    }
}
