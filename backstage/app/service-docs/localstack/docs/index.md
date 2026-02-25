# LocalStack

LocalStack provides a fully functional local cloud stack emulating AWS services for development and testing.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `localstack` |
| **Type** | AWS Emulator |
| **Default** | Disabled |
| **Config Key** | `crossplane_apps.localstack` |
| **Dashboard** | [localstack.localhost](https://localstack.localhost) |
| **Deployment** | Crossplane DevApplication |


## Official Documentation

- [LocalStack Documentation](https://docs.localstack.cloud/overview/)
- [AWS Service Coverage](https://docs.localstack.cloud/references/coverage/)
- [LocalStack CLI](https://docs.localstack.cloud/getting-started/installation/)
- [Configuration Reference](https://docs.localstack.cloud/references/configuration/)

## Enabling

```json
{
  "crossplane_apps": {
    "localstack": true
  }
}
```

## Accessing

- **Dashboard**: [https://localstack.localhost](https://localstack.localhost)
- **API endpoint**: `http://localstack.localstack.svc.cluster.local:4566`

## Supported Services

| AWS Service | LocalStack Endpoint |
|-------------|-------------------|
| **S3** | `http://localstack.localstack:4566` |
| **SQS** | `http://localstack.localstack:4566` |
| **SNS** | `http://localstack.localstack:4566` |
| **DynamoDB** | `http://localstack.localstack:4566` |
| **Lambda** | `http://localstack.localstack:4566` |
| **IAM** | `http://localstack.localstack:4566` |
| **CloudFormation** | `http://localstack.localstack:4566` |
| **Secrets Manager** | `http://localstack.localstack:4566` |

## Usage

### AWS CLI

```bash
# Configure AWS CLI to use LocalStack
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Create an S3 bucket
aws --endpoint-url=$AWS_ENDPOINT_URL s3 mb s3://my-bucket

# Create an SQS queue
aws --endpoint-url=$AWS_ENDPOINT_URL sqs create-queue --queue-name my-queue

# Put item in DynamoDB
aws --endpoint-url=$AWS_ENDPOINT_URL dynamodb create-table \
  --table-name MyTable \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Python (boto3)

```python
import boto3

s3 = boto3.client('s3',
    endpoint_url='http://localstack.localstack:4566',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

s3.create_bucket(Bucket='my-bucket')
s3.put_object(Bucket='my-bucket', Key='hello.txt', Body=b'Hello World')
```

### Node.js

```javascript
const { S3Client, CreateBucketCommand } = require('@aws-sdk/client-s3');

const client = new S3Client({
  endpoint: 'http://localstack.localstack:4566',
  region: 'us-east-1',
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' },
  forcePathStyle: true,
});

await client.send(new CreateBucketCommand({ Bucket: 'my-bucket' }));
```

## Notes

- Default credentials: Access Key `test`, Secret Key `test`
- Data is ephemeral (lost on restart)
- All services share port 4566 (multiplexed by service headers)

## Troubleshooting

```bash
kubectl get pods -n localstack
kubectl logs -n localstack -l app.kubernetes.io/name=localstack --tail=50

# Check service health
curl http://localstack.localstack:4566/_localstack/health | jq .
```
