# tap-tap

Pure signal-processing tap detector for Apple Watch — no ML, no dataset, fully deterministic.

## Overview

```
IMU stream → magnitude → moving average → peak detection → state machine → events
```

Detects two gesture types from raw accelerometer data:

| Event | Description |
|-------|-------------|
| `singleTap` | One sharp acceleration spike |
| `doubleTap` | Two taps within a configurable window |

## Requirements

- Swift 5.9+
- Apple Watch (watchOS 9+), iOS 16+, or macOS 13+

## Quick Start

Add the package to your project and feed `userAcceleration` samples from CoreMotion:

```swift
import TapDetection
import CoreMotion

let detector = TapDetector()
detector.onEvent = { event in
    switch event {
    case .singleTap:  print("Tap")
    case .doubleTap:  print("Double tap")
    }
}

// In your CMMotionManager handler (~100 Hz):
motionManager.startDeviceMotionUpdates(to: queue) { motion, _ in
    guard let accel = motion?.userAcceleration else { return }
    detector.processSample(
        x: accel.x, y: accel.y, z: accel.z,
        timestamp: motion!.timestamp
    )
}
```

## Tuning

All parameters are exposed via `TapDetectorConfiguration`:

```swift
var config = TapDetectorConfiguration()
config.tapThreshold = 2.0      // minimum g to trigger (default: 1.5)
config.lockoutDuration = 0.150 // seconds between taps (default: 0.120)
config.doubleTapWindow = 0.400 // seconds for double-tap (default: 0.350)
let detector = TapDetector(configuration: config)
```

## Testing

```bash
swift test
```

## License

MIT