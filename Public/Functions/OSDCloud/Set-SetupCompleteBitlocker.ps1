function Set-SetupCompleteBitlocker {

    #Create Script to Backup Bitlocker Key to AAD
$BitlockerFile = @'
$BitlockerVol = Get-BitLockerVolume -MountPoint $env:SystemDrive
$KPID=""
foreach($KP in $BitlockerVol.KeyProtector){
    if($KP.KeyProtectorType -eq "RecoveryPassword"){
        $KPID=$KP.KeyProtectorId
        Write-Output $KPID
        $output = BackupToAAD-BitLockerKeyProtector -MountPoint "$($env:SystemDrive)" -KeyProtectorId $KPID
    }
}
Start-Sleep -Seconds 10
Unregister-ScheduledTask -TaskName "Register Bitlocker in AAD" -Confirm:$False
'@


    $BitlockerFile | Out-File "C:\OSDCloud\configs\BackupToAAD.ps1" -Force
    
$ScriptsPath = "C:\Windows\Setup\scripts"
    if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath} 

    $RunScript = @(@{ Script = "SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1';Type = 'Setup'; Path = "$ScriptsPath"})
    $PSFilePath = "$($RunScript.Path)\$($RunScript.ps1File)"

    if (Test-Path -Path $PSFilePath){
        Add-Content -Path $PSFilePath "Write-OutPut 'Enabling Bitlocker'"
        Add-Content -Path $PSFilePath "Enable-TpmAutoProvisioning"
        Add-Content -Path $PSFilePath "Initialize-Tpm"
        Add-Content -Path $PSFilePath 'Enable-BitLocker -MountPoint c:\ -EncryptionMethod XtsAes256 -RecoveryPasswordProtector -UsedSpaceOnly:$false'
        #Create Scheduled Task
        Add-Content -Path $PSFilePath '$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument  "-NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File C:\OSDCloud\configs\BackupToAAD.ps1"'
        Add-Content -Path $PSFilePath '$trigger = New-ScheduledTaskTrigger -AtLogon'
        Add-Content -Path $PSFilePath '$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount'
        Add-Content -Path $PSFilePath '$settings = New-ScheduledTaskSettingsSet'
        Add-Content -Path $PSFilePath '$task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings'
        Add-Content -Path $PSFilePath 'Register-ScheduledTask "Register Bitlocker in AAD" -InputObject $task'
    }
    else {
    Write-Output "$PSFilePath - Not Found"
    }
}