# Jenkins

Jenkins is an open-source automation server for building CI/CD pipelines.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `jenkins` |
| **Type** | CI/CD |
| **Default** | Disabled |
| **Config Key** | `crossplane_apps.jenkins` |
| **Dashboard** | [jenkins.localhost](https://jenkins.localhost) |
| **Deployment** | Crossplane DevApplication |


## Official Documentation

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Plugin Index](https://plugins.jenkins.io/)
- [Jenkins REST API](https://www.jenkins.io/doc/book/using/remote-access-api/)

## Enabling

```json
{
  "crossplane_apps": {
    "jenkins": true
  }
}
```

## Accessing

- **Dashboard**: [https://jenkins.localhost](https://jenkins.localhost)
- **Default credentials**: `admin` / `admin`

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Jenkins | `admin` | `admin` |

## Dependencies

- `resource:jenkins-storage` — Persistent volume for Jenkins home (`/var/jenkins_home`)

## Features

| Feature | Description |
|---------|-------------|
| **Pipeline as Code** | Jenkinsfile-based pipelines |
| **Plugin Ecosystem** | 1800+ plugins available |
| **Kubernetes Agent** | Dynamic build agents as pods |
| **Blue Ocean** | Modern UI for pipeline visualization |

## Creating a Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent {
        kubernetes {
            yaml '''
            apiVersion: v1
            kind: Pod
            spec:
              containers:
              - name: build
                image: maven:3.9-eclipse-temurin-17
                command: ['sleep', 'infinity']
            '''
        }
    }
    stages {
        stage('Build') {
            steps {
                container('build') {
                    sh 'mvn clean package'
                }
            }
        }
    }
}
```

## Integration with Harbor

Push built images to the local Harbor registry:

```groovy
stage('Push Image') {
    steps {
        sh 'docker build -t harbor.localhost/library/my-app:${BUILD_NUMBER} .'
        sh 'docker push harbor.localhost/library/my-app:${BUILD_NUMBER}'
    }
}
```

## Troubleshooting

```bash
kubectl get pods -n jenkins
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins --tail=50

# Get initial admin password (first run)
kubectl exec -n jenkins deploy/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
```
