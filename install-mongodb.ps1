<#
.SYNOPSIS
    Installs MongoDB on your machine. 
.DESCRIPTION
    Script to install msi, create folder structure and register MongoDB as a service in your machine. By default it creates following structure
    $mongoDBFolderLocation\data
    $mongoDBFolderLocation\data\log (log file is locate here)
    $mongoDBFolderLocation\data\db
.PARAMETER mongoDbFolderLocation
    The Path where Mongodb (data and binaries) will be installed. Can't contain spaces (msiexec problem)
.PARAMETER $mongoDbMsiLocation
    The absolute path and name to the downloaded MongoDB msi installation package
.EXAMPLE
    C:\PS> install-mongodb.ps1 -mongoDbFolderLocation C:\mongodb -mongoDbMsiLocation C:\mongodb-win32-x86_64-2008plus-ssl-3.4.3-signed.msi
.NOTES
    Author: Diego Saavedra San Juan
    Date:   Many
#>


param(    
    [string]$mongoDbFolderLocation="C:\mongodb",
    [Parameter(Mandatory=$true)]
    [string]$mongoDbMsiLocation)

$appToMatch="*mongodb*"
#$mongoDbMsiLocation=".\mongodb-win32-x86_64-2008plus-ssl-3.4.3-signed.msi"
#$mongoDbFolderLocation="C:\mongodb" #installation folder can't contain spaces even with quoting?
$mongoDbDataFolderLocation=$mongoDbFolderLocation + "\data"
$mongoDbLogFolderLocation=$mongoDbDataFolderLocation + "\log"
$mongoDbDbFolderLocation=$mongoDbDataFolderLocation + "\db"
$mongoDBServiceName="MongoDB"
$secondsToWaitForServiceToStartUp=10

$cfgLocation = "C:\mongodb\mongo.cfg"
$conf = "systemLog:
    destination: file
    path: c:\mongodb\data\log\mongod.log
storage:
    dbPath: c:\mongodb\data\db"

function Get-InstalledApps
{
    if ([IntPtr]::Size -eq 4) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | .{process{if($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |Sort DisplayName
}


function Test-Administrator  
{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}


if ( $mongoDbFolderLocation.Contains(" ") )
{
    Write-Error "MongoDB folder location parameter contains spaces. It can't contain spaces because the MSI installation would fail in that case. Please use a path withouth spaces"
}


# Dummy check if mogodb service already installed
Write-Host "Checking if Mongodb is already installed (service)" -ForegroundColor Cyan
$isMongoDbServiceInstalled = Get-Service | Where-Object {$_.Name -like "*mongo*"}
if ( -not ($isMongoDbServiceInstalled -eq $null)) 
{
    # Mongodb already installed in some way
    Write-Host "Mongodb is already available as a service, you probably have already installed it" -ForegroundColor Green
    exit 0
}


# Check admin privilege, won't be able to create the service otherwise
Write-Host "Checking administrator privilege before creating mongodb service" -ForegroundColor Cyan
if ( -not (Test-Administrator)  )
{ 
    Write-Host "Not running as administrator - won't be able to create the mongodb service or install it. Please run again as administrator" -ForegroundColor Red
    exit 1
}



# Check if program is installed instead, before installing it (service creation might have gone wrong, but it is installed nonetheless)
Write-Host "Checking if Mongodb is already installed (program)"
$result = Get-InstalledApps | where {$_.DisplayName -like $appToMatch}
if ($result -eq $null) {    
    # Install msi
    Write-Host "MongoDB not installed, proceeding with installation"
    if ( -Not ( Test-Path $mongoDbMsiLocation) )
    {
        Write-Error "MongoDB msi not available at $mongoDbMsiLocation, have you downloaded and placed it there?"
        exit 1
    }

    Write-Host "Installing MongoDB msi"

    # Msi exec needs absolute path to msi
    if ( ! ( Test-Path $mongoDbMsiLocation ) )
    {
        Write-Error "Msi installation file not found at $mongoDbMsiLocation, did you download it? You need to download yourself since MongoDB requires user input to download"
        exit 1
    }
    $msi = Get-Item $mongoDbMsiLocation
    $msiPath = $msi.FullName
    $mongoDbMsiInstallArgs = " /qn /i  $msiPath INSTALLLOCATION=$mongoDbFolderLocation ADDLOCAL=all" #installation folder can't contain spaces even with quoting?
    Write-Host "msiexec parameter: $mongoDbMsiInstallArgs"
    Start-Process "msiexec.exe"  -ArgumentList $mongoDbMsiInstallArgs -Wait -NoNewWindow -PassThru

    Start-Sleep -Seconds 10

    $result = Get-InstalledApps | where {$_.DisplayName -like $appToMatch}
    if ($result -eq $null) 
    {  
        Write-Host "Installation of MongoDB failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "Installed MongoDB msi correctly" -ForegroundColor Green
}
else 
{
    $reply = Read-Host "MongoDB already installed as an application, do you want to continue configuring it at $mongoDbFolderLocation (Y/N)"
    if ( $reply.ToUpper() -ne "Y")
    {
        Write-Host "Okay, skipping then"
        exit 0
    }
}


# Create mongodb folder
Write-Host "Creating mongodb folder at $mongoDbFolderLocation" -ForegroundColor Cyan
if ( -Not (Test-Path $mongoDbFolderLocation ))
{
    mkdir $mongoDbFolderLocation
    Write-Host "Created correctly" -ForegroundColor Green
}
else { Write-Host "Mongodb folder already exists, good" -ForegroundColor Green }


# Create mongodb data folder
Write-Host "Creating mongodb data folder at $mongoDbDataFolderLocation" -ForegroundColor Cyan
if ( -Not (Test-Path $mongoDbDataFolderLocation ))
{
    mkdir $mongoDbDataFolderLocation
    Write-Host "Created correctly" -ForegroundColor Green
}
else { Write-Host "Mongodb data folder already exists, good" -ForegroundColor Green }

# Create mongodb db folder
Write-Host "Creating mongodb data folder at $mongoDbDbFolderLocation" -ForegroundColor Cyan
if ( -Not (Test-Path $mongoDbDbFolderLocation ))
{
    mkdir $mongoDbDbFolderLocation
    Write-Host "Created correctly" -ForegroundColor Green
}
else { Write-Host "Mongodb db folder already exists, good" -ForegroundColor Green }


# Create mongodb log folder
Write-Host "Creating mongodb log folder at $mongoDbLogFolderLocation" -ForegroundColor Cyan
if ( -Not (Test-Path $mongoDbLogFolderLocation ))
{
    mkdir $mongoDbLogFolderLocation
    Write-Host "Created correctly" -ForegroundColor Green
}
else { Write-Host "Mongodb log folder already exists, good" -ForegroundColor Green }


    
# Create cfg file
Write-Host "Creating mongodb configuration file at" $cfgLocation -ForegroundColor Cyan
if ( -Not (Test-Path $cfgLocation ))
{
    New-Item -Path $cfgLocation
    $conf | Out-File $cfgLocation
    Write-Host "Created correctly" -ForegroundColor Green
}
else { Write-Host "Mongodb configuration file already exists, good" -ForegroundColor Green }

# Create log file
$logFileLocation = "C:\mongodb\data\log\mongod.log"
Write-Host "Creating mongodb log file at" $logFileLocation -ForegroundColor Cyan
if ( -Not (Test-Path $logFileLocation ))
{
    New-Item -Path $logFileLocation    
    Write-Host "Created correctly" -ForegroundColor Green
}
else { Write-Host "Mongodb log file already exists, good" -ForegroundColor Green }



# Set up as a service
Write-Host "Setting up MongoDb as a service" -ForegroundColor Cyan
$mongodExec=$mongoDbFolderLocation+"\bin\mongod.exe"
$setupServiceArgs= " --config " + $cfgLocation + " --install " 
$res = Start-Process $mongodExec -ArgumentList $setupServiceArgs -Wait -NoNewWindow -PassThru

# Check service exists
Write-Host "Checking if Mongodb service was created correctly" -ForegroundColor Cyan
$isMongoRunning = Get-Service | Where-Object {$_.Name -like "*mongo*"}
if ( $isMongoRunning -eq $null ) 
{ 
    Write-Error "Something went wrong setting up the service, it is not listed in the service list"
    exit 1
}

# Start service
Write-Host "Starting MongoDB service to check if it starts corretly" -ForegroundColor Cyan
Start-Service -Name "MongoDB"
Write-Host "Waiting $secondsToWaitForServiceToStartUp seconds for MongoDB service to start" -ForegroundColor Cyan
Start-Sleep -Seconds $secondsToWaitForServiceToStartUp
$MongoDbService = Get-Service -Name $mongoDBServiceName
if ( -Not ($MongoDbService.Status -eq "Running") ) 
{ 
    Write-Error "Something went wrong setting up the service, it did not start correctly. Check the log file for more information"
    exit 1
}

Write-Host "Correctly installed MongoDB as a service" -ForegroundColor Green
Write-Host "Correctly installed MongoDB" -ForegroundColor Green






