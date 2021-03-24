<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
#>

param(
    # The name of the KeyVault
    [Parameter(Mandatory = $true)]
    [string]    $KeyVaultName

    # The name of the certificate used for SSL encryption
    [Parameter(Mandatory = $true)]
    [string]    $SslCertificateName,

    # The name of the certificate used for token signing
    [Parameter(Mandatory = $true)]
    [string]    $SignCertificateName,

    # The host name of the CreateToken Azure Function
    [Parameter(Mandatory = $true)]
    [string]    $TokenFactoryHostname
)

function Set-PrivateKeyPermissions {

    param (
        # The thumbprint of the target certificate
        [Parameter(Mandatory = $true)]
        [string] $Thumbprint
    )

    # resolve certificate private key
    $certKeyName = (((Get-ChildItem -Path CERT:\LocalMachine\my | Where-Object { $_.Thumbprint -eq $Thumbprint } | Select-Object -First 1).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
    $certKeyPath = $env:ProgramData + "\Microsoft\Crypto\RSA\MachineKeys\" + $certKeyName
    $certKeyAcl = Get-Acl $certKeyPath

    # grant permissions on certificate private key
    $permission = "NT AUTHORITY\NETWORK SERVICE", "Read", "Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $certKeyAcl.AddAccessRule($accessRule)
    Set-Acl $certKeyPath $certKeyAcl
}

function Remove-CertificatePrivateKey {

    param (
        # The thumbprint of the target certificate
        [Parameter(Mandatory = $true)]
        [string] $Thumbprint
    )

    # resolve the certificate by thumbprint
    $certificate = Get-ChildItem -Path CERT:\LocalMachine\my | Where-Object { $_.Thumbprint -eq $Thumbprint } | Select-Object -First 1

    if ($certificate) {

        $certificatePath = Join-Path $PSScriptRoot "$Thumbprint.cer"

        try {

            $certificate | Export-Certificate -FilePath $certificatePath -Force | Out-Null

            # replace the existing certificate
            Import-Certificate -FilePath $certificatePath -CertStoreLocation Cert:\LocalMachine\My | Out-Null

            if ($certificate.Issuer -eq $certificate.Subject) {

                # this is a self signed certificate - import the certificate also to trusted root
                Import-Certificate -FilePath $certificatePath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
            }
        }
        finally {

            # clean up - remove exported certificate
            Remove-Item -Path $certificatePath -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

function Install-ApplicationRequestRouting {

    param (
        [Parameter(Mandatory = $false)]
        [string] $Hostname
    )

    $msiUrl = "https://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi"
    $msiPath = (Join-Path $PSScriptRoot ($msiUrl.Substring($msiUrl.LastIndexOf("/") + 1))) + ".msi"

    if (!(Test-Path $msiPath -PathType leaf)) {

        # download WebPI installer if needed
        Invoke-WebRequest $msiUrl -OutFile $msiPath
    }

    # install WebPI
    $logPath = [System.IO.Path]::ChangeExtension($msiPath, ".log")
    Start-Process "msiexec.exe" -ArgumentList @( "/qn", "/i $msiPath", "/log $logPath" ) -NoNewWindow -Wait | Out-Null

    # install WebPI packages
    $logPath = [System.IO.Path]::ChangeExtension($logPath, ".packages.log")
    Start-Process "C:\Program Files\Microsoft\Web Platform Installer\WebPiCmd-x64.exe" -ArgumentList @( "/Install", "/Products:'UrlRewrite2,ARRv3_0'", "/AcceptEULA", "/Log:$logPath" ) -NoNewWindow -Wait | Out-Null

    if ($Hostname) {

        $appcmd = Join-Path $env:windir "System32\inetsrv\appcmd.exe"
        $ruleName = "TokenFactoryAPI"

        # enable ARR proxy
        Start-Process $appcmd -ArgumentList @( "set", "config", "-section:system.webServer/proxy", "/enabled:`"True`"", "/commit:apphost" ) -NoNewWindow -Wait

        # set allowed server variables
        Start-Process $appcmd -ArgumentList @( "set", "config", "-section:system.webServer/rewrite/allowedServerVariables", "/+`"[name='HTTP_X_FORWARDED_HOST']`"", "/commit:apphost" ) -NoNewWindow -Wait

        # create API rewrite rule
        Start-Process $appcmd -ArgumentList @( "set", "config", "-section:system.webServer/rewrite/globalRules", "/+`"[name='$ruleName',patternSyntax='Wildcard',stopProcessing='True']`"", "/commit:apphost" ) -NoNewWindow -Wait
        Start-Process $appcmd -ArgumentList @( "set", "config", "-section:system.webServer/rewrite/globalRules", "/`"[name='$ruleName']`".match.url:`"api/*`"", "/commit:apphost" ) -NoNewWindow -Wait
        Start-Process $appcmd -ArgumentList @( "set", "config", "-section:system.webServer/rewrite/globalRules", "/`"[name='$ruleName']`".action.type:`"Rewrite`"", "/commit:apphost" ) -NoNewWindow -Wait
        Start-Process $appcmd -ArgumentList @( "set", "config", "-section:system.webServer/rewrite/globalRules", "/`"[name='$ruleName']`".action.url:`"https://$Hostname/{R:0}`"", "/commit:apphost" ) -NoNewWindow -Wait

        # set custom header for backend
        Start-Process $appcmd -ArgumentList @( "set", "config", "-section:system.webServer/rewrite/globalRules", "/+`"[name='$ruleName']`".serverVariables.`"[name='HTTP_X_FORWARDED_HOST', value='{HTTP_HOST}']`"", "/commit:apphost" ) -NoNewWindow -Wait
    }
}

try {

    Start-Transcript -Path (Join-Path $PSScriptRoot "gateway.log")

    # install RDS Gateway Windows Feature
    Add-WindowsFeature -Name RDS-Gateway -IncludeAllSubFeature

    # install Remote Desktop Service Tools
    Add-WindowsFeature -Name RSAT-RDS-Gateway -IncludeAllSubFeature

    # install IIS management console and scription tools
    Install-WindowsFeature -Name Web-Mgmt-Console, Web-Scripting-Tools

    # install IIS ARR and configure api forwarding
    Install-ApplicationRequestRouting -Hostname $TokenFactoryHostname

    # install RDGateway FedAuth plug-in
    $msi = Join-Path $PSScriptRoot "RDGatewayFedAuth.msi"
    $log = [System.IO.Path]::ChangeExtension($msi, '.log')
    Start-Process "msiexec.exe" -ArgumentList @("/qn", "/lv!", "$log", "/i", "$msi", "ACCEPTEULA=1") -Wait -NoNewWindow

    # install NuGet package provider (dependency for PowerShellGet)
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force

    # install PowerShellGet (used to install Azure Powershell)
    Install-Module -Name PowerShellGet -Confirm:$false -Force

    # install Azure PowerShell
    Install-Module -Name Az -AllowClobber -Scope AllUsers -Confirm:$false -Force

    $sslCertificate = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $SslCertificateName
    $signCertificate = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $SignCertificateName

    # grant private key access on certificates
    Set-PrivateKeyPermissions -Thumbprint $sslCertificate.Thumbprint
    Set-PrivateKeyPermissions -Thumbprint $signCertificate.Thumbprint

    # install RDS module
    Import-Module RemoteDesktopServices

    # set gateway SSL certificate
    Set-Item -Path "RDS:\GatewayServer\SSLCertificate\Thumbprint" -Value $sslCertificate.Thumbprint

    # Remove the private key from signing certificate and handle self signed certificates properly
    Remove-CertificatePrivateKey -Thumbprint $signCertificate.Thumbprint

    # set gateway signing certificate
    $wmi = Get-WmiObject -computername $env:COMPUTERNAME -NameSpace "root\TSGatewayFedAuth2" -Class "FedAuthSettings"
    $wmi.TrustedIssuerCertificates = $signCertificate.Thumbprint
    $wmi.IdleTimeoutMinutes = 120
    $wmi.SessionTimeoutMinutes = 720
    $wmi.Put()

    # register FedAuth plug-in at gateway
    $wmi = Get-WmiObject -Namespace root\CIMV2\TerminalServices -Class Win32_TSGatewayServerSettings
    $wmi.SetAuthenticationPlugin("FedAuthAuthenticationPlugin")
    $wmi.SetAuthorizationPlugin("FedAuthAuthorizationPlugin")
    $wmi.RecycleRpcApplicationPools()

    # restart gateway service
    @("W3SVC", "TSGateway") | ForEach-Object { Restart-Service -Name $_ -Force }
}
finally {

    Stop-Transcript
}
