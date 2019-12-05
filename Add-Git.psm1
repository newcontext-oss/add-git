
# Setup TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Thanks to John Freeman: https://stackoverflow.com/a/54935264/238074
function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    do {
      $name = [System.IO.Path]::GetRandomFileName()
      $item = New-Item -Path $parent -Name $name -ItemType "directory" -ErrorAction SilentlyContinue
    } while (-not $item)
    return $Item.FullName
}

function Add-Git {

    <#
    
        .Synopsis
        Installs Git-for-Windows.
        
        .Description
        Installs Git-for-Windows (https://gitforwindows.org/) on a 
        Windows machine. Installs latest 64-bit version. Install location
        is C:\Program Files\Git (default). 

        This software is copyright New Context Security and open sourced
        under the MIT License, 2019 version. See more details
        at https://opensource.org/licenses/MIT . Author:
        Kevin Buchs.

        .Parameter InstallPath
        Parent directory under which you want Git installed. Default is
        "C:\Program Files"

        .Inputs
        None

        .Outputs
        A few logging messages via Write-Host and a potential Write-Error
        
        .Notes
        Full example:
        Add-Git   
        # Add git binary paths to PATH variable and get gitting
        $env:PATH += ";c:\program files\git\bin;c:\program files\git\usr\bin"
        git clone http://repo.example.com

        .Link
        https://github.com/newcontext-oss/add-git

        .Link
        https://gitforwindows.org/

        .Link
        https://newcontext.com

    #>

    [CmdletBinding()]
    param(
        [string]$InstallPath = "C:\Program Files"
    )

    $tempDir = New-TemporaryDirectory
    $cfgFile = "$tempDir\gitinstaller.inf"
    $installer = "$tempDir\gitinstaller.exe"

    # First, find latest version of Git for Windows
    $url="https://api.github.com/repos/git-for-windows/git/releases/latest"
    $latestInfo = Invoke-WebRequest $url | ConvertFrom-Json  `
        | Select-Object -expandproperty html_url
    # example: $latestInfo="https://github.com/git-for-windows/git/releases/tag/v2.23.0.windows.1"
    # pick off the version and build the download URL
    $fullVersion = Split-Path -Path $latestInfo -Leaf
    $version = $fullVersion -replace '^v','' -replace '\.windows',''
    $fileName = "Git-${version}-64-bit.exe"
    $latestUrl = ($latestInfo -Replace '/releases/tag/','/releases/download/') + "/" + $fileName
    # download the latest version
    Invoke-WebRequest -uri $latestUrl -outfile $installer

    # Git installer configuration
    "[Setup]
    Lang=default
    Dir=$InstallPath\Git
    Group=Git
    NoIcons=1
    SetupType=compact
    Components=main
    Tasks=
    EditorOption=VIM
    CustomEditorPath=
    PathOption=Cmd
    SSHOption=OpenSSH
    TortoiseOption=false
    CURLOption=OpenSSL
    CRLFOption=CRLFCommitAsIs
    BashTerminalOption=ConHost
    PerformanceTweaksFSCache=Disabled
    UseCredentialManager=Disabled
    EnableSymlinks=Enabled
    EnableBuiltinInteractiveAdd=Disabled
    PrivilegesRequiredOverridesAllowed=commandline
    " | Out-File -FilePath $cfgFile -Force

    # install git
    # Occasionally the Invoke-Expression fails for unknown reasons. So we will retry it
    # if we find a expected file is not present
    Write-Host "Running installer"
    $collegeTry = 15 # number of times to try to install before giving up
    $counter = 0
    $endLoop = $false
    while (-not $endLoop -and $counter -lt $collegeTry) {
        Invoke-Expression "$installer /loadinf=$cfgFile /verysilent /allusers /log=$InstallPath\git-install.log"
        $counter += 1
        $endLoop = Test-Path '$InstallPath\Git\unins00*.msg'
        if (-not $endLoop) {
            Write-Host "Sleeping 60 seconds"
            Start-Sleep -Seconds 60  # wait for completion
            $endLoop = Test-Path "$InstallPath\Git\unins00*.msg"
        }
        if (-not $endLoop) { Write-Host "failed..Retrying installer" }
    }
    if ($counter -eq $collegeTry) { Write-Error "Git installer failed to run. Check log in $tempDir" }

    Remove-Item -Recurse -Force $tempDir
}

Export-ModuleMember -Function Add-Git
