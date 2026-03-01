# TapTap

A pure signal-processing tap detector for Apple Watch (and iOS).  
No machine learning — just IMU filtering, peak detection, and a minimal state machine.

## Events

### Tap Events

| Event | Description |
|-------|-------------|
| `singleTap` | One distinct tap on a surface |
| `doubleTap` | Two taps within a configurable time window |
| `longTap` | A tap followed by sustained low-motion hold |

### Swipe Events

| Event | Description |
|-------|-------------|
| `swipeLeft` | Horizontal swipe toward the left |
| `swipeRight` | Horizontal swipe toward the right |
| `swipeUp` | Vertical swipe upward |
| `swipeDown` | Vertical swipe downward |

## How It Works

### Tap Detection

```
IMU stream → magnitude → peak detection → lockout → state machine → events
```

1. **Magnitude** — `√(x² + y² + z²)` of user acceleration (gravity removed).
2. **Peak detection** — magnitude exceeds a configurable threshold (default 0.5g).
3. **Lockout** — ignores ringing oscillations for ~120 ms after a peak.
4. **State machine** — classifies peaks into single, double, or long taps.

### Swipe Detection

```
IMU stream → axis activation → velocity integration → direction classification → events
```

1. **Activation** — any single axis exceeds a configurable threshold (default 0.4g).
2. **Tracking** — integrates per-axis acceleration into velocity using the trapezoidal rule.
3. **Completion** — triggered by deceleration (sign change) or timeout.
4. **Classification** — dominant axis determines direction; rejects diagonal and z-axis motion.

## Quick Start

Add TapTap as a Swift Package dependency:

```swift
.package(url: "https://github.com/StephanoGit/tap-tap.git", from: "0.1.0")
```

Then use it with CoreMotion:

```swift
import TapTap
import CoreMotion

let tapDetector = TapDetector()
tapDetector.onTap = { event in
    switch event {
    case .singleTap:  print("tap")
    case .doubleTap:  print("double tap")
    case .longTap:    print("long tap")
    }
}

let swipeDetector = SwipeDetector()
swipeDetector.onSwipe = { event in
    switch event {
    case .swipe(.left):   print("swipe left")
    case .swipe(.right):  print("swipe right")
    case .swipe(.up):     print("swipe up")
    case .swipe(.down):   print("swipe down")
    }
}

// Feed samples from CMMotionManager.deviceMotionUpdates
tapDetector.processSample(
    x: motion.userAcceleration.x,
    y: motion.userAcceleration.y,
    z: motion.userAcceleration.z,
    timestamp: motion.timestamp
)
swipeDetector.processSample(
    x: motion.userAcceleration.x,
    y: motion.userAcceleration.y,
    z: motion.userAcceleration.z,
    timestamp: motion.timestamp
)
```

## Configuration

### Tap Detector

```swift
let config = TapDetectorConfig(
    threshold: 0.5,            // magnitude in g
    lockoutInterval: 0.120,    // seconds
    doubleTapWindow: 0.350,    // seconds
    longTapHoldDuration: 0.500,// seconds
    longTapVarianceThreshold: 0.05
)
let tapDetector = TapDetector(config: config)
```

### Swipe Detector

```swift
let config = SwipeDetectorConfig(
    activationThreshold: 0.4,  // single-axis acceleration in g
    maxSwipeDuration: 0.500,   // seconds
    axisRatio: 1.5,            // dominant vs secondary axis ratio
    minDisplacement: 0.06,     // minimum integrated velocity
    cooldown: 0.300            // seconds between swipes
)
let swipeDetector = SwipeDetector(config: config)
```

## URL Scheme — Receiving Replies

TapTap includes a `ReplyManager` for handling incoming `taptap://replies` URLs. This lets an external app or webpage send reply data to your app via a custom URL scheme.

### URL Format

```
taptap://replies?r1=First+Reply&r2=Second+Reply&r3=Third+Reply
```

### Setup

1. Register `taptap` as a URL scheme in your iPhone app target's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>taptap</string>
        </array>
    </dict>
</array>
```

2. Handle incoming URLs in your SwiftUI app entry point:

```swift
import SwiftUI
import TapTap

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    ReplyManager.shared.handleURL(url)
                }
        }
    }
}
```

3. Access the parsed replies anywhere in your app:

```swift
let replies = ReplyManager.shared.replies
// e.g. ["First Reply", "Second Reply", "Third Reply"]
```

The `r1`, `r2`, `r3` query parameter values are stored in order. Missing or empty parameters are skipped.

## Running on Apple Watch Series 7

### Prerequisites

- **Mac** with **Xcode 15** or later
- **Apple Watch Series 7** paired with an iPhone, both signed into the same Apple ID
- **Apple Developer account** (free or paid) — required to deploy to a physical device
- Watch running **watchOS 8** or later (Series 7 ships with watchOS 8+)

### Step 1 — Create a watchOS App in Xcode

1. Open Xcode → **File → New → Project**
2. Select the **watchOS** tab → **App** → **Next**
3. Enter a product name (e.g. `TapTapDemo`), set the interface to **SwiftUI**, and lifecycle to **SwiftUI App**
4. Make sure the **Bundle Identifier** uses your team prefix (e.g. `com.yourname.TapTapDemo`)
5. Click **Create**

### Step 2 — Add TapTap as a Package Dependency

1. In Xcode, select your project in the navigator
2. Go to **Package Dependencies** tab → click **+**
3. Enter the repository URL:
   ```
   https://github.com/StephanoGit/tap-tap.git
   ```
4. Set the dependency rule (e.g. **Branch → main** or **Up to Next Major Version**)
5. Click **Add Package**, then add the `TapTap` library to your watch app target

### Step 3 — Add Motion Usage Description

Add a motion usage description to your watch app's `Info.plist`:

| Key | Value |
|-----|-------|
| `NSMotionUsageDescription` | `TapTap needs accelerometer access to detect tap gestures.` |

You can add this in Xcode under your watch app target → **Info** tab → **Custom iOS Target Properties**, or edit `Info.plist` directly:

```xml
<key>NSMotionUsageDescription</key>
<string>TapTap needs accelerometer access to detect tap gestures.</string>
```

### Step 4 — Write the Watch App Code

Replace the contents of your main `ContentView.swift` with:

```swift
import SwiftUI
import CoreMotion
import TapTap

struct ContentView: View {
    @StateObject private var viewModel = TapViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Text(viewModel.lastEvent)
                .font(.title2)
                .fontWeight(.bold)

            Text("Tap count: \(viewModel.tapCount)")
                .font(.caption)

            Text("Swipe count: \(viewModel.swipeCount)")
                .font(.caption)
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

class TapViewModel: ObservableObject {
    @Published var lastEvent = "Waiting…"
    @Published var tapCount = 0
    @Published var swipeCount = 0

    private let motionManager = CMMotionManager()
    private let tapDetector = TapDetector()
    private let swipeDetector = SwipeDetector()
    private let queue = OperationQueue()

    init() {
        tapDetector.onTap = { [weak self] event in
            DispatchQueue.main.async {
                self?.tapCount += 1
                switch event {
                case .singleTap:  self?.lastEvent = "Single Tap"
                case .doubleTap:  self?.lastEvent = "Double Tap"
                case .longTap:    self?.lastEvent = "Long Tap"
                }
            }
        }

        swipeDetector.onSwipe = { [weak self] event in
            DispatchQueue.main.async {
                self?.swipeCount += 1
                switch event {
                case .swipe(.left):   self?.lastEvent = "Swipe Left ←"
                case .swipe(.right):  self?.lastEvent = "Swipe Right →"
                case .swipe(.up):     self?.lastEvent = "Swipe Up ↑"
                case .swipe(.down):   self?.lastEvent = "Swipe Down ↓"
                }
            }
        }
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            lastEvent = "No motion sensor"
            return
        }
        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0  // 100 Hz
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let x = motion.userAcceleration.x
            let y = motion.userAcceleration.y
            let z = motion.userAcceleration.z
            let t = motion.timestamp
            self.tapDetector.processSample(x: x, y: y, z: z, timestamp: t)
            self.swipeDetector.processSample(x: x, y: y, z: z, timestamp: t)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
```

### Step 5 — Configure Signing and Deploy

1. Select your **watch app target** in Xcode
2. Go to the **Signing & Capabilities** tab
3. Check **Automatically manage signing** and select your **Team**
4. Connect your **iPhone** to your Mac via USB (the paired Apple Watch deploys over the iPhone)
5. In the Xcode toolbar, select your **Apple Watch** as the run destination — it appears as `YourName's Apple Watch` under your iPhone
6. Press **⌘R** (or click **Run**)

> **First-time setup:** If this is your first time deploying to the watch, Xcode may need to prepare the device. This can take a few minutes. You may also need to trust the developer profile on the watch: **Settings → General → Device Management → Trust**.

### Step 6 — Test Tap and Swipe Detection

Once the app launches on your Apple Watch:

1. **Point your hand forward** (arm extended, palm facing down)
2. **Single tap** the surface near the watch with a finger — you should see "Single Tap"
3. **Double tap** quickly — you should see "Double Tap"
4. **Tap and hold** your finger down — you should see "Long Tap"
5. **Swipe your wrist left** — you should see "Swipe Left ←"
6. **Swipe your wrist right** — you should see "Swipe Right →"
7. **Tilt your wrist up** — you should see "Swipe Up ↑"
8. **Tilt your wrist down** — you should see "Swipe Down ↓"

### Troubleshooting

| Problem | Fix |
|---------|-----|
| Watch not appearing in Xcode | Make sure iPhone is connected via USB and watch is paired. Restart Xcode. |
| "Untrusted Developer" on watch | Go to **Settings → General → Device Management** on the watch and trust your profile. |
| No tap events detected | Try adjusting `threshold` lower (e.g. `0.3`) — sensitivity varies by surface. |
| Too many false positives | Increase `threshold` (e.g. `1.0`) or increase `lockoutInterval` (e.g. `0.150`). |
| Swipes not detected | Lower `activationThreshold` (e.g. `0.3`) or decrease `minDisplacement` (e.g. `0.04`). |
| Diagonal swipes triggering | Increase `axisRatio` (e.g. `2.0`) to require more directional motion. |
| App crashes on launch | Ensure `NSMotionUsageDescription` is set in `Info.plist`. |

## License

MIT