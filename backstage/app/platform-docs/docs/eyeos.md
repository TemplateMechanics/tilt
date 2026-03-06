# iOS / eyeOS on Kubernetes — EXPERIMENTAL

!!! warning
    Highly experimental. Requires Linux host with KVM. More limited than the full macOS setup.

## What is Docker-eyeOS?

Docker-eyeOS by sickcodes runs **actual iOS and iPadOS** in containers — not just the simulator.

**GitHub**: [sickcodes/Docker-eyeOS](https://github.com/sickcodes/Docker-eyeOS)

## Comparison with macOS + Xcode

| Feature | Docker-eyeOS | macOS + Xcode |
|---------|--------------|---------------|
| What it runs | iOS/iPadOS directly | Full macOS with Xcode |
| Xcode support | ❌ | ✅ |
| iOS Simulator | ❌ (runs real iOS) | ✅ |
| App testing | ✅ Real iOS environment | ⚠️ Simulator only |
| Resources | Lower (4GB RAM) | Higher (12–24GB RAM) |
| Boot time | ~10–20 min | ~45–90 min |
| App development | Limited | Full IDE |
| Storage needed | 64GB | 120GB+ |

## Use Cases

**Good for:**

- Testing iOS apps in a real iOS environment
- UI/UX testing and screenshots
- Automation testing (Appium, XCUITest)
- Web testing in Safari Mobile

**Not good for:**

- Building iOS apps from source (no Xcode)
- App Store deployment
- Physical device features (camera, GPS)

## Prerequisites

- Linux host with KVM (`/dev/kvm`)
- 4+ CPU cores, 4–8GB RAM
- 64GB storage

## Device Configuration

### iPhones

```yaml
DEVICE_TYPE: "iphone"
DEVICE_MODEL: "iPhone15,2"  # iPhone 14 Pro
# iPhone14,2 - iPhone 13 Pro
# iPhone13,2 - iPhone 12 Pro
# iPhone12,1 - iPhone 11
```

### iPads

```yaml
DEVICE_TYPE: "ipad"
DEVICE_MODEL: "iPad13,1"  # iPad Pro 11" (2021)
# iPad8,1 - iPad Pro 11" (2018)
# iPad11,1 - iPad mini (6th gen)
```

### iOS Versions

```yaml
VERSION: "17"  # iOS 17 (latest)
# VERSION: "16"
# VERSION: "15"
```

## Access

| Method | Address |
|--------|---------|
| Web VNC | `http://eyeos.localhost` |
| Native VNC | `vnc://eyeos.localhost:5900` (password: `changeme`) |
| SSH | `ssh root@eyeos.localhost -p 2222` (password: `alpine`) |
| WebDAV | `http://eyeos.localhost:8080` |

## Automation with Appium

```python
from appium import webdriver

caps = {
    'platformName': 'iOS',
    'platformVersion': '17',
    'deviceName': 'iPhone',
    'automationName': 'XCUITest',
    'udid': 'eyeos.localhost:9221'
}

driver = webdriver.Remote('http://eyeos.localhost:9221', caps)
driver.quit()
```

## Jailbreak Mode

Enable for advanced testing:

```yaml
env:
  - name: JAILBREAK
    value: "true"
```

Benefits: direct IPA installation, filesystem access, SSH with full root, debugging tools.

## Multi-Version Testing

Run multiple iOS versions in parallel by duplicating the helm directory:

```bash
# iOS 17 — helm/eyeos/
# iOS 16 — copy to helm/eyeos-ios16/ and change VERSION + ports
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| iOS won't boot | Check KVM: `kubectl exec -it eyeos-0 -n eyeos -- ls -la /dev/kvm` |
| Touch not working | Use native VNC client instead of web |
| Apps crash | Increase RAM, check iOS version compatibility |
| Can't install apps | Need Apple ID for App Store, or jailbreak for IPA files |

## Performance Tips

1. Allocate 4GB+ RAM
2. Use SSD storage
3. Dedicate CPU cores
4. Use native VNC client (web has lag)
5. Close background apps in iOS

## Cost per Instance

- **CPU**: 4 cores
- **RAM**: 4–8GB
- **Storage**: 64GB
- **Boot time**: 10–20 minutes
- You can run **3–4 eyeOS instances** with the resources needed for one full macOS+Xcode environment

## Resources

- [Docker-eyeOS GitHub](https://github.com/sickcodes/Docker-eyeOS)
- [sickcodes Projects](https://github.com/sickcodes)
- [Appium iOS docs](https://appium.io/docs/en/drivers/ios-xcuitest/)
