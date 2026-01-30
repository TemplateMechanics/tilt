# Docker-eyeOS - iOS/iPadOS on Kubernetes - EXPERIMENTAL

⚠️ **WARNING: Highly experimental! More limited than full macOS setup.**

## What is Docker-eyeOS?

Docker-eyeOS by sickcodes runs **actual iOS and iPadOS** in containers, not just the simulator. This is different from the full macOS approach and has unique use cases.

**GitHub**: https://github.com/sickcodes/Docker-eyeOS

## Key Differences from macOS/iOS Setup

| Feature | Docker-eyeOS | macOS + Xcode |
|---------|--------------|---------------|
| **What it runs** | iOS/iPadOS directly | Full macOS with Xcode |
| **Xcode support** | ❌ No | ✅ Yes |
| **iOS Simulator** | ❌ No (runs real iOS) | ✅ Yes |
| **App Testing** | ✅ Real iOS environment | ⚠️ Simulator only |
| **Resources** | Lower (4GB RAM) | Higher (12-24GB RAM) |
| **Boot time** | Faster (~10-20 min) | Slower (~45-90 min) |
| **App Development** | Limited | Full IDE |
| **UI Testing** | ✅ Excellent | ✅ Good |
| **Storage needed** | 64GB | 120GB+ |

## Use Cases

**Good For:**
- ✅ Testing iOS apps in real iOS environment
- ✅ UI/UX testing and screenshots
- ✅ App behavior validation
- ✅ iOS automation testing (Appium, XCUITest)
- ✅ Web testing in Safari Mobile
- ✅ API testing from iOS
- ✅ Learning iOS features
- ✅ Jailbreak research (optional)

**Not Good For:**
- ❌ Building iOS apps from source (no Xcode)
- ❌ Full iOS development workflow
- ❌ App Store deployment
- ❌ Physical device features (camera, GPS, etc.)

## Prerequisites

Same as macOS setup:
- Linux host with KVM (`/dev/kvm`)
- Privileged container support
- 4+ CPU cores, 4-8GB RAM
- 64GB storage

## Configuration

### Device Models Available

Edit `statefulset.yaml` to choose device:

**iPhones:**
```yaml
DEVICE_TYPE: "iphone"
DEVICE_MODEL: "iPhone15,2"  # iPhone 14 Pro
# Other options:
# iPhone14,2 - iPhone 13 Pro
# iPhone13,2 - iPhone 12 Pro
# iPhone12,1 - iPhone 11
```

**iPads:**
```yaml
DEVICE_TYPE: "ipad"
DEVICE_MODEL: "iPad13,1"  # iPad Pro 11" (2021)
# Other options:
# iPad8,1 - iPad Pro 11" (2018)
# iPad11,1 - iPad mini (6th gen)
```

### iOS Versions

```yaml
VERSION: "17"  # iOS 17 (latest)
# VERSION: "16"  # iOS 16
# VERSION: "15"  # iOS 15
```

### Resolution Settings

**iPhone 14 Pro:**
```yaml
WIDTH: "1170"
HEIGHT: "2532"
```

**iPad Pro 11":**
```yaml
WIDTH: "1668"
HEIGHT: "2388"
```

**iPhone SE:**
```yaml
WIDTH: "750"
HEIGHT: "1334"
```

## Deployment

1. Verify KVM: `ls /dev/kvm`
2. Uncomment in Tiltfile: `k8s_kustomize("./helm/eyeos/", "eyeos", generate_link=True)`
3. Run: `tilt up`
4. Wait 10-20 minutes for iOS to boot

## Access Methods

### Web VNC (Easiest)
```
http://eyeos.localhost
```

### Native VNC Client (Better)
```bash
# macOS
open vnc://eyeos.localhost:5900

# Linux
vncviewer eyeos.localhost:5900
# Password: changeme
```

### SSH Access
```bash
ssh root@eyeos.localhost -p 2222
# Password: alpine
```

### File Transfer (WebDAV)
```
http://eyeos.localhost:8080
```

## Using iOS/iPadOS

### Installing Apps

**Option 1: App Store** (if not jailbroken)
- Sign in with Apple ID
- Download apps normally
- Limited to App Store apps

**Option 2: IPA Files** (requires jailbreak or development certificate)
```bash
# SSH into the container
ssh root@eyeos.localhost -p 2222

# Upload IPA
scp -P 2222 MyApp.ipa root@eyeos.localhost:/var/root/

# Install with ipa-install (if jailbroken)
ipa-install MyApp.ipa
```

**Option 3: TestFlight** (requires Apple Developer account)
- Sign in with developer Apple ID
- Access TestFlight builds
- Install beta apps

### Testing Web Apps

1. Open Safari via VNC
2. Navigate to your web app
3. Test iOS-specific features:
   - Touch gestures
   - Safari quirks
   - PWA installation
   - Mobile viewport

### Automation Testing

**With Appium:**
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
# Run your tests
driver.quit()
```

### Screenshots and Screen Recording

**Via VNC:**
- Use your VNC client's screenshot feature

**Via SSH:**
```bash
ssh root@eyeos.localhost -p 2222
# Take screenshot (if jailbroken with appropriate tools)
screencap /tmp/screenshot.png
```

### Jailbreak Mode (Optional)

Enable jailbreak for advanced testing:

```yaml
env:
  - name: JAILBREAK
    value: "true"
```

**Benefits:**
- Install IPA files directly
- Access filesystem
- Install tweaks for testing
- SSH with full root access
- Install debugging tools

**Risks:**
- Less stable
- May break App Store apps
- Security implications

## iOS Development Workflow

Since you can't develop IN eyeOS, use this workflow:

```
┌─────────────────┐
│  Develop on Mac │──► Build IPA
│  or with GitHub │
│  Actions        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Upload to      │
│  TestFlight or  │
│  Direct Install │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Test in        │──► Screenshots
│  Docker-eyeOS   │──► Bug reports
│                 │──► Validation
└─────────────────┘
```

## Multiple iOS Versions Testing

Run multiple versions simultaneously:

```bash
# iOS 17
k8s_kustomize("./helm/eyeos/", "eyeos-ios17", generate_link=True)

# Copy helm/eyeos to helm/eyeos-ios16 and modify:
# - VERSION: "16"
# - Change ports and ingress host
k8s_kustomize("./helm/eyeos-ios16/", "eyeos-ios16", generate_link=True)
```

## Troubleshooting

**iOS won't boot:**
```bash
# Check KVM
kubectl exec -it eyeos-0 -n eyeos -- ls -la /dev/kvm

# Check logs
kubectl logs eyeos-0 -n eyeos --tail=100

# Common issue: Insufficient RAM
# Solution: Increase RAM in statefulset.yaml
```

**Touch input not working:**
- Use native VNC client instead of web
- Enable "send pointer events" in VNC settings
- Some VNC clients don't support touch well

**Apps crash on launch:**
- Increase RAM allocation
- Check iOS version compatibility
- Some apps detect virtualization

**Can't install apps:**
- Need Apple ID for App Store
- Need jailbreak for IPA files
- Use TestFlight for beta apps

## Performance Tips

1. **Allocate enough RAM**: 4GB minimum, 8GB recommended
2. **Use SSD storage**: iOS is storage-intensive
3. **Dedicated CPU cores**: Don't overcommit
4. **Native VNC client**: Web VNC has lag
5. **Limit background apps**: Close what you don't need

## Security Considerations

⚠️ **Important:**
- Runs as privileged container
- Has full system access via KVM
- Jailbreak mode is less secure
- Don't use production credentials
- Isolate network if testing malware

## Comparison with Alternatives

**Docker-eyeOS vs:**

**Physical iOS Device:**
- ✅ Easier automation
- ✅ Disposable/reproducible
- ❌ Missing hardware features
- ❌ Performance not identical

**iOS Simulator (Xcode):**
- ✅ Real iOS, not simulator
- ✅ More accurate app behavior
- ❌ Can't build apps
- ❌ More resource intensive

**BrowserStack/Sauce Labs:**
- ✅ Self-hosted
- ✅ No usage fees
- ❌ More setup complexity
- ❌ Requires maintenance

## Known Limitations

- ❌ No native GPU acceleration
- ❌ No actual camera/sensors
- ❌ Can't connect to physical accessories
- ❌ Some apps detect virtualization
- ❌ App Store publishing requires real device
- ⚠️ Slower than native iOS
- ⚠️ Legal/licensing questions with Apple

## Cost Estimation

**Per eyeOS Instance:**
- **CPU**: 4 cores
- **RAM**: 4-8GB
- **Storage**: 64GB
- **Boot Time**: 10-20 minutes
- **Multiple instances**: More feasible than full macOS

**You could run 3-4 eyeOS instances** with the resources needed for one full macOS+Xcode environment.

## Recommended Use

**Best Use Case**: Automated testing farm
- Run iOS 15, 16, and 17 in parallel
- Test your app on multiple iOS versions
- Capture screenshots automatically
- Validate UI across versions
- Much cheaper than device lab

## Resources

- **GitHub**: https://github.com/sickcodes/Docker-eyeOS
- **Docker Hub**: https://hub.docker.com/r/sickcodes/docker-eyeos
- **sickcodes Projects**: https://github.com/sickcodes
- **iOS Automation**: https://appium.io/docs/en/drivers/ios-xcuitest/
