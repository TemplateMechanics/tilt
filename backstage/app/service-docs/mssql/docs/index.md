# Microsoft SQL Server

Microsoft SQL Server (MSSQL) is a relational database management system for applications requiring SQL Server compatibility.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `mssql` |
| **Type** | Relational Database |
| **Default** | Disabled |
| **Config Key** | `raw_apps.mssql` |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [SQL Server Documentation](https://learn.microsoft.com/en-us/sql/sql-server/)
- [T-SQL Reference](https://learn.microsoft.com/en-us/sql/t-sql/language-reference)
- [sqlcmd Utility](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility)
- [SQL Server on Linux](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-overview)

## Enabling

```json
{
  "raw_apps": {
    "mssql": true
  }
}
```

## Accessing

- **In-cluster**: `mssql.mssql.svc.cluster.local:1433`
- **Port forward**: `kubectl port-forward -n mssql svc/mssql 1433:1433`

## Default Credentials

| Property | Value |
|----------|-------|
| Username | `sa` |
| Password | `YourStrong@Passw0rd` |

## Usage

### sqlcmd

```bash
kubectl exec -it -n mssql deploy/mssql -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd'

-- Create database
CREATE DATABASE mydb;
GO

-- Use database
USE mydb;
GO

-- Create table
CREATE TABLE users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) UNIQUE
);
GO

-- Insert data
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
GO

-- Query
SELECT * FROM users;
GO
```

### Python (pyodbc)

```python
import pyodbc

conn = pyodbc.connect(
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=mssql.mssql.svc.cluster.local,1433;'
    'DATABASE=master;'
    'UID=sa;'
    'PWD=YourStrong@Passw0rd'
)

cursor = conn.cursor()
cursor.execute("SELECT @@VERSION")
print(cursor.fetchone()[0])
```

### .NET

```csharp
var connectionString = "Server=mssql.mssql.svc.cluster.local,1433;Database=master;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";
using var connection = new SqlConnection(connectionString);
await connection.OpenAsync();
```

### Connection String

```
Server=mssql.mssql.svc.cluster.local,1433;Database=master;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;
```

## Notes

- Uses the official Microsoft SQL Server Linux container
- SQL Server Developer Edition (free for development)
- Supports T-SQL, stored procedures, and all SQL Server features

## Troubleshooting

```bash
kubectl get pods -n mssql
kubectl logs -n mssql -l app=mssql --tail=50

# Check if SQL Server is ready
kubectl exec -n mssql deploy/mssql -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "SELECT 1"
```
