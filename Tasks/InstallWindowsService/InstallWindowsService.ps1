[CmdletBinding()]
param()
Import-Module .\ps_modules\VstsTaskSdk

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    Import-VstsLocStrings "$PSScriptRoot\Task.json"

    # Get the inputs.

    $Server = Get-VstsInput -Name Server
    $ServiceName = Get-VstsInput -Name ServiceName
    $BinPath = Get-VstsInput -Name BinPath
    [bool]$ChangeUser =  Get-VstsInput -Name ChangeUser -AsBool
    $Username = Get-VstsInput -Name Username
    $Password = Get-VstsInput -Name Password
    $AdminUser =  Get-VstsInput -Name AdminUsername
    $AdminPassword =  Get-VstsInput -Name AdminPassword
    $StartUpType = Get-VstsInput -Name StartUpType
    [bool]$Start = Get-VstsInput -Name Start -AsBool
    $Description = Get-VstsInput -Name Description
    $DependsOn = Get-VstsInput -Name DependsOn
    [bool]$EnableFailure = Get-VstsInput -Name EnableFailure -AsBool
    $ResetFailure = Get-VstsInput -Name ResetFailure
    $Actions = Get-VstsInput -Name Actions
   
    $securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force    
    $credential = New-Object System.Management.Automation.PSCredential($AdminUser,$securePassword)
    
    $results = Invoke-Command -ComputerName $Server -ScriptBlock {
        
                param
                    (
                        [string]$rServiceName,
                        [string]$rBinPath,
                        [string]$rUsername,
                        [string]$rPassword,
                        [string]$rStartUpType,
                        [bool]$rStart = $false,
                        [string]$rDescription,
                        [string]$rDependsOn,
                        [bool]$rEnableFailure = $false,
                        [int]$rResetFailure,
                        [string]$rActions,
                        [bool]$rChangeUser = $false
                    )                     
    try{
               #remove it if it's already there
                $service = Get-WmiObject -Class Win32_Service -Filter "Name='$rServiceName'"
                
                if($service -ne $null) 
                {
                    $service.StopService()
                    $s = Get-Service "$rServiceName"
                    $s.WaitForStatus("Stopped")
                    sc.exe delete $service.Name
                }
    
                New-Service -Name $rServiceName -BinaryPathName "$rBinPath" -DisplayName "$rServiceName" -StartupType "$rStartUpType"
    
                if($rChangeUser -eq $true) {sc.exe config $rServiceName obj= "$rUsername" password= "$rPassword"}
    
                if(![string]::IsNullOrEmpty($rDependsOn)) {sc.exe config $rServiceName depend= $rDependsOn}
    
                if($rEnableFailure -eq $true) {sc.exe failure $rServiceName reset= $rResetFailure actions= "$rActions"}
    
                if(![string]::IsNullOrEmpty($rDescription)) {sc.exe description $rServiceName "$rDescription"}
                    
                if($rStart -eq $true) {Set-Service $rServiceName -Status Running}
            }
            catch
            {
                return $_
            }
                
            } -ArgumentList @($ServiceName,$BinPath,$Username,$Password,$StartUpType,$Start,
            $Description,$DependsOn,$EnableFailure,$ResetFailure,$Actions,$ChangeUser) -Credential $credential
     
       Write-Host $results
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}