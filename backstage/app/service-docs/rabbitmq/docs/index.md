# RabbitMQ

RabbitMQ is a reliable open-source message broker supporting AMQP, MQTT, and STOMP protocols.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `rabbitmq` |
| **Type** | Message Broker |
| **Default** | Disabled |
| **Config Key** | `raw_apps.rabbitmq` |
| **Management UI** | [rabbitmq.localhost](https://rabbitmq.localhost) |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [RabbitMQ Documentation](https://www.rabbitmq.com/docs)
- [Management HTTP API](https://www.rabbitmq.com/docs/management#http-api)
- [AMQP Concepts](https://www.rabbitmq.com/tutorials/amqp-concepts)
- [Client Libraries](https://www.rabbitmq.com/client-libraries/devtools)

## Enabling

```json
{
  "raw_apps": {
    "rabbitmq": true
  }
}
```

## Accessing

- **Management UI**: [https://rabbitmq.localhost](https://rabbitmq.localhost)
- **AMQP**: `rabbitmq.rabbitmq.svc.cluster.local:5672`
- **Management API**: `rabbitmq.rabbitmq.svc.cluster.local:15672`

## Default Credentials

| Property | Value |
|----------|-------|
| Username | `guest` |
| Password | `guest` |

## Usage

### Python (pika)

```python
import pika

connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='rabbitmq.rabbitmq',
        credentials=pika.PlainCredentials('guest', 'guest')
    )
)
channel = connection.channel()

# Declare a queue
channel.queue_declare(queue='tasks')

# Publish a message
channel.basic_publish(exchange='', routing_key='tasks', body='Hello RabbitMQ!')

# Consume messages
def callback(ch, method, properties, body):
    print(f"Received: {body}")

channel.basic_consume(queue='tasks', on_message_callback=callback, auto_ack=True)
channel.start_consuming()
```

### Node.js (amqplib)

```javascript
const amqp = require('amqplib');

const conn = await amqp.connect('amqp://guest:guest@rabbitmq.rabbitmq:5672');
const channel = await conn.createChannel();

await channel.assertQueue('tasks');
channel.sendToQueue('tasks', Buffer.from('Hello RabbitMQ!'));

channel.consume('tasks', (msg) => {
  console.log(`Received: ${msg.content.toString()}`);
  channel.ack(msg);
});
```

### Management API

```bash
# List queues
curl -u guest:guest http://rabbitmq.rabbitmq:15672/api/queues | jq '.[].name'

# List exchanges
curl -u guest:guest http://rabbitmq.rabbitmq:15672/api/exchanges | jq '.[].name'

# Publish a message via API
curl -u guest:guest -X POST http://rabbitmq.rabbitmq:15672/api/exchanges/%2f/amq.default/publish \
  -H "Content-Type: application/json" \
  -d '{"properties":{},"routing_key":"tasks","payload":"Hello","payload_encoding":"string"}'
```

## Troubleshooting

```bash
kubectl get pods -n rabbitmq
kubectl logs -n rabbitmq -l app=rabbitmq --tail=50

# Check queue status
kubectl exec -n rabbitmq deploy/rabbitmq -- rabbitmqctl list_queues
kubectl exec -n rabbitmq deploy/rabbitmq -- rabbitmqctl status
```
