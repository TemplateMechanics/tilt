# MailHog

MailHog is an email testing tool that captures outgoing email in a web-based UI, perfect for testing notifications without sending real emails.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `mailhog` |
| **Type** | Email Testing |
| **Default** | Disabled |
| **Config Key** | `raw_apps.mailhog` |
| **UI** | [mailhog.localhost](https://mailhog.localhost) |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [MailHog GitHub](https://github.com/mailhog/MailHog)
- [MailHog Configuration](https://github.com/mailhog/MailHog/blob/master/docs/CONFIG.md)
- [MailHog API v2](https://github.com/mailhog/MailHog/blob/master/docs/APIv2/swagger-2.0.yaml)
- [mhsendmail Utility](https://github.com/mailhog/mhsendmail)

## Enabling

```json
{
  "raw_apps": {
    "mailhog": true
  }
}
```

## Accessing

- **Web UI**: [https://mailhog.localhost](https://mailhog.localhost)
- **SMTP**: `mailhog.mailhog.svc.cluster.local:1025`
- **API**: `mailhog.mailhog.svc.cluster.local:8025/api/v2/messages`

## Usage

### Configure Your App

Point your application's SMTP settings to MailHog:

```yaml
SMTP_HOST: mailhog.mailhog.svc.cluster.local
SMTP_PORT: 1025
SMTP_TLS: false
SMTP_AUTH: false
```

### Python Example

```python
import smtplib
from email.mime.text import MIMEText

msg = MIMEText("Hello from the dev platform!")
msg["Subject"] = "Test Email"
msg["From"] = "app@example.com"
msg["To"] = "user@example.com"

with smtplib.SMTP("mailhog.mailhog", 1025) as server:
    server.send_message(msg)
```

### Node.js Example

```javascript
const nodemailer = require('nodemailer');

const transport = nodemailer.createTransport({
  host: 'mailhog.mailhog',
  port: 1025,
});

await transport.sendMail({
  from: 'app@example.com',
  to: 'user@example.com',
  subject: 'Test',
  text: 'Hello from the dev platform!'
});
```

### API Queries

```bash
# List all messages
curl http://mailhog.mailhog:8025/api/v2/messages

# Search messages
curl "http://mailhog.mailhog:8025/api/v2/search?kind=to&query=user@example.com"

# Delete all messages
curl -X DELETE http://mailhog.mailhog:8025/api/v1/messages
```

## Troubleshooting

```bash
kubectl get pods -n mailhog
kubectl logs -n mailhog -l app=mailhog --tail=50
```
