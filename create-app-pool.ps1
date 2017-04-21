<#
.SYNOPSIS
    Creates an app pool
.DESCRIPTION
    Script to create an IIS app pool.
.PARAMETER appPoolName
    The name for the app pool
.PARAMETER dotNetVersion
    The .NET version the app pool will use. Ie v4.0
.EXAMPLE
    C:\PS> create-app-pool.ps1 -appPoolName appPool -dotNetVersion "v4.0"
.NOTES
    Author: Diego Saavedra San Juan
    Date:   Many
#>


param(
    [Parameter(Mandatory=$true)]
    [string]$appPoolName, 
    [string]$dotNetVersion="v4.0",
    [string]$appPoolIdentityUser,
    [string]$appPoolIdentityPass)

Import-Module WebAdministration

#navigate to the app pools root
#$currentPath = pwd
#cd IIS:\AppPools\

#check if the app pool exists
Write-Host "Checking if application pool $appPoolName already exists" -ForegroundColor Cyan
if (!(Test-Path "IIS:\\AppPools\$appPoolName" -pathType container))
{
    #create the app pool
    Write-Host "Creating app pool $appPoolName" -ForegroundColor Cyan
    $appPool = New-Item IIS:\AppPools\${appPoolName}
    $appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value $dotNetVersion
    if ( -Not ( $appPoolIdentityUser -eq $null -or $appPoolIdentityUser -eq "" ))
    {
        if ( $appPoolIdentityPass -eq $null -or $appPoolIdentityPass -eq "" )
        {
            Write-Host "App pool identity pass is null or empty, refusing to set it" -ForegroundColor Red
            exit 1
        }

        Write-Host "Setting app pool identity to $appPoolIdentityUser" -ForegroundColor Cyan
        Set-ItemProperty IIS:\AppPools\${appPoolName} -name processModel -value @{userName=${appPoolIdentityUser};password=${appPoolIdentityPass};identitytype=3}
    }
    Write-Host "Created app pool $appPoolName correctly" -ForegroundColor Green
}
else
{
    Write-Host "App pool $appPoolName already exists, good" -ForegroundColor Green
}



