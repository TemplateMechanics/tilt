# Redis

Redis is an in-memory data structure store used as a database, cache, message broker, and streaming engine.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `redis` |
| **Type** | In-Memory Database / Cache |
| **Default** | Disabled |
| **Config Key** | `raw_apps.redis` |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [Redis Documentation](https://redis.io/docs/latest/)
- [Redis Commands](https://redis.io/docs/latest/commands/)
- [Redis CLI](https://redis.io/docs/latest/develop/tools/cli/)
- [Data Types](https://redis.io/docs/latest/develop/data-types/)

## Enabling

```json
{
  "raw_apps": {
    "redis": true
  }
}
```

## Accessing

- **In-cluster**: `redis.redis.svc.cluster.local:6379`
- **Port forward**: `kubectl port-forward -n redis svc/redis 6379:6379`

## Usage

### redis-cli

```bash
kubectl exec -it -n redis deploy/redis -- redis-cli

SET mykey "Hello Redis"
GET mykey
INCR counter
LPUSH mylist "item1" "item2"
LRANGE mylist 0 -1
```

### Python

```python
import redis

r = redis.Redis(host="redis.redis.svc.cluster.local", port=6379)

r.set("mykey", "Hello Redis")
print(r.get("mykey"))

# Pub/Sub
pubsub = r.pubsub()
pubsub.subscribe("events")
r.publish("events", "user_created")
```

### Node.js

```javascript
const Redis = require('ioredis');
const redis = new Redis({ host: 'redis.redis', port: 6379 });

await redis.set('mykey', 'Hello Redis');
const value = await redis.get('mykey');
console.log(value);
```

## Common Patterns

### Caching

```python
import json

def get_user(user_id):
    cached = r.get(f"user:{user_id}")
    if cached:
        return json.loads(cached)
    user = db.query(f"SELECT * FROM users WHERE id = {user_id}")
    r.setex(f"user:{user_id}", 300, json.dumps(user))  # Cache 5 min
    return user
```

### Rate Limiting

```python
def rate_limit(client_ip, max_requests=100, window=60):
    key = f"rate:{client_ip}"
    current = r.incr(key)
    if current == 1:
        r.expire(key, window)
    return current <= max_requests
```

## Notes

This is the **standalone** Redis instance. Airflow and Harbor deploy their own Redis instances in their respective namespaces.

## Troubleshooting

```bash
kubectl get pods -n redis
kubectl logs -n redis -l app=redis --tail=50

# Check connectivity
kubectl exec -n redis deploy/redis -- redis-cli ping
# Output: PONG
```
