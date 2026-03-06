# PostgreSQL

PostgreSQL is the open-source relational database deployed as a standalone instance for application development.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `postgresql` |
| **Type** | Relational Database |
| **Default** | Disabled |
| **Config Key** | `raw_apps.postgresql` |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [PostgreSQL Documentation](https://www.postgresql.org/docs/current/)
- [SQL Reference](https://www.postgresql.org/docs/current/sql.html)
- [psql CLI Reference](https://www.postgresql.org/docs/current/app-psql.html)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)

## Enabling

```json
{
  "raw_apps": {
    "postgresql": true
  }
}
```

## Accessing

- **In-cluster**: `postgresql.postgresql.svc.cluster.local:5432`
- **Port forward**: `kubectl port-forward -n postgresql svc/postgresql 5432:5432`

## Default Credentials

| Property | Value |
|----------|-------|
| Username | `postgres` |
| Password | `postgres` |
| Database | `postgres` |

## Usage

### psql

```bash
kubectl exec -it -n postgresql deploy/postgresql -- psql -U postgres

-- Create a table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert data
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');

-- Query
SELECT * FROM users;
```

### Python (psycopg2)

```python
import psycopg2

conn = psycopg2.connect(
    host="postgresql.postgresql.svc.cluster.local",
    port=5432,
    database="postgres",
    user="postgres",
    password="postgres"
)

cur = conn.cursor()
cur.execute("SELECT version()")
print(cur.fetchone())
conn.close()
```

### Node.js (pg)

```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'postgresql.postgresql',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'postgres',
});

await client.connect();
const res = await client.query('SELECT NOW()');
console.log(res.rows[0]);
await client.end();
```

### Connection String

```
postgresql://postgres:postgres@postgresql.postgresql.svc.cluster.local:5432/postgres
```

## Notes

This is the **standalone** PostgreSQL instance. Several other services deploy their own PostgreSQL instances:

- Airflow (`airflow` namespace)
- Backstage (`backstage` namespace)
- Harbor (`harbor` namespace)
- Keycloak (`keycloak` namespace)
- Langfuse (`langfuse` namespace)

## Troubleshooting

```bash
kubectl get pods -n postgresql
kubectl logs -n postgresql -l app=postgresql --tail=50

# Check connectivity
kubectl exec -n postgresql deploy/postgresql -- pg_isready -U postgres
```
