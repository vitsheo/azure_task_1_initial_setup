$ErrorActionPreference = "Stop"

Import-Module Az.Accounts
Import-Module Az.Resources
Import-Module Az.Storage

$context = Get-AzContext -ErrorAction SilentlyContinue

if (-not $context -or -not $context.Subscription.Id) {
    throw "Azure subscription unavailable. Setup is prepared but cannot create cloud resources yet."
}

$rgName = "mate-resources"
$location = "westeurope"
$containerName = "task-artifacts"

Write-Host "Checking resource group..."

$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue

if (-not $rg) {
    $rg = New-AzResourceGroup `
        -Name $rgName `
        -Location $location
}

Write-Host "Checking storage account..."

$storage = Get-AzStorageAccount -ResourceGroupName $rgName |
    Where-Object { $_.Sku.Name -eq "Standard_LRS" } |
    Select-Object -First 1

if (-not $storage) {
    $name = "mateart" + [guid]::NewGuid().ToString("N").Substring(0,12)

    $storage = New-AzStorageAccount `
        -ResourceGroupName $rgName `
        -Name $name `
        -Location $location `
        -SkuName Standard_LRS `
        -Kind StorageV2
}

Write-Host "Checking artifact container..."

$container = Get-AzStorageContainer `
    -Name $containerName `
    -Context $storage.Context `
    -ErrorAction SilentlyContinue

if (-not $container) {
    New-AzStorageContainer `
        -Name $containerName `
        -Context $storage.Context `
        -Permission Off | Out-Null
}

Write-Host "Generating artifacts..."

& "$PSScriptRoot/generate-artifacts.ps1" `
    -ArtifactsStorageAccountName $storage.StorageAccountName

Write-Host "Validating artifacts..."

& "$PSScriptRoot/validate-artifacts.ps1"

Write-Host "Azure Lab Setup completed." -ForegroundColor Green
