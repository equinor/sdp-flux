# Root
$originRgName = 'sdpaksVeleroBackup'

# Destination
$destSaRgName = 'temp-rg'
$destSaName = 'tempstaccgit'
$destContainerName = 'migrate'
$destDiskRgName = 'temp-rg'

$snapshotList = @(
 ('kubernetes-dynamic-pvc-66c040cf-f7bb-11e8-9-d3e09798-0e88-4771-a6c0-88b10b06c317')
)
$destList = "verdaccio-pv"

$storageAccountKey = Get-AzStorageAccountKey -resourceGroupName $destSaRgName -AccountName $destSaName
$destinationContext = New-AzStorageContext -StorageAccountName $destSaName -StorageAccountKey ($storageAccountKey).Value[0]

$rootUri = "https://tempstaccgit.blob.core.windows.net/migrate/"
$storageAccountId = "/subscriptions/b18da12e-efa1-4642-8fec-b6580b00212c/resourceGroups/$destSaRgName/providers/Microsoft.Storage/storageAccounts/$destSaName"


for  ($i = 0; $i -lt $snapshotList.Count; $i++) {
    echo "Creating Disk image: $destList ..."
    $uri = $rootUri + $destList
    $diskConfig = New-AzDiskConfig -AccountType "Standard_LRS" -Location "norwayeast" -CreateOption Import -StorageAccountId $storageAccountId -SourceUri $uri 
    New-AzDisk -Disk $diskConfig -ResourceGroupName $destDiskRgName -DiskName verdaccio-pv2
}