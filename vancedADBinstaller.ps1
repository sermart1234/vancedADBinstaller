[CmdletBinding()]
param(
    [ValidateSet('usb', 'wifi')]
    $adb,
    [ValidateSet('dark', 'black')]
    $theme,
    [ValidateSet('stable', 'beta')]
    $channel,
    [switch]$latest,
    [switch]$uninstall,
    [switch]$saveDownloads
)

$msgTable = Data {
    #culture="en-US"
    ConvertFrom-StringData @'
    device—onnected = The device is connected
    attachDevice = Connect the device and enable USB debugging in the developer settings
    allow—onnection = Allow connection
    unexpectedError = Unexpected error

    wasWIFIused = Is there {0}:{1} in the list of connected devices?
    wifiWasNotUsed = No. The device has not been paired before
    wifiWasUsed = Yes. I used Wi-Fi debugging earlier
    start—onnection = Start connection
    enterAddr = Enter the address
    portMsg = The connection port may differ from the pairing port
    enterPort = Enter the port
    badAddrOrPort = Wrong IP address or port
    keepOldValue = Press Enter to save the old value
    badPort = Wrong port
    notPaired = Paired was not performed

    startPairing = Start pairing
    enterPswd = Enter the password
    successfullyPaired = The device is paired

    selectVersion = Select a version:
    installed = (installed)
    latest = (latest)


    failedDel = failed to uninstall
    deleted = uninstall

    noInternet = There is no internet connection or the server is unavailable

    adbOver = Select the connection method:
    adbOverUSB = via USB
    adbOverWIFI = via WiFi (for Android 11 and above)
    
    arch = Device architecture:
    language = System language
    installedVersion = Installed version

    themeRequest = —hoose theme:
    themeDark = Dark (default)
    themeBlack = Black (recommended for AMOLED)

    channelRequest = Select a channel:
    channelStable = Stable
    channelBeta = Beta

    allowInstall = Allow installation on the device
    failedInstall = Failed to install
    noSuchFile = No such file or directory
    uninstallAndRepeat = Try deleting and repeat
    isInstalled = is installed

    openLink = Vanced is default application for links to youtube.com
'@
}
Import-LocalizedData -BindingVariable msgTable

function usbADB
{
    while($True)
    {
        Invoke-Expression ".\adb.exe get-state device" -OutVariable output -ErrorVariable errors | Out-Null
        if ($output -eq "device")
        {
            Write-Host $msgTable.device—onnected -ForegroundColor Green
            break
        }
        else
        {
            if (($errors | Select-String "error: no devices/emulators found" ) -or 
                ($errors | Select-String "error: device offline") -or 
                ($errors | Select-String "error: no devices found"))
            {
                Write-Host $msgTable.attachDevice
            }
            elseif ($errors | Select-String "error: device unauthorized" )
            {
                Write-Host $msgTable.allow—onnection
            }
            elseif ($errors | Select-String "error: more than one device/emulator")
            {
                Invoke-Expression ".\adb.exe kill-server" -OutVariable output -ErrorVariable errors | Out-Null
            }
            else
            {
                Write-Host $msgTable.unexpectedError -ForegroundColor Red
            }
        }
        pause
    }
}

function wirelessADB
{
    Write-Host ($msgTable.wasWIFIused -f $env:UserName, $env:COMPUTERNAME) -ForegroundColor Yellow
    Write-Host "1:"$msgTable.wifiWasNotUsed
    Write-Host "2:"$msgTable.wifiWasUsed
    
    while($True)
    {
        $choice = Read-Host
        if($choice -eq 1)
        {
            $pair = 1
            break
        }
        if($choice -eq 1)
        {
            $pair = 0
            break
        }
    }

    if ($pair){ 
        pairWirelessADB(0)
    }

    Write-Host $msgTable.start—onnection
    if ($pair -eq 0)
    {
        Write-Host $msgTable.enterAddr
        $addr = Read-Host
    }

    if ($pair)
    {
        Write-Host $msgTable.portMsg -ForegroundColor Green
    }
    Write-Host $msgTable.enterPort
    $port = Read-Host


    while($True)
    {
        $adb = ".\adb.exe connect {0}:{1}" -f $addr, $port
        Invoke-Expression $adb -OutVariable output -ErrorVariable errors | Out-Null

        if ($output | Select-String "connected to"){
            Write-Host $msgTable.device—onnected -ForegroundColor Green
            break
        }
        else
        {
            if (($output | Select-String "cannot connect to") -or 
                ($output | Select-String "cannot resolve host"))
            {
                Write-Host $msgTable.badAddrOrPort -ForegroundColor Red
                Write-Host $msgTable.keepOldValue -ForegroundColor Green
                Write-Host $msgTable.enterAddr
                if ($value = Read-Host $addr) { $addr = $value }
                Write-Host $msgTable.enterPort
                if ($value = Read-Host $port) { $port = $value }
            }
            elseif ($output | Select-String "bad port number")
            {
                Write-Host $msgTable.badPort -ForegroundColor Red
                Write-Host $msgTable.enterPort
                if ($value = Read-Host $port) { $port = $value }
            }
            elseif ($output | Select-String "failed to connect to")
            {
                Write-Host $msgTable.notPaired -ForegroundColor Red
                pairWirelessADB($addr)
            }
            else 
            {
                Write-Host $msgTable.unexpectedError -ForegroundColor Red
                exit
            }
        }
        
    }
    
}

function pairWirelessADB($addr2)
{
    Write-Host $msgTable.startPairing
    if($addr2 -eq 0){
        Write-Host $msgTable.enterAddr
        $addr = Read-Host}
    else{
        $addr = $addr2
    }

    Write-Host $msgTable.enterPort
    $port = Read-Host
    Write-Host $msgTable.enterPswd
    $pswd = Read-Host
    
    while($True)
    {
        $adb = ".\adb.exe pair {0}:{1} {2}" -f $addr, $port, $pswd
        Invoke-Expression $adb -OutVariable output -ErrorVariable errors | Out-Null
        if ($output | Select-String "Successfully paired"){
        Write-Host $msgTable.successfullyPaired -ForegroundColor Green
        break
        }
        else
        {
            if ($output | Select-String "Failed: Unable to start pairing client.")
            {
        
                if($addr2 -eq 0)
                {
                    Write-Host $msgTable.badAddrOrPort -ForegroundColor Red
                    Write-Host $msgTable.keepOldValue -ForegroundColor Green
                    Write-Host $msgTable.enterAddr
                    if ($value = Read-Host $addr) { $addr = $value }
                }
                else {
                    Write-Host $msgTable.badPort -ForegroundColor Red
                    Write-Host $msgTable.keepOldValue -ForegroundColor Green
                }
            
            
                Write-Host $msgTable.enterPort
                if ($value = Read-Host $port) { $port = $value }
                Write-Host $msgTable.enterPswd
                if ($value = Read-Host $pswd) { $pswd = $value }
            }
            elseif ($output | Select-String "Failed: Wrong password or connection was dropped.")
            {
                Write-Host $msgTable.enterPswd
                if ($value = Read-Host $pswd) { $pswd = $value }
            }
            else
            {
                Write-Host $msgTable.unexpectedError -ForegroundColor Red
                exit
            }
        }
    }
}

function GetAbi
{
    return (.\adb shell getprop ro.product.cpu.abi) -replace "-","_"
}

function GetSystemLanguage
{
    $locale = .\adb shell getprop persist.sys.locale
    return $locale -replace '\s*-.*'
}

function CheckInstalledVersion  ($pkgname)
{
    $cmd = ".\adb.exe shell dumpsys package {0}" -f $pkgname
    Invoke-Expression $cmd -OutVariable output -ErrorVariable errors | Out-Null
    $version = $output | Select-String "versionName"
    return $version  -replace '.*='
}

function VancedApi
{
    $response = Invoke-WebRequest -Uri "https://mirror.codebucket.de/vanced/api//v1/latest.json" #"https://api.vancedapp.com/api/v1/latest.json"
    if ($response.statuscode -eq '200') {
        $json = ConvertFrom-Json $response.Content
    }
    return $json
}

function VancedVersion ($URI)
{
    $URI = $URI + "versions.json"
    $response = Invoke-WebRequest -Uri $URI
    if ($response.statuscode -eq '200') {
        $json = ConvertFrom-Json $response.Content
    }
    return $json
}

function SelectVancedVersion ($list)
{
    #($list.vanced | measure -Maximum).maximum
    Write-Host $msgTable.selectVersion -ForegroundColor Yellow
    ForEach ($item in $list.vanced)
    {
        $color = "White"
        $temp_str = "{0}:{1}" -f ($list.vanced.IndexOf($item) + 1), $item

        if ($item -eq $installedVersionVanced)
        {
            $temp_str = $temp_str + " " + $msgTable.installed
            $color = "Yellow"
        }

        if ($item -eq $api.vanced.version)
        {
            $temp_str = $temp_str + " " + $msgTable.latest
            $color = "Green"
        }
    
        Write-Host $temp_str -ForegroundColor $color
    }

    while($True)
    {
        $choice = Read-Host
        if (($choice -gt 0) -and
            ($list.vanced.length -ge $choice))
        {
            break
        }
    }

    return $list.vanced[$choice - 1]
}

function Downloader ($uri, $path)
{	
    Invoke-WebRequest -Uri $uri -OutFile $path -ErrorVariable errors
}

   
#############################################################################
#TODO is_microg_broken
$api = VancedApi
if ($api -eq $null)
{
    Write-Host $msgTable.noInternet
    exit
}

if ($adb -eq $null)
{
    Write-Host $msgTable.adbOver -ForegroundColor Yellow
    Write-Host "1:"$msgTable.adbOverUSB -ForegroundColor Green
    Write-Host "2:"$msgTable.adbOverWIFI

    while($adb -eq $null)
    {
        $choice = Read-Host

        Switch($choice)
        {
            1{$adb = 'usb'}
            2{$adb = 'wifi'}
            default {}
        }
    }
}

Switch($adb)
{
    'usb'{usbADB}
    'wifi'{wirelessADB}
    default {}
}

$abi = GetAbi
$language = GetSystemLanguage

Write-Host $msgTable.arch $abi
Write-Host $msgTable.language $language

$installedVersionVanced = CheckInstalledVersion("com.vanced.android.youtube")
if ($installedVersionVanced){ write-host $msgTable.installedVersion "YouTube Vanced:" $installedVersionVanced}

$installedVersionMicroG = CheckInstalledVersion("com.mgoogle.android.gms")
if ($installedVersionMicroG){ write-host $msgTable.installedVersion "microG:" $installedVersionMicroG}

$installedVersionOrig = CheckInstalledVersion("com.google.android.youtube")
if ($installedVersionOrig){ write-host $msgTable.installedVersion "Google YouTube:" $installedVersionOrig}

if ($uninstall)
{
    Invoke-Expression ".\adb.exe shell pm uninstall com.vanced.android.youtube" | Out-Null
    if ($LASTEXITCODE)
    {
        Write-Host $msgTable.failedDel"Vanced" -ForegroundColor Red
    }
    else
    {
    Write-Host "Vanced"$msgTable.deleted -ForegroundColor Green
    }

    Invoke-Expression ".\adb.exe shell pm uninstall com.mgoogle.android.gms" | Out-Null
    if ($LASTEXITCODE)
    {
        Write-Host $msgTable.failedDel"microG" -ForegroundColor Red
    }
    else
    {
    Write-Host "microG"$msgTable.deleted -ForegroundColor Green
    }
    exit
}

if ($theme -eq $null)
{
    Write-Host $msgTable.themeRequest -ForegroundColor Yellow
    Write-Host "1:"$msgTable.themeDark
    Write-Host "2:"$msgTable.themeBlack

    while($theme -eq $null)
    {
        $choice = Read-Host
        Switch($choice)
        {
            1{$theme = 'dark'}
            2{$theme = 'black'}
            default {}
        }
    }
}

if($channel -eq $null)
{
    Write-Host $msgTable.channelRequest -ForegroundColor Yellow
    Write-Host "1:"$msgTable.channelStable
    Write-Host "2:"$msgTable.channelBeta

    while($channel -eq $null)
    {
        $choice = Read-Host
        Switch($choice)
        {
            1{$channel = 'stable'}
            2{$channel = 'beta'}
            default {}
        }
    }
}

$URI = "https://mirror.codebucket.de/vanced/api/"

Switch($channel)
{
    'stable'{$URI = $URI + "v1/"}
    'beta'{$URI = $URI + "beta/"}
    default {}
}

if ($latest -and ($channel -eq 'stable'))
{
    $version = $api.vanced.version
    
}
else
{
    $versions = VancedVersion($URI)
    $version = SelectVancedVersion($versions)
}

$URI = $URI + "apks/v" + $version + "/nonroot/"
$PATH = "Downloads/Vanced/" + $version + "/"

[System.Collections.ArrayList]$listURI = @()
[System.Collections.ArrayList]$listPATH = @()

$temp = "Theme/{0}.apk" -f $theme
$listURI.Add($URI + $temp)| Out-Null
$listPATH.Add($PATH + $temp)| Out-Null

$temp = "Arch/split_config.{0}.apk" -f $abi
$listURI.Add($URI + $temp)| Out-Null
$listPATH.Add($PATH + $temp)| Out-Null

$temp = "Language/split_config.{0}.apk" -f "en"
$listURI.Add($URI + $temp)| Out-Null
$listPATH.Add($PATH + $temp)| Out-Null

if (($api.vanced.langs.Contains($language)) -and ($language -ne "en"))
{
    $temp = "Language/split_config.{0}.apk" -f $language
    $listURI.Add($URI + $temp)| Out-Null
    $listPATH.Add($PATH + $temp)| Out-Null
}

ForEach ($Uri in $listURI){
    $indexPATH = $listURI.IndexOf($URI)
    
    If(!(test-path $listPATH[$indexPATH]))
    {
        New-Item -Force -Path $listPATH[$indexPATH] | Out-Null
        Downloader $Uri $listPATH[$indexPATH]
    }
}

$cmd = ".\adb.exe install-multiple"
ForEach ($item in $listPATH){
    $cmd = $cmd + " " + $item
}

Write-Host $msgTable.allowInstall -ForegroundColor Yellow
Invoke-Expression $cmd -OutVariable output -ErrorVariable errors | Out-Null
if ($LASTEXITCODE)
{
    Write-Host $msgTable.failedInstall"Vanced" -ForegroundColor Red
    if ($errors | Select-String "No such file or directory" )
    {
        Write-Host $msgTable.noSuchFile
    }
    if($installedVersionVanced)
    {
        Write-Host $msgTable.uninstallAndRepeat
    }
    exit
}
else
{
    Write-Host "Vanced"$msgTable.isInstalled
}

if ($installedVersionOrig)
{
    Invoke-Expression ".\adb.exe shell pm set-app-link --user 0 com.google.android.youtube never"
}
Invoke-Expression ".\adb.exe shell pm set-app-link --user 0 com.vanced.android.youtube always"
Write-Host $msgTable.openLink -ForegroundColor Green

$PATHmicroG = "../Downloads/microG/microG.apk"
echo $PATHmicroG $api.microg.url
If(!(test-path $PATHmicroG))
{
    New-Item -Force $PATHmicroG | Out-Null
    Downloader $api.microg.url $PATHmicroG
}

$cmdMicroG = ".\adb.exe install " + $PATHmicroG
Write-Host $msgTable.allowInstall -ForegroundColor Yellow
Invoke-Expression $cmdMicroG -OutVariable output -ErrorVariable errors | Out-Null
if ($LASTEXITCODE)
{
    Write-Host $msgTable.failedInstall"microG" -ForegroundColor Red
    if ($errors | Select-String "No such file or directory" )
    {
        Write-Host $msgTable.noSuchFile
    }
    if($installedVersionMicroG)
    {
        Write-Host $msgTable.uninstallAndRepeat
    }
}
else
{
    Write-Host "microG"$msgTable.isInstalled
}

if ($saveDownloads -eq $False)
{
    Remove-Item "Downloads" -recurse
}

exit