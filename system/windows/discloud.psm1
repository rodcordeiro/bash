function getMessage(){
    $key = $args[0][0];
    if ($args[0][1]){
        $language= $args[0][1];
    } else {
        $language= 1;
    }
    
    $messages = [PSCustomObject]@{
        'user_config_file_not_found'=@{
            1 = 'User settings not found.';
            2 = 'Configuracoes de usuario nao encontradas.';
        };
        'config_file_not_found' = @{
            1='Project settings not found. Please, run discloud init to set up';
            2='Configuracoes de projeto nao encontradas. Por favor, execute discloud init para configura-las';    
            
        };
        'token_message' = @{
            1='Please, inform your Discloud API Token';
            2= 'Por favor, informe seu token da API Discloud'
        };
        'default' = @{
            1='Script execution failure';
            2='Falha na execução do script';
        };
        'inform_project_name' = @{
            1='Inform the project name';
            2='Informe o nome do projeto';
        };
        'inform_project_id' = @{
            1='Inform the project id';
            2='Informe o id do projeto';
        };
        'created_discloud_file' = @{
            1='Discloud project created. For including files, you must open .discloud and add files on "Files" field';
            2='Projeto Discloud criado. Para inclusao dos arquivos, acesse o .discloud e adicione-os no campo "Files"';
        };
     
    } 
    
    return $messages.$key.$language
}
function get_config(){
    if($(Test-Path -Path "$($env:USERPROFILE)\Discloud\.discloud")){
        $config = Get-Content -Path $(Resolve-Path -Path "$($env:USERPROFILE)\Discloud\.discloud") | ConvertFrom-Json
        return $config
    }
    getMessage('user_config_file_not_found')
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
    return $settings
    
}

function init(){
    $config = get_config
    $settings = @{}
    $name = Read-Host 'Inform the project name'
    $settings | Add-Member -type NoteProperty -name name -Value $name
    $msg = 'Inform the project id'
    $id = Read-Host $msg
    $settings | Add-Member -type NoteProperty -name id -Value $id
    $settings | Add-Member -type NoteProperty -name files -Value @()
    $settings | Add-Member -type NoteProperty -name exclude -Value @()
    
    New-Item -Type 'File' -Name '.discloud' -Value $($settings | ConvertTo-Json) | Out-Null
    
}

function commit(){
    $config = get_config
    $file = get_config_file($PWD)
    if(!$file) {
        $message = getMessage('config_file_not_found',$config.language)
        Write-Host $message
        return
    }
    $content = Get-Content -Path $file | ConvertFrom-Json
    if(Test-Path './app.zip'){
        Remove-Item -Path './app.zip' -Force
    }
    New-Item -Type 'directory' -Name 'tmp' | Out-Null
    $content.files | ForEach-Object {
        Copy-Item -Path $(Resolve-Path -Path "./$($_)") '.\tmp' -Recurse -Force
    }
    Compress-Archive -Path '.\tmp\*' -DestinationPath ".\app.zip" -Force | Out-Null
    Remove-Item -Force -Recurse -Path '.\tmp' 
    $url = "https://discloud.app/status/bot/$($content.id)/commit"
    $upload = Invoke-MultipartFormDataUpload('.\app.zip',$config.token,$url)
    $upload
}

function Invoke-MultipartFormDataUpload
{
    [CmdletBinding()]
    PARAM
    (
        [string][parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$InFile,
        [string][parameter(Mandatory = $true)]$token,
        [Uri][parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]$Uri,
        [System.Management.Automation.PSCredential]$Credential
    )
    BEGIN
    {
        if (-not (Test-Path $InFile))
        {
            $errorMessage = ("File {0} missing or unable to read." -f $InFile)
            $exception =  New-Object System.Exception $errorMessage
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, 'MultipartFormDataUpload', ([System.Management.Automation.ErrorCategory]::InvalidArgument), $InFile
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        Add-Type -AssemblyName System.Web

        $mimeType = [System.Web.MimeMapping]::GetMimeMapping($InFile)

        if ($mimeType)
        {
            $ContentType = $mimeType
        }
        else
        {
            $ContentType = "application/octet-stream"
        }
    
    }
    PROCESS
    {
        Add-Type -AssemblyName System.Net.Http

        $httpClientHandler = New-Object System.Net.Http.HttpClientHandler

        if ($Credential)
        {
            $networkCredential = New-Object System.Net.NetworkCredential @($Credential.UserName, $Credential.Password)
            $httpClientHandler.Credentials = $networkCredential
        }

        $httpClient = New-Object System.Net.Http.Httpclient $httpClientHandler

        $packageFileStream = New-Object System.IO.FileStream @($InFile, [System.IO.FileMode]::Open)

        $contentDispositionHeaderValue = New-Object System.Net.Http.Headers.ContentDispositionHeaderValue "form-data"
        $contentDispositionHeaderValue.Name = "fileData"
        $contentDispositionHeaderValue.FileName = (Split-Path $InFile -leaf)

        $streamContent = New-Object System.Net.Http.StreamContent $packageFileStream
        $streamContent.Headers.ContentDisposition = $contentDispositionHeaderValue
        $streamContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue $ContentType
        $streamContent.Headers | Add-Member -type NoteProperty -name 'api-token'  -Value $token
        $content = New-Object System.Net.Http.MultipartFormDataContent
        $content.Add($streamContent)

        try
        {
            $response = $httpClient.PostAsync($Uri, $content).Result

            if (!$response.IsSuccessStatusCode)
            {
                $responseBody = $response.Content.ReadAsStringAsync().Result
                $errorMessage = "Status code {0}. Reason {1}. Server reported the following message: {2}." -f $response.StatusCode, $response.ReasonPhrase, $responseBody

                throw [System.Net.Http.HttpRequestException] $errorMessage
            }

            $responseBody = [xml]$response.Content.ReadAsStringAsync().Result

            return $responseBody
        }
        catch [Exception]
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        finally
        {
            if($null -ne $httpClient)
            {
                $httpClient.Dispose()
            }

            if($null -ne $response)
            {
                $response.Dispose()
            }
        }
    }
    END { }
}


Function get_config_file([string]$Path) {
    if ($(Split-Path -Path $Path -Leaf) -ne '.discloud') {
        if (Test-Path -Path "$Path\.discloud") {
            return Resolve-Path -Path "$Path\.discloud"
        }
        if (Test-Path -Path "..\$Path\.discloud") {
            return Resolve-Path -Path "$Path\.discloud"
        }
        $folders = $(Get-ChildItem "$Path\*" -Depth 0 -Directory)
        $folders | ForEach-Object {
            $f = "$Path\$_"
            if (Test-Path -Path "$f\.discloud") {
                
                return Resolve-Path -Path "$f\.discloud"
            }
            $folders2 = $(Get-ChildItem "$f\*" -Depth 0 -Directory)
            $folders2 | ForEach-Object {
                if (Test-Path -Path "$f\$_\.discloud") {
                    
                    return Resolve-Path -Path "$f\$_\.discloud"
                }               
            
            }
        }
    }
    else {
        return Resolve-Path -Path "$Path"
    }
    
}

function discloud(
    [Parameter(Position=0, Mandatory=$True)]
    [ValidateSet("commit", "init")]
    [string]$Command
  ){
      switch ($Command) {
        'commit' { 
            commit
         }
         'init' { 
            init
         }
          Default {}
      }
  }
Export-ModuleMember -Function discloud