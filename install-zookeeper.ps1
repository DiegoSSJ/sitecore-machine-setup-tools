
<#
.SYNOPSIS
    Installs Zookeeper on your machine. 
.DESCRIPTION
    Script to download, unpack and register Zookeeper as a service in your machine. Checks if Java and/or Zookeeper are already installed. 
.PARAMETER zookeeperExtractLocation
    The Path where Zookeeper will be installed 
.PARAMETER zookeperVersion
     Zookeper version to download from Apache zookeeper archives. Format is ie "3.4.9", "3.5.2-alpha". Must match what is in the archive
.PARAMETER serviceName
    The name the service running zookeeper will have
.PARAMETER zookeperHosts
    Comma-separated list of hosts that will conform the zookeeper ensemble. No spaces please. Ie: "host1,host2". Will be written to the zookeeper configuration file in that order.
    Ex: host1,host2 -> 
    server.1=host1:2888:3888
    server.2=host2:2888:3888
.PARAMETER zookeeperHostNr
    The number this host has in the zookeeper ensemble. Ie 1, 2. Will be written to the myid file in the data folder.
.EXAMPLE
    C:\PS> install-zookeeper.ps1 -zookeeperExtractLocation C:\zookeeper -zookeeperVersion "3.4.9" -serviceName "zookeeper" -zookeeperHosts "one.contoso.com,two.contoso.com" 
.NOTES
    Author: Diego Saavedra San Juan
    Date:   Many
#>

# Must be run as system admin (to create the service)

param(
    [Parameter(Mandatory=$true)]
    [string]$zookeeperExtractLocation, #The path where zookeeper will be installed
    [Parameter(Mandatory=$true)]
    [string]$zookeeperHosts,
    [Parameter(Mandatory=$true)]
    [string]$zookeeperHostNr,
    [string]$zookeeperVersion="3.4.9",  # Zookeper version to download from Apache zookeeper archives. Format is ie "3.4.9", "3.5.2-alpha". Must match what is in the archive
    [string]$serviceName="zookeeper",
    [bool]$createService=$true)

if ($zookeeperExtractLocation -eq $null -or $zookeeperExtractLocation -eq "")
{
    Write-Host "Parameter zookeeperExtractLocation is mandatory, but it is null or empty" -ForegroundColor Red
    exit 1
}

$zookeeperVersionName=$zookeeperVersion
$zookeeperUrl="http://apache.mirrors.spacedump.net/zookeeper/zookeeper-$zookeeperVersionName/zookeeper-$zookeeperVersionName.tar.gz"
$zookeeperBinaryFolder="$zookeeperExtractLocation\bin\"
$zookeeperBinaryLocation=$zookeeperBinaryFolder + "zkServer.cmd"
$zookeeperConfigurationFileLocation=$zookeeperExtractLocation + "\conf\zoo.cfg"
$zookeeperExampleConfigurationFileLocation=$zookeeperExtractLocation + "\conf\zoo_sample.cfg"
$zookeeperMyidFileLocation=$zookeeperExtractLocation + "\data\myid"
$zookeeperServiceName=$serviceName
$zookeeperServiceDisplayName="Zookeeper service instance"
$zookeeperServiceDescription="This is the zookeeper service"
$serviceStartupWaitTime=10
$serviceStopWaitTime=20
$sevenZipBinaryLocation='C:\Program Files\7-Zip\7z.exe'
$sevenZipArguments=' x ' 

$nssmName="nssm.exe"
$nssmLocalPath="$nssmName"
$nssmZookeeperPath="$zookeeperBinaryFolder\$nssmName"


$tempdir = Get-Location
$tempdir = $tempdir.tostring()
$appToMatch = '*Java*'
#$msiFile = $tempdir+"\microsoft.interopformsredist.msi"
#$msiArgs = "-qb"

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


# Dummy check if zookeeper is already running 
Write-Host "Checking if zookeeper is already installed" -ForegroundColor Cyan
$iszookeeperServiceInstalled = Get-Service | Where-Object {$_.Name -like "*zookeeper*"}
if ( -not ($iszookeeperServiceInstalled -eq $null)) 
{
    # zookeeper already installed in some way
    Write-Host "zookeeper is already available as a service, you probably have alread installed it" -ForegroundColor Green
    exit 0
}


# Check java
Write-Host "Checking Java is installed" -ForegroundColor Cyan
$result = Get-InstalledApps | where {$_.DisplayName -like $appToMatch}

if ($result -eq $null) {
    #(Start-Process -FilePath $msiFile -ArgumentList $msiArgs -Wait -Passthru).ExitCode
    Write-Host "Java not installed please install from http://www.java.com/sv/download/win10.jsp" -ForegroundColor Red
    exit 1
}

# Try to actually run java (it has to be in the path for the zookeeper service to be able to start)
try
{
    java 2> $null
}
catch
{
    Write-Host "Java is installed but it is not in the path, you have to add it ot the path so that zookeeper service will be able to start" -ForegroundColor Red
    exit 1
}

# Check nssm
if(!(Test-Path $nssmLocalPath))
{
    Write-Host "Nssm is not available, won't be able to create the zookeeper service. It should be at $nssmLocalPath" -ForegroundColor Red
    exit 1
}

# Check admin privilege, won't be able to create the service otherwise
Write-Host "Checking administrator privilege before creating zookeeper service" -ForegroundColor Cyan
if ( -not (Test-Administrator)  )
{ 
    Write-Host "Not running as administrator - won't be able to create the zookeeper service. Please run again as administrator" -ForegroundColor Red
    exit 1
}


Write-Host "Downloading zookeeper $zookeeperVersionName" -ForegroundColor Cyan
$filename = "$env:temp\zookeeper-$zookeeperVersionName.tar.gz" 
if(!(Test-Path $filename))
{
    wget $zookeeperUrl -OutFile $filename
}
else 
{
    Write-Host "zookeeper has already been downloaded" -ForegroundColor Cyan
}

# Kind of hard to get an exit code from wget/Invoke-WebRequest so we just check if the file is there and over 0 size
if(!(Test-Path $filename))
{
    Write-Host "Couldn't download the zookeeper zip file correctly, check error messages and fix accordingly." -ForegroundColor Red
    exit 1
}


Write-Host "Unpacking zookeeper to $zookeeperExtractLocation" -ForegroundColor Cyan
if(!(Test-Path $zookeeperBinaryLocation))
{
    # Check 7-zip, needed to unpack .tar.gz coming from Zookeeper archive
    if ( -Not( Test-Path $sevenZipBinaryLocation ))
    {
        Write-Host "7-zip doesn't seem to be installed, it couldn't be found at $sevenZipBinaryLocation. You need it to extract the .tar.gz file from the zookeeper archives" -ForegroundColor Red
        exit 1
    }

    if ( -Not ( Test-Path $zookeeperExtractLocation ))
    {
        Write-Host "Zookeeper expected extrat location $zookeeperExtractLocation does not exist" -ForegroundColor Red
        $answer = Read-Host  -Prompt "Do you want to create it? (Y/N)" 
        if ( $answer.ToUpperInvariant() -eq "Y" )
        {
            Write-Host "Creating location at $zookeeperExtractLocation" -ForegroundColor Cyan
            mkdir $zookeeperExtractLocation
        }
        else
        {
            Write-Host "Won't extract to unexistent location, bye"
            exit 1
        }
    }


    ## 7-Zip List command parameters
    $argumentlist="$sevenZipArguments $($filename) -o$zookeeperExtractLocation"

    ## Execute command
    #start-process 'C:\Program Files\7-Zip\7z.exe' -argumentlist $argumentlist -wait -RedirectStandardOutput $tempfile
    start-process $sevenZipBinaryLocation -argumentlist $argumentlist -wait -Debug #-RedirectStandardOutput $tempfile
    Write-Debug "Before second pass filename is: $filename"
    $tarFile = Get-ChildItem $zookeeperExtractLocation
    #Write-Host "Before second pass tarfile is: $tarFile.Fullname"
    
    $argumentlist="$sevenZipArguments $($tarFile.FullName) -o$zookeeperExtractLocation"
    start-process $sevenZipBinaryLocation -argumentlist $argumentlist -wait -Debug #-RedirectStandardOutput $tempfile

    Remove-Item $tarFile.FullName

    # Move all from the newly create folder to one level up
    Move-Item $zookeeperExtractLocation\zookeeper*\* $zookeeperExtractLocation
    Rmdir $zookeeperExtractLocation\zookeeper-?.?.? -Exclude *jar*

    #Expand-Archive $filename -DestinationPath $zookeeperExtractLocation
    Copy-Item -Path $nssmLocalPath -Destination $zookeeperBinaryFolder
}
else 
{
    Write-Host "zookeeper had already been extracted to $zookeeperExtractLocation"
}

if(!(Test-Path $zookeeperBinaryLocation))
{
    Write-Host "Couldn't extract Zookeeper, check error messages and fix accordingly" -ForegroundColor Red
    exit 1
}

# Configure Zookeeper
Write-Host "Configuring Zookeper" -ForegroundColor Cyan

## Create configuration file
if ( -Not ( Test-Path $zookeeperConfigurationFileLocation) )
{
    Write-Host "Copying standard zookeeper configuration file to zookeeper" -ForegroundColor Cyan    
    if (-Not (Test-Path $zookeeperExampleConfigurationFileLocation) )
    {
        Write-Host "Standard zookeeper configuration file not found, is this a proper zookeeper extracted instance?" -ForegroundColor Red
        exit 1
    }

    Copy-Item $zookeeperExampleConfigurationFileLocation $zookeeperConfigurationFileLocation
}
else 
{
    Write-Host "Zookeeper configuration file already in place, good" -ForegroundColor Green
}

# Change so that it works without JAVA_HOME if it is not set
if ( -Not ( (Get-ChildItem env: | Where-Object {$_.Name -eq "JAVA_HOME"}) -and 
 (-Not ((Select-String -Path $zookeeperExtractLocation\bin\zkServer.cmd -SimpleMatch "%JAVA%") -eq $null))))
{
    Write-Host "JAVA_HOME not set, will adapt zookeeper for that" -ForegroundColor Cyan    
    (Get-Content $zookeeperExtractLocation\bin\zkServer.cmd) -replace '%JAVA%', 'java' | Set-Content $zookeeperExtractLocation\bin\zkServer.cmd
    Write-Host "Adapted Zookeeper to use java directly instead of via JAVA_HOME" -ForegroundColor Green
}

# Change so that logs to file
if ( (-Not ((Select-String -Path $zookeeperExtractLocation\conf\log4j.properties -SimpleMatch "ROLLINGFILE") -eq $null)))
{
    Write-Host "Configuring zookeeper to log to file" -ForegroundColor Cyan
    mkdir $zookeeperExtractLocation\logs
    (Get-Content $zookeeperExtractLocation\bin\zkEnv.cmd) -replace ',CONSOLE', ',ROLLINGFILE' | Set-Content $zookeeperExtractLocation\bin\zkEnv.cmd
    (Get-Content $zookeeperExtractLocation\bin\zkEnv.cmd) -replace 'set ZOO_LOG_DIR=%~dp0%..', 'set ZOO_LOG_DIR=%~dp0%..\logs' | Set-Content $zookeeperExtractLocation\bin\zkEnv.cmd
    #(Get-Content $zookeeperExtractLocation\conf\log4j.properties) -replace ', CONSOLE', ', ROLLINGFILE' | Set-Content $zookeeperExtractLocation\conf\log4j.properties
    #(Get-Content $zookeeperExtractLocation\conf\log4j.properties) -replace 'dir=.', 'dir=logs' | Set-Content $zookeeperExtractLocation\conf\log4j.properties
    Write-Host "Configured zookeeper to log to file" -ForegroundColor Green
}



## Append hosts to configuration file
Write-Host "Checking server instances in configuration file" -ForegroundColor Cyan
$file = Get-Content $zookeeperConfigurationFileLocation
$containsServer = $file | %{$_ -match "server.1"}
if( $containsServer -contains $true )
{
    Write-Host "Configuration file already contains server instances, good" -ForegroundColor Green
}
else
{
    Write-Host "Adding server instances to configuration file" -ForegroundColor Cyan
    $serverNr = 1
    $zookeeperHosts.Split(",") | ForEach {
        $output = "server." + $serverNr + "=" + $_ + ":2888:3888"
        Add-Content $zookeeperConfigurationFileLocation $output
        $serverNr++
    }
}


# Change datafolder location 
Write-Host "Checking data folder location in configuration file" -ForegroundColor Cyan
$file = Get-Content $zookeeperConfigurationFileLocation
$containsDefaultDataFolderLocation = $file | %{$_ -match "/tmp/zookeeper"}
if( $containsDefaultDataFolderLocation -contains $true )
{
    Write-Host "Adding custom data folder location to configuration file" -ForegroundColor Cyan    
    $dataPath = "$zookeeperExtractLocation\data" -replace "\\", "/"
    (Get-Content $zookeeperConfigurationFileLocation) -replace '/tmp/zookeeper', $dataPath | Set-Content $zookeeperConfigurationFileLocation
}
else
{
    Write-Host "Configuration file already contains custom data folder location, good" -ForegroundColor Green
}   

## Create myid file
Write-Host "Checking myid file" -ForegroundColor Cyan
if ( -Not ( Test-Path $zookeeperMyidFileLocation )) 
{

    Write-Host "Creating myid file" -ForegroundColor Cyan
    $myidFile = New-Item -Path $zookeeperMyidFileLocation -Force
    if ( $myIdFile -eq $null )
    {
        Write-Host "Error creating myid file" -ForegroundColor Red
        exit 1
    }
    Add-Content $myidFile $zookeeperHostNr 
}
else 
{ 
    Write-Host "Myid file already exists, good" -ForegroundColor Green
}


if ($createService)
{
	Write-Host "Setting up Zookeeper as a service" -ForegroundColor Cyan

	# Use nssm to create the service as we are trying to run an exe that is not compiled to be a service. See http://serverfault.com/questions/54676/how-to-create-a-service-running-a-bat-file-on-windows-2008-server
	# http://nssm.cc/commands
	$res = Start-Process $nssmZookeeperPath -ArgumentList "install $zookeeperServiceName $zookeeperBinaryLocation" -Wait -NoNewWindow -PassThru
	$res2 = Start-Process $nssmZookeeperPath -ArgumentList "set $zookeeperServiceName AppDirectory $zookeeperBinaryFolder" -Wait -NoNewWindow -PassThru


	Start-Sleep 2
	Start-Service -Name $zookeeperServiceName

	Write-Host "Checking if zookeeper service was created correctly" -ForegroundColor Cyan
	$iszookeeperRunning = Get-Service -Name $zookeeperServiceName
	if ( $iszookeeperRunning -eq $null ) 
	{ 
		Write-Host "Something went wrong setting up the service, it is not listed in the service list" -ForegroundColor Red
		exit 1
	}


	Write-Host "Waiting $serviceStartupWaitTime seconds to check if Zookeeper started correctly" -ForegroundColor Cyan
	Start-Sleep $serviceStartupWaitTime
	# Check that the service is effectively running 
	$iszookeeperRunning = Get-Service -Name $zookeeperServiceName
	if(-Not ( $iszookeeperRunning.Status -eq "Running" ) )
	{
		Write-Host "Something is wrong with the zookeeper service, please check service creation" -ForegroundColor Red
		exit 1
	}
	Write-Host "zookeeper is running correctly"	-ForegroundColor Green
}
else { Write-Host "Skipping service creation due to flag" -ForegroundColor Cyan }

Write-Host "zookeeper installed correctly" -ForegroundColor Green
exit 0