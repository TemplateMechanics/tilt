The following added to a service deploy .yaml file will allow pulling secrets from 1password:

```
volumeMounts:
  enabled: true
  items:
    - name: rh-data
      mountPath: "/app/rh-data"
      readOnly: true

# Volumes Configuration
volumes:
  enabled: true
  items:
    - name: rh-data
      secret:
        secretName: rh-cc
```