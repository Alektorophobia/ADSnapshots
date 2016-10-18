
## Takes a Snapshot of Active Directory and then makes a copy of the NTDS folder.
## It will only keep 3 snapshots before deleting the oldest one.

$Date = (Get-Date).ToString('yyyy-MM-dd')

If (-NOT (Test-Path -Path D:\Snapshots\Logs)) { New-Item -Path D:\Snapshots\Logs -Type Directory | Out-Null }

Start-Transcript -Path "D:\Snapshots\Logs\$($Date).log"

$PreviousSnapshots = Get-ChildItem "D:\Snapshots" -Exclude "Logs" | Sort-Object -Property CreationTime

Write-Warning "Previous Snapshots"
$PreviousSnapshots | Select-Object -ExpandProperty Name | Out-Host

If ($PreviousSnapshots.Count -gt 2) {
    $DeleteSnapshotPath = $PreviousSnapshots | Select-Object -First 1 -ExpandProperty FullName
    Write-Warning "Removing Oldest Snapshot - $DeleteSnapshotPath"
    
    Remove-Item -Path "$DeleteSnapshotPath" -Recurse -Force
}

Function New-ADSnapshot {
    <#
    .SYNOPSIS
       Creates a new Active Directory database snapshot.
    .DESCRIPTION
       Uses NTDSUTIL to create a new Active Directory database snapshot.
       NTDSUTIL "Activate Instance NTDS" SNAPSHOT CREATE
       
       It will also make a copy of the NTDS directory into "D:\Snapshots\<Date>\NTDS" Directory
    .EXAMPLE
       New-ADSnapshot
    .NOTES
       This cmdlet targets the local machine.  It must execute locally on a domain controller either through a local or remote PowerShell session.
    #>
    Param()
    
    $Date = (Get-Date).ToString('yyyy-MM-dd')
    
    Write-Warning "Checking For Previous Snapshots and removing them"
    $SnapShots = ntdsutil snapshot "list all" quit quit
    
    $SnapShots | Out-Host
    
    If ($SnapShots[2] -ne "No snapshots found.") {
        Write-Warning "Removing Previous Snapshots!"
        ntdsutil snapshot "list all" "delete *" quit quit | Out-Host
    }

    Write-Warning "Creating a new Snapshot."
    ntdsutil "Activate Instance NTDS" snapshot create quit quit | Out-Host
    
    Write-Warning "Check for Previously Mounted snapshots"
    $Mounted = ntdsutil snapshot "list mounted" quit quit
    
    If ($Mounted -as [Bool]) { 
        Write-Warning "Dismounting Previous Snapshot"
        ntdsutil snapshot "list mounted" "unmount *" quit quit | Out-Host
    }
    
    Write-Warning "Mounting Snapshot"
    $Mount = ntdsutil snapshot "list all" "mount 1" quit quit
    
    $Mount | Out-Host
    
    $MountPath = (($Mount | Select-String -SimpleMatch '_VOLUMED$') -split 'mounted as')[-1].Trim()
    
    Robocopy "$MountPath\NTDS" "D:\Snapshots\$($Date)\NTDS" /E /R:2 /NP | Out-Host
    
    Write-Warning "Dismount Snapshots"
    ntdsutil snapshot "list mounted" "unmount *" quit quit | Out-Host
    
    Write-Warning "Delete Snapshots"
    ntdsutil snapshot "list all" "delete *" quit quit | Out-Host
}

New-ADSnapshot

Stop-Transcript
