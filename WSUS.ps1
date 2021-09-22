#Set-ExecutionPolicy -ExecutionPolicy Unrestricted 
#Enable-PSRemoting -Force 

#I had to allow winrm to contain trustedhosts because not part of a domain 
#Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'machineA,machineB'

#You will need to copy the WindowsUpdateProvider from a Windows 2019 server to a 2016 
#Location: C:\System32\WIndowsPOwerShell\1.0\Modules\ 
#Import: Import-module -name WindowsUpdateProvider

$date = (get-date -f yyyy-MM-dd) 
$logsPath =  "C:\PowerShell-Scripts\logs\"

##########################################################################################################################################################################
############################################################## FUNCTIONS #################################################################################################
##########################################################################################################################################################################

#################################################################################################
# Using Module PSWindowsUpdate
function installWSUS{
param(
[Parameter(Mandatory=$True)]
[String]$serverName)
    
    #get-command -module PSWindowsUpdate
    #Enable-WURemoting — enable Windows firewall rules to allow remote use of the PSWindowsUpdate cmdlets;
    Write-Host "$logsPath$date_$serverName_WindowsUpdate.log" 
    Write-Host 'Windows Update: ' + $serverName
    
    invoke-command -ComputerName $serverName -scriptblock {Get-wulist -verbose | Out-File C:\PowerShell-Scripts\logs\PSWindowsUpdateLog.txt -Append} 

    Invoke-WUJob -ComputerName $serverName -Script {Install-WindowsUpdate -AcceptAll -Install -AutoReboot} -Confirm:$false -verbose -RunNow 
    
    ##OLD 
    ##download update 
    #Invoke-WUJob -ComputerName $serverName -Script {Download-WindowsUpdate -AcceptAll -ForceDownload } -Confirm:$false -verbose -RunNow | Out-File C:\PowerShell-Scripts\logs\PSWindowsUpdateLog.txt -Append
    ##install update 
    #Invoke-WUJob -ComputerName $serverName -Script {Install-WindowsUpdate -AcceptAll -AutoReboot -ForceInstall } -Confirm:$false -verbose -RunNow | Out-File C:\PowerShell-Scripts\logs\PSWindowsUpdateLog.txt -Append
    ##Not working #Invoke-WUInstall -ComputerName $serverName -Script {ipmo PSWindowsUpdate; Get-WUInstall -AcceptAll | Out-File  C:\PowerShell-Scripts\logs\PSWindowsUpdate.log  } -Confirm:$false -Verbose
    
    #check updates 
    #Invoke-WUJob -ComputerName $serverName -ArgumentList $logsPath,$date,$serverName -ScriptBlock{Get-WUHistory | Out-File C:\PowerShell-Scripts\logs\PSWindowsUpdateLog.txt -Append} 
    #Invoke-WUJob -ComputerName $serverName -ArgumentList $logsPath,$date,$serverName -ScriptBlock{Get-WUHistory | Out-File "$args[0]_$args[1]_$args[2]-WindowsUpdate.log" -Append} 
}

#################################################################################################
# Using MOdule WindowsUpdateProvider
function installWSUS2{
param(
[Parameter(Mandatory=$True)]
[String]$serverName)
    
    #Get-Command -Module WindowsUpdateProvider
    #Get-Content Function:\Start-WUScan
    Write-Host "$logsPath$date_$serverName_WindowsUpdate.log" 
    Write-Host 'Windows Update using : ' + $serverName
  
    #Start-WUScan -SearchCriteria "Type='Software' AND IsInstalled=0"
    Write-Host "Start-WUScan for server: " $serverName 
    $updates = Invoke-Command -ComputerName $serverName -ScriptBlock {Start-WUScan -SearchCriteria "Type='Software' AND IsInstalled=0"}

    if($updates -ne $Null) 
    {    
        #Install-WUUpdates -Updates $Updates -DownloadOnly
        Write-Host "Install-Updates for server: " $serverName 
        Invoke-Command -ComputerName $serverName -ArgumentList $updates -ScriptBlock {Install-WUUpdates -Updates $args[0]}
    }
}

#################################################################################################
# check if any updates are waiting to be installed 
function patchWaiting{
param(
[Parameter(Mandatory=$True)]
[String]$serverName)

    Write-Host "Check if patches required for server: " $serverName
    $patches = Invoke-Command -ComputerName $serverName -ScriptBlock {Get-wulist} 

    if (!$patches) 
    {
        $patches = $False
    }
    else
    {
        $patches = $True
    }
    return $patches 
}

#################################################################################################
# check if any updates are waiting to be installed 
function pendingReboot{
param(
[Parameter(Mandatory=$True)]
[String]$serverName)

    Write-Host "Check if reboot required for server: " $serverName
    $reboot = Invoke-Command -ComputerName $serverName -ScriptBlock {Get-WUIsPendingReboot} 

    return $reboot 

}

#################################################################################################
# restart a server 
function restartServer{
param(
[Parameter(Mandatory=$True)]
[String]$serverName)

        Write-Host "Restart-Computer for server: " $serverName
        Invoke-Command -ComputerName $serverName -ScriptBlock {Restart-Computer -Force}

}

#################################################################################################
# start service on server 
function startService{
param(
[Parameter(Mandatory=$True)]
[String]$serverName,
[Parameter(Mandatory=$True)]
[String]$serviceName) 

    Write-Host ('Starting Service ' + $serviceName + ' on ECM Server: ' + $serverName)
    Invoke-Command -ComputerName $serverName -ArgumentList $serviceName -ScriptBlock {Get-Service $args[0] | Start-Service }  

}

#################################################################################################
# Stop a service on server 
function stopService{
param(
[Parameter(Mandatory=$True)]
[String]$serverName,
[Parameter(Mandatory=$True)]
[String]$serviceName) 

    Write-Host ('Stopping Service ' + $serviceName + ' on ECM Server: ' + $serverName)
    #Out-File "C:\PowerShell-Scripts\logs\$date-$serverName-WindowsUpdate.log"
    #Invoke-Command -ComputerName $serverName -ScriptBlock {Get-Service schedule | Set-Service -Status Stopped} 
    Invoke-Command -ComputerName $serverName -ArgumentList $serviceName -ScriptBlock {Get-Service $args[0] | Stop-Service -Force }  

}

#########################################################################################################################################################################
############################################################## MAIN #####################################################################################################
#########################################################################################################################################################################

#set date for log file naming 

Write-Host "WSUS Patching" 

$servers = Get-Content -Path C:\PowerShell-Scripts\servers.json | ConvertFrom-Json 
$services = Get-Content -Path C:\PowerShell-Scripts\services.json | ConvertFrom-Json 

#Get server counts 
$ECMCount = 0 
$CVCount = 0 

#################################################################################################
# Turn off Objective Services 
foreach($server in $servers.servers)
{
    if ($server.type -eq "ECM") 
    {
        $ECMCount = $ECMCount + 1 
        
        foreach($service in $services.Services)
        {
        
            if ($service.type -eq "ECM") 
            {
                stopService $server.name $service.name
            }
        }
    }
}

#################################################################################################
### INSERT QUERY TO CV TO MAKE SURE IT IS IDLE BEFORE PROCEEDING ###
#################################################################################################

# Turn off CV Service
foreach($server in $servers.servers)
{
    if ($server.type -eq "CV") 
    {
        $CVCount = $CVCount + 1 

        foreach($service in $services.Services)
        {
            if ($service.type -eq "CV") 
            {
                stopService $server.name $service.name
            }
        }
    }
}

Write-Host "ECM Server count: " $ECMCount 
Write-Host "CV Server count: " $CVCount 

#################################################################################################
# Using the -Module PSWindowsUpdate 
# Download and install updates 
# Enable-WURemoting
foreach($server in $servers.servers)
{
    if ($server.type -eq "ECM") 
    {
        installWSUS $server.name 
    }
}

#################################################################################################
# Using the -Module WindowsUpdateProvider
# Download and install updates 
foreach($server in $servers.servers)
{
    if ($server.type -eq "ECM") 
    {
        #installWSUS2 $server.name 
    }
}

#Wait before checking they are online  
Write-Host "Start-Sleep -s 60"  
Start-Sleep -s 10

$counter = 0 

#################################################################################################
# Wait for all servers to come online 
while ($true) 
{
    $counter = 0 

    foreach($server in $servers.servers)
    {   
       Write-Host "Test-NetConnection -ComputerName " $server.name
       if ((Test-NetConnection -ComputerName $server.name -Port 445).TcpTestSucceeded -eq $true)
       {
            Write-Host "Test-NetConnection -eq True -ComputerName " $server.name     

            $patchingWaiting = patchWaiting $server.name
            Write-Host "patches Waiting: " $patchingWaiting

            $rebootWaiting = pendingReboot $server.name
            Write-Host "rebootWaiting Waiting: " $rebootWaiting

            if($rebootWaiting -eq $False -and $patchingWaiting -eq $False)
            {
                $counter = $counter + 1
            }
            elseif ($patchingWaiting -eq $True) 
            {
                installWSUS $server.name
            }
            elseif ($rebootWaiting -eq $True)
            {
                restartServer $server.name
            }
            else 
            {
                Write-Host "Failed to match critiera"
            }
       }
    }

    if (($ECMCount + $CVCount) -eq $counter) 
    {
        break 
    }
}

Write-Host "ECM Servers all online" 

#################################################################################################
# Start Objective services 
foreach($server in $servers.servers)
{
    if ($server.type -eq "ECM") 
    {
        foreach($service in $services.Services)
        {
            if ($service.type -eq "ECM") 
            {
                startService $server.name $service.name
            }
        }
    }
}


#################################################################################################
# INSERT OBJECTIVE CHECKS 


#################################################################################################
# Start CV service







