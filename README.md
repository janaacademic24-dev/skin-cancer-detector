# 🔬 DermaScan AI — Skin Cancer Detection App



> ⚠️ **Medical Disclaimer:** This application is intended for **educational and research purposes only**. It is **not** a substitute for professional medical diagnosis and has **not** been FDA-approved or clinically validated. Always consult a licensed dermatologist for any skin concerns.

---

## 📖 Overview

**DermaScan AI** is a cross-platform mobile application that uses a custom-trained TensorFlow Lite convolutional neural network to analyze photographs of skin lesions and classify them into one of five dermatological categories. The model runs entirely **on-device**, ensuring user privacy and enabling offline functionality.

The AI model was trained on the [HAM10000 dataset](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/DBW86T) — a well-established benchmark collection of over 10,000 dermatoscopic images.

---

## ✨ Features

- **On-device AI Inference** — TensorFlow Lite model runs locally; no data leaves your device
- **Camera & Gallery Support** — Capture a new photo or select one from your library
- **Image Cropping** — Built-in cropping tool to isolate the lesion for better accuracy
- **Flashlight Control** — Toggle the device torch for better lighting when capturing images
- **Confidence Scoring** — Visual confidence bar with percentage for each prediction
- **Top-3 Predictions** — See the three most likely classifications ranked by probability
- **Scan History** — Persistent local storage of up to 50 previous scan results
- **Color-coded Risk Levels** — Instant visual feedback (red = malignant, orange = precancerous, green = benign)
- **Medical Advice Prompts** — Contextual guidance on when to seek professional care

---

## 🧬 Supported Classifications

| Code | Full Name | Risk Level |
|------|-----------|------------|
| `mel` | Melanoma | 🔴 Malignant |
| `bcc` | Basal Cell Carcinoma | 🔴 Malignant |
| `akiec` | Actinic Keratoses | 🟡 Precancerous |
| `nv` | Melanocytic Nevi | 🟢 Benign |
| `bkl` | Benign Keratosis | 🟢 Benign |

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| [Flutter](https://flutter.dev/) | Cross-platform UI framework |
| [TensorFlow Lite (`tflite_flutter`)](https://pub.dev/packages/tflite_flutter) | On-device AI inference |
| [`image`](https://pub.dev/packages/image) | Image decoding & preprocessing |
| [`image_picker`](https://pub.dev/packages/image_picker) | Camera & gallery access |
| [`image_cropper`](https://pub.dev/packages/image_cropper) | Interactive image cropping |
| [`torch_light`](https://pub.dev/packages/torch_light) | Device flashlight control |
| [`permission_handler`](https://pub.dev/packages/permission_handler) | Runtime permissions |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Persistent scan history |
| [`path_provider`](https://pub.dev/packages/path_provider) | Local file system access |
| [`intl`](https://pub.dev/packages/intl) | Date/time formatting |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.x or later)
- Android Studio or Xcode (for device/emulator deployment)
- A physical device is strongly recommended for camera features

### Installation

1. **Clone the repository**
   ```bash
  git clone https://github.com/janaacademic24-dev/skin-cancer-detector.git
   cd skin-cancer-detector
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Add the TFLite model**

   Place the `model.tflite` file in the `assets/` directory:
   ```
   assets/
   └── model.tflite
   ```

   Ensure it is declared in `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/model.tflite
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 🤖 AI Model Details

| Parameter | Value |
|---|---|
| Framework | TensorFlow Lite |
| Input Size | 300 × 300 × 3 (RGB) |
| Normalization | Pixel values scaled to `[0, 1]` |
| Output | 5-class softmax probabilities |
| Minimum Confidence Threshold | 60% |
| Training Dataset | HAM10000 |
| Output Classes | 5 (see classification table above) |

### Inference Pipeline

1. **Image Decoding** — The selected image is decoded from bytes using the `image` package.
2. **Resizing** — The image is resized to 300×300 pixels using linear interpolation.
3. **Normalization** — RGB pixel values are normalized to the range `[0.0, 1.0]`.
4. **Inference** — The preprocessed tensor `[1, 300, 300, 3]` is fed into the TFLite interpreter.
5. **Softmax** — If raw logits are detected (sum > 2.0), softmax is applied for probability normalization.
6. **Result Ranking** — The top 3 class predictions are ranked by confidence score.

---

## 📸 Tips for Best Results

To maximize classification accuracy, follow these image capture guidelines:

- **Lighting** — Use bright, even, natural light. Avoid shadows and glare. Use the in-app flashlight if needed.
- **Distance** — Get close enough that the lesion fills most of the frame.
- **Focus** — Tap the lesion on your camera screen to ensure sharp focus.
- **Angle** — Shoot from directly above the lesion, perpendicular to the skin surface.
- **Cropping** — Use the built-in crop tool to remove background and center the lesion.
- **Multiple attempts** — If the confidence is low (< 60%), try retaking from a different angle or lighting condition.

---

## 📁 Project Structure

```
lib/
├── main.dart                  # App entry point, theme configuration
├── models/
│   └── scan_result.dart       # ScanResult data model with JSON serialization
└── screens/
    ├── skin_cancer_detector.dart  # Main scanner screen & inference logic
    ├── history_screen.dart        # Scan history list with swipe-to-delete
    ├── history_detail_screen.dart # Detailed view of a past scan
    └── about_screen.dart          # App information & usage tips

assets/
├── model.tflite               # TFLite classification model
└── images/
    └── app_logo.png           # App logo
```

---

## 🔒 Privacy

All image processing and AI inference are performed entirely **on-device**. No images, scan results, or personal data are transmitted to any external server. Scan history is stored locally using `SharedPreferences` and can be deleted at any time from within the app.

---

## ⚠️ Medical & Legal Disclaimer

This application is a **student/educational project** and:

- Is **not** intended to diagnose, treat, cure, or prevent any medical condition.
- Has **not** been approved by the FDA or any equivalent regulatory body.
- Should **never** be used as a substitute for consultation with a licensed dermatologist or healthcare professional.
- May produce **inaccurate results** based on image quality, lighting, or lesion type.

If you have any concerns about a skin lesion, **please consult a qualified medical professional immediately**. Early professional evaluation saves lives.

---

---

## 🙏 Acknowledgements

- [HAM10000 Dataset](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/DBW86T) — Tschandl, P. et al. (2018)
- [TensorFlow Lite](https://www.tensorflow.org/lite) — On-device ML framework by Google
- [Flutter](https://flutter.dev/) — UI toolkit by Google
