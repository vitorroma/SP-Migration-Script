# Configura��es de autentica��o
$clientId = "xx00x0x0x0x-x000-0000-xxxx-xxxx0000xxx00"
$clientSecret = "xx00x0x0x0x-x000-0000-xxxx-xxxx0000xxx00"
$tenantId = "xx00x0x0x0x-x000-0000-xxxx-xxxx0000xxx00"
$authority = "https://login.microsoftonline.com/$tenantId"
$scope = "https://graph.microsoft.com/.default"

# Definir a vari�vel para o caminho base da URL 
$baseUrlPath = "Engenharia de Manuten��o/Equipamentos/Eletrica"

# Fun��o para obter o token de acesso
function Get-AccessToken {
    $body = @{
        client_id = $clientId
        scope = $scope
        client_secret = $clientSecret
        grant_type = "client_credentials"
    }
    $response = Invoke-RestMethod -Method Post -Uri "$authority/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body
    return $response.access_token
}

$accessToken = Get-AccessToken

# Configura��o do logging
$logFile = "c:\temp\migration_pasta_log.csv"
if (-Not (Test-Path $logFile)) {
    "Source;Destination;Item name;Extension;Item size (MB);Type;Status;Message;Destination item ID;Incremental round;Date;Time" | Out-File -FilePath $logFile
}

function Log-Migration {
    param (
        [string]$source,
        [string]$destination,
        [string]$itemName,
        [string]$extension,
        [double]$itemSizeMB,
        [string]$type,
        [string]$status,
        [string]$message,
        [string]$destinationItemId,
        [string]$incrementalRound,
        [string]$date = (Get-Date).ToString("dd/MM/yyyy"),
        [string]$time = (Get-Date).ToString("HH:mm:ss")
    )
    "$source;$destination;$itemName;$extension;$itemSizeMB;$type;$status;$message;$destinationItemId;$incrementalRound;$date;$time" | Out-File -FilePath $logFile -Append
}

# Fun��o para migrar arquivos com renova��o de token
function Migrate-Files {
    param (
        [string]$sourceFolder,
        [string]$destinationDrive,
        [hashtable]$filters
    )
    $headers = @{
        Authorization = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }
    # Verificar se a pasta de origem existe
    if (-Not (Test-Path $sourceFolder)) {
        Log-Migration -source $sourceFolder -destination "N/A" -itemName "N/A" -extension "N/A" -itemSizeMB 0 -type "N/A" -status "Falha" -message "Pasta de origem n�o encontrada: $sourceFolder" -destinationItemId "N/A" -incrementalRound "N/A"
        return
    }
    Write-Host "Pasta de origem encontrada: $sourceFolder"
    # Obter lista de arquivos e pastas da pasta de origem
    $items = Get-ItemsFromSource -folder $sourceFolder -filters $filters
    $totalItems = $items.Count
    $currentItem = 0
    foreach ($item in $items) {
        $currentItem++
        $progress = [math]::Round(($currentItem / $totalItems) * 100, 2)
        Write-Host "Migrando item: $($item.FullName) ($progress% completo)"
        
        try {
            # Verificar se o erro � 401 (n�o autorizado)
            if ($_.Exception.Response.StatusCode -eq 401) {
                Write-Host "Token expirado. Renovando token..."
                $accessToken = Get-AccessToken
                $headers.Authorization = "Bearer $accessToken"
                # Tentar novamente a opera��o ap�s renovar o token
                continue
            }
            if ($item.PSIsContainer) {
                # Criar pasta no destino
                Create-FolderInDrive -folder $item -driveId $destinationDrive -headers $headers
            } else {
                # Verificar se o arquivo j� existe no destino com tamanho igual ou superior
                if (-not (Test-DestinationFileExists -file $item -driveId $destinationDrive -headers $headers)) {
                    # Migrar arquivo para o SharePoint
                    $destinationItemId, $uploadUrl, $cleanedDestinationPath, $incrementalRound = Upload-FileToDrive -file $item -driveId $destinationDrive -headers $headers
                    # Ocultar as informa��es desnecess�rias do uploadUrl na coluna Destination item ID
                    # O cleanedUploadUrl agora cont�m o caminho completo de destino e nome do arquivo
                    $cleanedUploadUrl = "$baseUrlPath/$($item.FullName.Replace($sourceFolder, '').Replace('\\\\', '/'))"
                    # Ocultar as informa��es desnecess�rias do uploadUrl na coluna Destination, exibindo apenas o caminho at� a pasta
                    $cleanedDestinationPathOnly = "$baseUrlPath"
                    # Definir o tamanho do arquivo em MB antes de chamar Log-Migration
                    $fileSizeMB = [math]::Round($item.Length / 1MB, 2)
                    Log-Migration -source "$($item.DirectoryName)" -destination "$cleanedDestinationPathOnly" -itemName "$($item.Name)" `
                    -extension "$($item.Extension)" `
                    -itemSizeMB "$fileSizeMB" `
                    -type "File" `
                    -status "Sucesso" `
                    -message "Arquivo migrado com sucesso" `
                    -destinationItemId "$cleanedUploadUrl" `
                    -incrementalRound "$incrementalRound"
                } else {
                    Write-Host "Arquivo j� migrado: $($item.FullName)"
                    # Definir o tamanho do arquivo em MB antes de chamar Log-Migration
                    $fileSizeMB = [math]::Round($item.Length / 1MB, 2)
                    # O cleanedUploadUrl agora cont�m o caminho completo de destino e nome do arquivo
                    Log-Migration -source "$($item.DirectoryName)" -destination "$baseUrlPath" -itemName "$($item.Name)" `
                    -extension "$($item.Extension)" `
                    -itemSizeMB "$fileSizeMB" `
                    -type "File" `
                    -status "Pulou" `
                    -message "Arquivo j� migrado" `
                    -destinationItemId "$baseUrlPath/$($item.FullName.Replace($sourceFolder, '').Replace('\\\\', '/'))" `
                    -incrementalRound "0"
                }
            }
        } catch {
            Write-Host "Erro ao migrar item: $_"
			if ($_.Exception.Response.StatusCode -eq 401) {
                Write-Host "Token expirado. Renovando token..."
                $accessToken = Get-AccessToken
                $headers.Authorization = "Bearer $accessToken"
                # Tentar novamente a opera��o ap�s renovar o token
                continue
            }
            # Definir o tamanho do arquivo em MB antes de chamar Log-Migration
            $fileSizeMB = [math]::Round($item.Length / 1MB, 2)
            # O cleanedUploadUrl agora cont�m o caminho completo de destino e nome do arquivo
            Log-Migration -source "$($item.DirectoryName)" -destination "$baseUrlPath" -itemName "$($item.Name)" `
            -extension "$($item.Extension)" `
            -itemSizeMB "$fileSizeMB" `
            -type "File" `
            -status "Falha" `
            -message "Erro: $_" `
            -destinationItemId "$baseUrlPath/$($item.FullName.Replace($sourceFolder, '').Replace('\\\\', '/'))" `
            -incrementalRound "0"
        }
    }
}

function Test-DestinationFileExists {
    param (
        [System.IO.FileInfo]$file,
        [string]$driveId,
        [hashtable]$headers
    )
    
    # Verificar se o arquivo j� existe no destino com tamanho igual ou superior
    try {
        # Verificar se o erro � 401 (n�o autorizado)
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Host "Token expirado. Renovando token..."
            $accessToken = Get-AccessToken
            $headers.Authorization = "Bearer $accessToken"
            # Tentar novamente a opera��o ap�s renovar o token
            continue
        }
        # Verificar se o arquivo j� existe no destino
        $filePath = $file.FullName.Replace($sourceFolder, '').Replace('\\', '/')
        $checkFileUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$baseUrlPath/${filePath}"
        $response = Invoke-RestMethod -Method Get -Uri $checkFileUrl -Headers $headers -ErrorAction Stop
        $destinationFileSize = $response.size
        return $file.Length -le $destinationFileSize
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            return $false
        } else {
            throw $_
        }
    }
}

function Get-ItemsFromSource {
    param (
        [string]$folder,
        [hashtable]$filters
    )
    # Implementar l�gica para obter arquivos e pastas da pasta de origem aplicando filtros
    # Exemplo: retornar apenas arquivos que n�o sejam .dat, .exe, desktop.ini, n�o comecem com ~# e que foram modificados nos �ltimos 3 anos
    $threeYearsAgo = (Get-Date).AddYears(-3)
    return Get-ChildItem -Path $folder -Recurse | Where-Object {
        ($_.PSIsContainer) -or ($_.Extension -ne ".dat" -and $_.Extension -ne ".lnk" -and $_.Extension -ne ".exe"  -and $_.Name -notmatch "^~#" -and $_.Name -notmatch "desktop.ini" -and $_.LastWriteTime -gt $threeYearsAgo)
    }
}

# Atualizar a fun��o Create-FolderInDrive para usar a vari�vel baseUrlPath
function Create-FolderInDrive {
    param (
        [System.IO.DirectoryInfo]$folder,
        [string]$driveId,
        [hashtable]$headers
    )
    # Criar pasta no Drive
    $folderPath = $folder.FullName.Replace($sourceFolder, '').Replace('\\', '/')
    $createFolderUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$baseUrlPath${folderPath}:/children"
    $checkFolderUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$baseUrlPath${folderPath}"

    Write-Host "Verificando se a pasta j� existe no URL: $checkFolderUrl"

    try {
        # Verificar se o erro � 401 (n�o autorizado)
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Host "Token expirado. Renovando token..."
            $accessToken = Get-AccessToken
            $headers.Authorization = "Bearer $accessToken"
            # Tentar novamente a opera��o ap�s renovar o token
            continue
        }
        $response = Invoke-RestMethod -Method Get -Uri $checkFolderUrl -Headers $headers -ErrorAction Stop
        Write-Host "Pasta j� existe: $($folder.FullName)"
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "Pasta n�o encontrada, criando nova pasta no URL: $createFolderUrl"
            $body = @{
                name = $folder.Name
                folder = @{ }
                "@microsoft.graph.conflictBehavior" = "rename"
            } | ConvertTo-Json

            try {
        # Verificar se o erro � 401 (n�o autorizado)
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Host "Token expirado. Renovando token..."
            $accessToken = Get-AccessToken
            $headers.Authorization = "Bearer $accessToken"
            # Tentar novamente a opera��o ap�s renovar o token
            continue
        }
                $response = Invoke-RestMethod -Method Post -Uri $createFolderUrl -Headers $headers -Body $body -ContentType "application/json"
                if ($response -eq $null) {
                    throw "Falha na cria��o da pasta: $($folder.Name)"
                }
            } catch {
                Write-Host "Erro ao criar pasta: $_"
                throw $_
            }
        } else {
            Write-Host "Erro ao verificar pasta: $_"
            throw $_
        }
    }
}

function Upload-FileToDrive {
    param (
        [System.IO.FileInfo]$file,
        [string]$driveId,
        [hashtable]$headers
    )
    # Verificar se o arquivo � v�lido
    if (-Not $file -or -Not $file.Exists) {
        throw "Arquivo inv�lido ou n�o encontrado: $($file.FullName)"
    }

    # Verificar se o arquivo j� existe no destino
    $filePath = $file.FullName.Replace($sourceFolder, '').Replace('\\', '/')
    $checkFileUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$baseUrlPath/${filePath}"
    $uploadUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$baseUrlPath/${filePath}:/content"

    Write-Host "Verificando se o arquivo j� existe no URL: $checkFileUrl"

    try {
        # Verificar se o erro � 401 (n�o autorizado)
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Host "Token expirado. Renovando token..."
            $accessToken = Get-AccessToken
            $headers.Authorization = "Bearer $accessToken"
            # Tentar novamente a opera��o ap�s renovar o token
            continue
        }
        $response = Invoke-RestMethod -Method Get -Uri $checkFileUrl -Headers $headers -ErrorAction Stop
        $destinationFileSize = $response.size
        $destinationFileLastModified = [datetime]$response.lastModifiedDateTime

        if ($file.Length -gt $destinationFileSize -or $file.LastWriteTime -gt $destinationFileLastModified) {
            Write-Host "Arquivo no destino � menor ou mais antigo. Realizando upload para URL: $uploadUrl"
            $fileContent = Get-Content -Path $file.FullName -Raw -Encoding Byte
            $response = Invoke-RestMethod -Method Put -Uri $uploadUrl -Headers $headers -Body $fileContent
            if ($response -eq $null) {
                throw "Falha no upload do arquivo: $($file.Name)"
            }
            $cleanedUploadUrl = "$baseUrlPath/$($file.FullName.Replace($sourceFolder, '').Replace('\\', '/'))"
            $cleanedDestinationPath = "$baseUrlPath"
			$incrementalRound++
            return $response.id, $cleanedUploadUrl, $cleanedDestinationPath, $incrementalRound
        } else {
            Write-Host "Arquivo no destino � igual ou mais recente. N�o � necess�rio realizar upload."
            $cleanedUploadUrl = "$baseUrlPath/$($file.FullName.Replace($sourceFolder, '').Replace('\\', '/'))"
            $cleanedDestinationPath = "$baseUrlPath"
            Log-Migration -source $file.DirectoryName -destination $cleanedDestinationPath -itemName $file.Name -extension $file.Extension -itemSizeMB ([math]::Round($file.Length / 1MB, 2)) -type "File" -status "Pulou" -message "Arquivo j� migrado" -destinationItemId $cleanedUploadUrl -incrementalRound "0"
            return $response.id, $cleanedUploadUrl, $cleanedDestinationPath
        }
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "Arquivo n�o encontrado no destino. Realizando upload para URL: $uploadUrl"
            $fileContent = Get-Content -Path $file.FullName -Raw -Encoding Byte
            $response = Invoke-RestMethod -Method Put -Uri $uploadUrl -Headers $headers -Body $fileContent
            if ($response -eq $null) {
                throw "Falha no upload do arquivo: $($file.Name)"
            }
            $cleanedUploadUrl = "$baseUrlPath/$($file.FullName.Replace($sourceFolder, '').Replace('\\', '/'))"
            $cleanedDestinationPath = "$baseUrlPath"
            return $response.id, $cleanedUploadUrl, $cleanedDestinationPath
        } else {
            Write-Host "Erro ao verificar arquivo: $_"
            throw $_
        }
    }
}

# Exemplo de uso
$sourceFolder = "\\server01\Area\Administrativo\Reunioes\Ata"
$driveId = "x!XXX-x0x0x0x0x0x0x0ss0_xxxX0xxXxX0xXXx_Ox0X-X0H"
$filters = @{ extension = ".txt" }

Migrate-Files -sourceFolder $sourceFolder -destinationDrive $driveId -filters $filters