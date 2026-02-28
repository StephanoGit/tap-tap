# TapTap

A pure signal-processing tap detector for Apple Watch (and iOS).  
No machine learning — just IMU filtering, peak detection, and a minimal state machine.

## Events

| Event | Description |
|-------|-------------|
| `singleTap` | One distinct tap on a surface |
| `doubleTap` | Two taps within a configurable time window |
| `longTap` | A tap followed by sustained low-motion hold |

## How It Works

```
IMU stream → magnitude → peak detection → lockout → state machine → events
```

1. **Magnitude** — `√(x² + y² + z²)` of user acceleration (gravity removed).
2. **Peak detection** — magnitude exceeds a configurable threshold.
3. **Lockout** — ignores ringing oscillations for ~120 ms after a peak.
4. **State machine** — classifies peaks into single, double, or long taps.

## Quick Start

Add TapTap as a Swift Package dependency:

```swift
.package(url: "https://github.com/StephanoGit/tap-tap.git", from: "0.1.0")
```

Then use it with CoreMotion:

```swift
import TapTap
import CoreMotion

let detector = TapDetector()
detector.onTap = { event in
    switch event {
    case .singleTap:  print("tap")
    case .doubleTap:  print("double tap")
    case .longTap:    print("long tap")
    }
}

// Feed samples from CMMotionManager.deviceMotionUpdates
detector.processSample(
    x: motion.userAcceleration.x,
    y: motion.userAcceleration.y,
    z: motion.userAcceleration.z,
    timestamp: motion.timestamp
)
```

## Configuration

```swift
let config = TapDetectorConfig(
    threshold: 1.5,            // magnitude in g
    lockoutInterval: 0.120,    // seconds
    doubleTapWindow: 0.350,    // seconds
    longTapHoldDuration: 0.500,// seconds
    longTapVarianceThreshold: 0.05
)
let detector = TapDetector(config: config)
```

## License

MIT