# SharePoint Deep Migration Script (.ps1)

Este script PowerShell realiza a migração de arquivos de um File Server para uma biblioteca do SharePoint Online utilizando a API Microsoft Graph. Diferente da ferramenta oficial SPMT da Microsoft, este script permite a navegação e migração de arquivos em **níveis profundos de pastas**, superando a limitação padrão de apenas dois níveis.

## Funcionalidades

- Autenticação via Microsoft Graph (Client Credentials)
- Criação de pastas no destino conforme a estrutura original
- Upload de arquivos com verificação de duplicidade e tamanho
- Registro detalhado de logs em CSV
- Suporte a filtros por extensão e data de modificação
- Renovação automática de token em caso de expiração

## Pré-requisitos

- Azure App Registration com permissões para Microsoft Graph
- PowerShell 5.1+
- Permissões de leitura no File Server e gravação no SharePoint

## Entradas do Usuário

No início do script, você deve preencher os seguintes campos:

```powershell
# Substitua com os valores da sua aplicação registrada no Azure
$clientId = "<Seu Client ID>"         # Veja como obter: https://learn.microsoft.com/en-us/graph/auth-register-app-v2
$clientSecret = "<Seu Secret ID>"     # Veja como gerar: https://learn.microsoft.com/en-us/graph/auth-register-app-v2#configure-application-secrets
$tenantId = "<Seu Tenant ID>"         # Veja como encontrar: https://learn.microsoft.com/en-us/microsoft-365/admin/setup/find-your-office-365-tenant-id
$baseUrlPath = "<caminho da pasta destino no SharePoint>"

# Além disso, no final do script, modifique os valores de acordo com o seu cenário:

$sourceFolder = "\\server\\caminho_da_pasta\subpastas\" #Informe o caminho da pasta em seu Servidor de Arquivos
$driveId = "<ID do drive do SharePoint>"  # Veja como obter: https://learn.microsoft.com/en-us/graph/api/resources/drive?view=graph-rest-1.0
