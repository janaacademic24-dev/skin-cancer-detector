import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SkinCancerApp());
}

class SkinCancerApp extends StatefulWidget {
  const SkinCancerApp({super.key});

  @override
  State<SkinCancerApp> createState() => _SkinCancerAppState();
}

class _SkinCancerAppState extends State<SkinCancerApp> {
  final List<ScanResult> _history = [];

  void _addToHistory(ScanResult result) {
    setState(() {
      _history.insert(0, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Skin Check Prototype',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomeShell(
        history: _history,
        onAddHistory: _addToHistory,
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.history,
    required this.onAddHistory,
  });

  final List<ScanResult> history;
  final void Function(ScanResult result) onAddHistory;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final ImagePicker _picker = ImagePicker();
  int _tabIndex = 0;

  Future<void> _startCameraFlow() async {
    final bytes = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (bytes != null && mounted) {
      await _openPreview(bytes);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        await _openPreview(bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  Future<void> _openPreview(Uint8List bytes) async {
    final previewedBytes = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(imageBytes: bytes),
      ),
    );

    if (previewedBytes == null || !mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreprocessScreen(
          imageBytes: previewedBytes,
          onSave: widget.onAddHistory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onStartCamera: _startCameraFlow,
        onUpload: _pickFromGallery,
      ),
      HistoryScreen(history: widget.history),
      const InfoScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onStartCamera,
    required this.onUpload,
  });

  final VoidCallback onStartCamera;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Skin Check (Prototype)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture or upload a skin lesion photo to run a quick on-device triage. '
              'This prototype is for demo and education purposes only.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a scan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined),
                      onPressed: onStartCamera,
                      label: const Text('Use camera'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: onUpload,
                      label: const Text('Upload from gallery'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Not a medical device. Always consult a dermatologist for real evaluation.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Quick tips for a good image',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const BulletList(items: [
              'Use bright, even lighting and turn off beauty filters.',
              'Hold the camera 10-15cm away and keep the lesion in focus.',
              'Avoid shadows and reflections; clean the lens if needed.',
              'Capture a single spot per photo.',
            ]),
            const SizedBox(height: 16),
            Text(
              'What happens next?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const BulletList(items: [
              'We crop and lightly enhance the photo.',
              'A tiny demo classifier scores the lesion: benign vs suspicious.',
              'You get a confidence score plus a reminder to seek real care.',
            ]),
          ],
        ),
      ),
    );
  }
}

class BulletList extends StatelessWidget {
  const BulletList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initializing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera unavailable: $e')),
      );
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      final newState = !_flashOn;
      await controller.setFlashMode(
        newState ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) return;
      setState(() => _flashOn = newState);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flash not available on this device')),
      );
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.pop(context, bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (_controller != null && _controller!.value.isInitialized)
                  CameraPreview(_controller!)
                else
                  const Center(child: Text('Camera not available')),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Center the lesion, keep the phone steady, and tap capture.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _toggleFlash,
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.black.withOpacity(0.35),
                            ),
                            icon: Icon(
                              _flashOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _capturing ? null : _capture,
                            icon: _capturing
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.camera),
                            label: const Text('Capture'),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Confirm the image looks clear and contains one lesion.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, imageBytes),
                  icon: const Icon(Icons.check),
                  label: const Text('Continue to preprocessing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Pick another image'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PreprocessScreen extends StatefulWidget {
  const PreprocessScreen({
    super.key,
    required this.imageBytes,
    required this.onSave,
  });

  final Uint8List imageBytes;
  final void Function(ScanResult result) onSave;

  @override
  State<PreprocessScreen> createState() => _PreprocessScreenState();
}

class _PreprocessScreenState extends State<PreprocessScreen> {
  final CropController _cropController = CropController();
  Uint8List? _previewBytes;
  bool _cropping = false;
  bool _processing = false;
  String _status = 'Adjust the crop, then run analysis.';

  @override
  void initState() {
    super.initState();
    _previewBytes = widget.imageBytes;
  }

  Future<void> _runCrop() async {
    setState(() {
      _cropping = true;
      _status = 'Cropping and enhancing...';
    });
    _cropController.crop();
  }

  Future<void> _onCropped(Uint8List bytes) async {
    final enhanced = await Preprocessor.preprocessImage(bytes);
    if (!mounted) return;
    setState(() {
      _previewBytes = enhanced;
      _cropping = false;
      _status = 'Cropped and enhanced. Ready to analyze.';
    });
  }

  Future<void> _useFullImage() async {
    setState(() {
      _cropping = true;
      _status = 'Enhancing full image...';
    });
    final enhanced = await Preprocessor.preprocessImage(widget.imageBytes);
    if (!mounted) return;
    setState(() {
      _previewBytes = enhanced;
      _cropping = false;
      _status = 'Full image enhanced. Ready to analyze.';
    });
  }

  Future<void> _runAnalysis() async {
    if (_processing) {
      return;
    }
    setState(() {
      _processing = true;
      _status = 'Running analysis...';
    });
    final bytes = _previewBytes ?? widget.imageBytes;
    final processed = await Preprocessor.preprocessImage(bytes);
    final classifier = SimpleSkinClassifier();
    final details = await classifier.analyze(processed);
    final probability = details.probability;
    final label = probability >= 0.55 ? 'Suspicious' : 'Benign';
    final result = ScanResult(
      label: label,
      confidence: probability,
      timestamp: DateTime.now(),
      imageBytes: widget.imageBytes,
      processedBytes: processed,
      details: details,
    );
    if (!mounted) return;
    setState(() {
      _processing = false;
      _status = 'Analysis complete.';
    });
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          result: result,
          onSave: () => widget.onSave(result),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewBytes = _previewBytes ?? widget.imageBytes;
    return Scaffold(
      appBar: AppBar(title: const Text('Preprocess')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Crop(
                  controller: _cropController,
                  image: widget.imageBytes,
                  aspectRatio: 1,
                  baseColor: Colors.black,
                  maskColor: Colors.black.withOpacity(0.4),
                  initialAreaBuilder: (rect) => Rect.fromLTWH(
                    rect.left + rect.width * 0.1,
                    rect.top + rect.height * 0.1,
                    rect.width * 0.8,
                    rect.height * 0.8,
                  ),
                  onCropped: _onCropped,
                ),
              ),
            ),
          ),
          if (_cropping || _processing)
            const LinearProgressIndicator(minHeight: 3),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _status,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cropping ? null : _useFullImage,
                        icon: const Icon(Icons.crop_free),
                        label: const Text('Use full image'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _cropping ? null : _runCrop,
                        icon: const Icon(Icons.crop),
                        label: const Text('Crop selection'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      previewBytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _processing ? null : _runAnalysis,
                  icon: _processing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Run AI analysis'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is a lightweight demo model. Results are probabilistic and not diagnostic.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.result,
    required this.onSave,
  });

  final ScanResult result;
  final VoidCallback onSave;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _saved = false;

  String _formatConfidence(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String _formatTimestamp(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _handleSave() {
    if (_saved) return;
    widget.onSave();
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to history')),
    );
  }

  Widget _confidenceMeter(double value) {
    final color = value >= 0.7
        ? Colors.red
        : value >= 0.45
            ? Colors.orange
            : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            color: color,
            backgroundColor: color.withOpacity(0.15),
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value, String hint) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _insights(PredictionDetails d) {
    return [
      {
        'title': 'Asymmetry',
        'value': _formatConfidence(d.asymmetry.clamp(0.0, 1.0)),
        'hint': 'Balanced halves are generally lower risk.',
      },
      {
        'title': 'Border darkening',
        'value': _formatConfidence(d.edgeDarkness.clamp(0.0, 1.0)),
        'hint': 'Dark center vs lighter edges can be suspicious.',
      },
      {
        'title': 'Contrast',
        'value': _formatConfidence(d.contrast.clamp(0.0, 1.0)),
        'hint': 'Sharper edges can indicate irregularity.',
      },
      {
        'title': 'Color spread',
        'value': _formatConfidence(d.colorSpread.clamp(0.0, 1.0)),
        'hint': 'Multiple hues and tones increase concern.',
      },
      {
        'title': 'Coverage',
        'value': _formatConfidence(d.sizeFraction.clamp(0.0, 1.0)),
        'hint': 'Lesion occupies this fraction of the frame.',
      },
      {
        'title': 'Darkness',
        'value': _formatConfidence(d.darkness.clamp(0.0, 1.0)),
        'hint': 'Average darkness of the lesion area.',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isSuspicious = result.isSuspicious;
    final confidence = isSuspicious
        ? result.confidence
        : (1 - result.confidence).clamp(0.0, 1.0);
    final details = result.details;
    String percent(double v) => '${(v * 100).toStringAsFixed(0)}%';

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isSuspicious
                        ? Icons.error_rounded
                        : Icons.check_circle_rounded,
                    color: isSuspicious ? Colors.red : Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    result.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Confidence: ${_formatConfidence(confidence)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _confidenceMeter(confidence),
              Text(
                'Evaluated: ${_formatTimestamp(result.timestamp)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Prototype only. If you see rapid changes or high suspicion, seek a dermatologist promptly.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Captured image',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          result.imageBytes,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          result.processedBytes,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Analysis signals',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricCard(
                    'Contrast',
                    percent(details.contrast.clamp(0.0, 1.5).toDouble()),
                    'Edge detail / texture strength',
                  ),
                  _metricCard(
                    'Color spread',
                    percent(details.colorSpread.clamp(0.0, 1.0).toDouble()),
                    'Variation across channels',
                  ),
                  _metricCard(
                    'Asymmetry',
                    percent(details.asymmetry.clamp(0.0, 1.0).toDouble()),
                    'Left/right imbalance',
                  ),
                  _metricCard(
                    'Border darkening',
                    percent(details.edgeDarkness),
                    'Center darker than rim',
                  ),
                  _metricCard(
                    'Lesion size',
                    percent(details.sizeFraction),
                    'Darker area coverage',
                  ),
                  _metricCard(
                    'Overall darkness',
                    percent(details.darkness),
                    'Average luminance',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Interpretation',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _insights(details)
                    .map(
                      (insight) => Container(
                        width: 170,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight['title']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              insight['value']!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              insight['hint']!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Disclaimer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'This is a simplified prototype model and is NOT a medical diagnosis. '
                'Always consult a dermatologist for real assessment. If you notice changes in a lesion, seek care promptly.',
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saved ? null : _handleSave,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(_saved ? 'Saved' : 'Save to history'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Scan again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.history});

  final List<ScanResult> history;

  String _formatTimestamp(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SafeArea(
        child: Center(
          child: Text('No scans saved yet.'),
        ),
      );
    }
    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = history[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                item.imageBytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(item.label),
            subtitle: Text(
              'Suspicion: ${(item.confidence * 100).toStringAsFixed(0)}% - ${_formatTimestamp(item.timestamp)}',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResultsScreen(
                    result: item,
                    onSave: () {},
                  ),
                ),
              );
            },
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: history.length,
      ),
    );
  }
}

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'How this demo works',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '1) You capture or upload a lesion image.\n'
              '2) We let you crop and we lightly enhance the image.\n'
              '3) A tiny on-device heuristic looks at asymmetry, border contrast, darkness, and color spread to score benign vs suspicious.',
            ),
            SizedBox(height: 12),
            Text(
              'Tips for capturing a good image',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            BulletList(items: [
              'Shoot in bright, even lighting. Avoid flash glare if the skin is oily.',
              'Keep the lesion centered and in focus; wipe the lens if needed.',
              'Avoid zooming; move closer instead until the lesion fills most of the frame.',
            ]),
            SizedBox(height: 12),
            Text(
              'Signals this demo considers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            BulletList(items: [
              'Asymmetry between left/right halves.',
              'Border darkening (center darker than rim).',
              'Color spread and contrast.',
              'Approximate lesion coverage in the frame.',
            ]),
            SizedBox(height: 12),
            Text(
              'Safety notice',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This prototype is NOT a diagnostic tool. It uses a simplified on-device model for demonstration. '
              'Always seek professional medical advice for any skin concerns.',
            ),
          ],
        ),
      ),
    );
  }
}

class ScanResult {
  ScanResult({
    required this.label,
    required this.confidence,
    required this.timestamp,
    required this.imageBytes,
    required this.processedBytes,
    required this.details,
  });

  final String label;
  final double confidence; // probability that lesion is suspicious
  final DateTime timestamp;
  final Uint8List imageBytes;
  final Uint8List processedBytes;
  final PredictionDetails details;

  bool get isSuspicious => confidence >= 0.55;
}

class Preprocessor {
  static Future<Uint8List> preprocessImage(Uint8List data) async {
    final decoded = img.decodeImage(data);
    if (decoded == null) {
      return data;
    }
    final resized = img.copyResize(
      decoded,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.cubic,
    );
    final enhanced = img.adjustColor(
      resized,
      contrast: 1.08,
      saturation: 1.05,
      brightness: 0.05,
      gamma: 0.95,
    );
    return Uint8List.fromList(img.encodeJpg(enhanced, quality: 90));
  }
}

class PredictionDetails {
  PredictionDetails({
    required this.probability,
    required this.contrast,
    required this.colorSpread,
    required this.edgeDarkness,
    required this.asymmetry,
    required this.sizeFraction,
    required this.darkness,
  });

  final double probability;
  final double contrast;
  final double colorSpread;
  final double edgeDarkness;
  final double asymmetry;
  final double sizeFraction;
  final double darkness;
}

class SimpleSkinClassifier {
  Future<PredictionDetails> analyze(Uint8List data) async {
    final decoded = img.decodeImage(data);
    if (decoded == null) {
      return PredictionDetails(
        probability: 0.5,
        contrast: 0,
        colorSpread: 0,
        edgeDarkness: 0,
        asymmetry: 0,
        sizeFraction: 0,
        darkness: 0.5,
      );
    }
    final resized = img.copyResize(decoded, width: 96, height: 96);
    final totalPixels = resized.width * resized.height;

    double meanR = 0;
    double meanG = 0;
    double meanB = 0;
    for (final pixel in resized.data) {
      meanR += img.getRed(pixel);
      meanG += img.getGreen(pixel);
      meanB += img.getBlue(pixel);
    }
    meanR /= totalPixels;
    meanG /= totalPixels;
    meanB /= totalPixels;

    double contrast = 0;
    for (final pixel in resized.data) {
      final lum = img.getLuminanceRgb(
        img.getRed(pixel),
        img.getGreen(pixel),
        img.getBlue(pixel),
      );
      contrast += (lum - ((meanR + meanG + meanB) / 3)).abs();
    }
    contrast /= totalPixels;

    // Simple symmetry metric: compare left vs right halves.
    double asymmetry = 0;
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width / 2; x++) {
        final left = resized.getPixel(x, y);
        final right = resized.getPixel(resized.width - 1 - x, y);
        final lumLeft = img.getLuminanceRgb(
          img.getRed(left),
          img.getGreen(left),
          img.getBlue(left),
        );
        final lumRight = img.getLuminanceRgb(
          img.getRed(right),
          img.getGreen(right),
          img.getBlue(right),
        );
        asymmetry += (lumLeft - lumRight).abs();
      }
    }
    asymmetry /= totalPixels;

    final colorSpread = ((meanR - meanG).abs() +
            (meanG - meanB).abs() +
            (meanB - meanR).abs()) /
        255;
    final edgeDarkness = _edgeDarkening(resized);
    final sizeFraction = _sizeFraction(resized);
    final darkness = (1 - ((meanR + meanG + meanB) / 3) / 255).clamp(0.0, 1.0);

    // Simple logistic-like scoring combining coarse features.
    final logit = -1.2 +
        1.7 * (contrast / 128) +
        1.3 * colorSpread +
        0.9 * edgeDarkness +
        1.0 * (asymmetry / 96) +
        0.6 * sizeFraction +
        0.8 * darkness;
    final probability = 1 / (1 + math.exp(-logit));

    return PredictionDetails(
      probability: probability.clamp(0.0, 1.0),
      contrast: (contrast / 128).clamp(0.0, 2.0),
      colorSpread: colorSpread.clamp(0.0, 2.0),
      edgeDarkness: edgeDarkness,
      asymmetry: (asymmetry / 96).clamp(0.0, 2.0),
      sizeFraction: sizeFraction.clamp(0.0, 1.0),
      darkness: darkness,
    );
  }

  double _edgeDarkening(img.Image image) {
    double border = 0;
    double center = 0;
    int borderCount = 0;
    int centerCount = 0;
    final xCutoff = (image.width * 0.1).round();
    final yCutoff = (image.height * 0.1).round();

    final data = image.data;
    for (var y = 0; y < image.height; y++) {
      final rowStart = y * image.width;
      for (var x = 0; x < image.width; x++) {
        final pixel = data[rowStart + x];
        final lum = img.getLuminanceRgb(
          img.getRed(pixel),
          img.getGreen(pixel),
          img.getBlue(pixel),
        );
        final isBorder =
            x < xCutoff || x > image.width - xCutoff || y < yCutoff || y > image.height - yCutoff;
        if (isBorder) {
          border += lum;
          borderCount++;
        } else {
          center += lum;
          centerCount++;
        }
      }
    }

    if (borderCount == 0 || centerCount == 0) {
      return 0;
    }
    final borderMean = border / borderCount;
    final centerMean = center / centerCount;
    final diff = (centerMean - borderMean) / 255;
    return diff.clamp(0.0, 1.0);
  }

  double _sizeFraction(img.Image image) {
    // Estimate lesion area by counting darker-than-mean pixels.
    final meanLum = image.data
            .map((p) => img.getLuminanceRgb(
                  img.getRed(p),
                  img.getGreen(p),
                  img.getBlue(p),
                ))
            .reduce((a, b) => a + b) /
        image.data.length;
    final threshold = (meanLum * 0.9);
    int lesionCount = 0;
    for (final pixel in image.data) {
      final lum = img.getLuminanceRgb(
        img.getRed(pixel),
        img.getGreen(pixel),
        img.getBlue(pixel),
      );
      if (lum < threshold) {
        lesionCount++;
      }
    }
    return lesionCount / image.data.length;
  }
}
