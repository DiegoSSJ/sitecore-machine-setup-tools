
<#
.SYNOPSIS
    Uninstalls Zookeeper on your machine. 
.DESCRIPTION
    Script to remove zookeeper folder and service from your machine.
.PARAMETER zookeeperExtractLocation
    The Path where zookeeper was installed. It will be deleted
.PARAMETER serviceName
    The name the service running zookeeper has, it will be removed
.EXAMPLE
    C:\PS> uninstall-zookeeper.ps1 -zookeeperExtractLocation C:\zookeeper  -serviceName "zookeeper" 
.NOTES
    Author: Diego Saavedra San Juan
    Date:   Many
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$zookeeperExtractLocation, #The path where zookeeper will be installed
    [Parameter(Mandatory=$true)]
    [string]$zookeeperServiceName="zookeeper")

$nssmName="nssm.exe"
$nssmLocalPath=".\$nssmName"

if ($zookeeperExtractLocation -eq $null -or $zookeeperExtractLocation -eq "")
{
    Write-Host "Parameter zookeeperExtractLocation is mandatory, but it is null or empty" -ForegroundColor Red
    exit 1
}

if ($zookeeperServiceName -eq $null -or $zookeeperServiceName -eq "")
{
    Write-Host "Parameter serviceName is mandatory, but it is null or empty" -ForegroundColor Red
    exit 1
}


# Uninstall Service
Write-Host "Checking if zookeeper service is installed"
$isZookeeperServiceInstalled = Get-Service | Where-Object {$_.Name -like "*$zookeeperServiceName*"}
if ( -not ($isZookeeperServiceInstalled -eq $null)) 
{
    Write-Host "Removing zookeeper service $zookeeperServiceName" -ForegroundColor Cyan

    # Stop the service 
    sc.exe stop $zookeeperServiceName

    # Nssm doesn't really delete, it just disables autostart
    #$res = Start-Process $nssmLocalPath -ArgumentList " remove $zookeeperServiceName confirm " -Wait -NoNewWindow -PassThru
    sc.exe delete $zookeeperServiceName 
    Start-Sleep 2
    #$isZookeeperServiceInstalled = Get-Service | Where-Object {$_.Name -like "*$zookeeperServiceName*"}
    $isZookeeperServiceInstalled = sc.exe query $zookeeperServiceName
    #if ( $isZookeeperServiceInstalled.Status -eq "Stopped" )
    if ( $isZookeeperServiceInstalled[0].Contains("1060"))
    {
        Write-Host "Removal of zookeeper service completed sucessfully" -ForegroundColor Green
    }
    else 
    { 
        Write-Host "Something went wrong removing zookeeper service named $zookeeperServiceName" -ForegroundColor Red
        exit 1
    }

}
else 
{ 
    Write-Host "zookeeper service already removed, good" -ForegroundColor Green
}


# Remove folder
if ( Test-Path $zookeeperExtractLocation )
{
    rmdir -recurse $zookeeperExtractLocation
    if ( -Not ( Test-Path $zookeeperExtractLocation ))
    {
        Write-Host "Correctly removed zookeeper directory at $zookeeperExtractLocation" -ForegroundColor Green
    }
    else 
    { 
        Write-Host "Something went wrong trying to remove the zookeeper directory" -ForegroundColor Red
        exit 1
    }
}
else { Write-Host "zookeeper location $zookeeperExtractLocation already removed, good" -ForegroundColor Green }

Write-Host "Completed uninstallation of zookeeper" -ForegroundColor Green




