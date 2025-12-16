# Skin Cancer Detector (Prototype)

A lightweight Flutter prototype that walks through capturing or uploading a skin-lesion photo, letting the user crop/enhance it, running a tiny on-device heuristic classifier (benign vs. suspicious), and showing a confidence score with disclaimers. History and info screens are included for a complete demo feel.

## Features
- Home screen with quick guidance and disclaimer
- Camera screen (live preview, capture, flash toggle)
- Upload/preview screen for gallery images
- Preprocessing screen with a simple crop tool and enhancement
- Results screen with label, confidence meter, original vs processed previews, feature breakdown, and disclaimer
- Optional history list of saved scans
- Info/about screen with how-it-works notes and photo tips
- On-device heuristic classifier using asymmetry, border darkening, color spread, contrast, and size coverage

## Running the app
1) Install Flutter (3.10+ recommended) and add `flutter` to your PATH.
2) Run `flutter pub get` to install dependencies.
3) Connect a device or start an emulator, then run `flutter run`.

## Notes
- The classifier is intentionally tiny and heuristic-based; it is **not** a medical device or diagnostic tool.
- Android: requires camera and photo permissions (already declared).
- iOS: permissions for camera and photo library are declared in `ios/Runner/Info.plist`.
