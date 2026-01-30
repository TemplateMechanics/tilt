The following added to a service deploy .yaml file will allow pulling secrets from 1password:

```
volumeMounts:
  enabled: true
  items:
    - name: app-data
      mountPath: "/app/app-data"
      readOnly: true

# Volumes Configuration
volumes:
  enabled: true
  items:
    - name: app-data
      secret:
        secretName: app-data-secret
```