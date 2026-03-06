# Azurite

Azurite is the Azure Storage emulator for local development, supporting Blob, Queue, and Table storage.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `azurite` |
| **Type** | Azure Storage Emulator |
| **Default** | Disabled |
| **Config Key** | `raw_apps.azurite` |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [Azurite Documentation](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azurite)
- [Azure Storage REST API](https://learn.microsoft.com/en-us/rest/api/storageservices/)
- [Azure SDK for Python](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-python)
- [Azure SDK for .NET](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-dotnet)

## Enabling

```json
{
  "raw_apps": {
    "azurite": true
  }
}
```

## Accessing

| Service | Port | Endpoint |
|---------|------|----------|
| **Blob** | 10000 | `http://azurite.azurite.svc.cluster.local:10000` |
| **Queue** | 10001 | `http://azurite.azurite.svc.cluster.local:10001` |
| **Table** | 10002 | `http://azurite.azurite.svc.cluster.local:10002` |

## Default Credentials

```
Account Name: devstoreaccount1
Account Key: Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==
```

## Connection String

```
DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://azurite.azurite:10000/devstoreaccount1;QueueEndpoint=http://azurite.azurite:10001/devstoreaccount1;TableEndpoint=http://azurite.azurite:10002/devstoreaccount1;
```

## Usage

### Python (azure-storage-blob)

```python
from azure.storage.blob import BlobServiceClient

conn_str = "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://azurite.azurite:10000/devstoreaccount1;"

client = BlobServiceClient.from_connection_string(conn_str)

# Create container
container = client.create_container("my-container")

# Upload blob
blob = client.get_blob_client("my-container", "hello.txt")
blob.upload_blob(b"Hello Azurite!")

# Download blob
data = blob.download_blob().readall()
```

### .NET

```csharp
var connectionString = "UseDevelopmentStorage=true";
// Override endpoints for in-cluster access
var blobClient = new BlobServiceClient(connectionString);
```

### Azure CLI

```bash
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;..."

az storage container create --name my-container
az storage blob upload -c my-container -n file.txt -f ./file.txt
az storage blob list -c my-container
```

## Troubleshooting

```bash
kubectl get pods -n azurite
kubectl logs -n azurite -l app=azurite --tail=50

# Test blob endpoint
curl http://azurite.azurite:10000/devstoreaccount1?comp=list
```
