
<#PSScriptInfo

.VERSION 1.0

.GUID f1eeb551-d414-4072-908c-d3d4cf5b00cf

.AUTHOR Rodrigo Cordeiro <rodrigomendoncca@gmail.com> (https://rodcordeiro.com)

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 Install Discloud command line functions 

#> 
Param()

# Changes output encoding to UTF8
$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.Utf8Encoding

rm -Recurse -Force "$($env:USERPROFILE)\Discloud\"

$IsAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (!$IsAdmin) {
    Write-Host 'You must run as administrator'
    return
}

function getMessage(){
    $key = $args[0][0];
    $language= $args[0][1];
    $messages = @{
        'token_message' = @{
            'en' = 'Please, inform your Discloud API Token';
            'ptbr' = 'Por favor, informe seu token da API Discloud'
        }
    }
    switch ($x)
    {
        {$language -eq 1 } {return $messages[$key].en}
        {$language -eq 2 } {return $messages[$key].ptbr}
        Default { 
            return $messages[$key].en
        }
    }    
}

# Creates discloud folder 
if (!$(Test-Path -Path "$($env:USERPROFILE)\Discloud")){
    New-Item -Type "Directory" -Name 'Discloud' -Path $env:USERPROFILE | Out-Null
    New-Item -Type "File" -Name '.discloud' -Path "$($env:USERPROFILE)\Discloud" | Out-Null
    Write-Host "Please, select the language:"
    Write-Host "1. English"
    Write-Host "2. Portugues (Brasil)"
    Write-Host ""
    $settings = [PSCustomObject]@{}
    $language = Read-Host "Inform the language number"
    $msg = getMessage('token_message', 2)
    $token = Read-Host "$msg"
    $settings | Add-Member -type NoteProperty -name language  -Value $language
    $settings | Add-Member -type NoteProperty -name token  -Value $token
    Add-Content -Path "$($env:USERPROFILE)\Discloud\.discloud" -Value $($settings | ConvertTo-Json)
}

# Stores discloud scripts


# Imports discloud into profile
# Import-Module "$($env:USERPROFILE)\Discloud\discloud.psm1"
