import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skin Cancer Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SkinCancerDetector(),
    );
  }
}

class SkinCancerDetector extends StatefulWidget {
  const SkinCancerDetector({super.key});

  @override
  State<SkinCancerDetector> createState() => _SkinCancerDetectorState();
}

class _SkinCancerDetectorState extends State<SkinCancerDetector> {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  File? _selectedImage;
  bool _isAnalyzing = false;

  // Model configuration
  static const int imgSize = 224;
  static const double minConfidence = 0.60;

  // Class names and descriptions
  final List<String> classNames = ['bcc', 'mel', 'nv', 'bkl', 'akiec'];

  final Map<String, String> classDescriptions = {
    'bcc': 'Basal Cell Carcinoma (MALIGNANT)',
    'mel': 'Melanoma (MALIGNANT)',
    'nv': 'Melanocytic Nevi (benign mole)',
    'bkl': 'Benign Keratosis (benign)',
    'akiec': 'Actinic Keratoses (precancerous)',
  };

  // Prediction results
  String? _predictedClass;
  double? _confidence;
  List<MapEntry<String, double>>? _topPredictions;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      setState(() {
        _isModelLoaded = true;
      });
      debugPrint('✅ Model loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading model: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading model: $e')));
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _predictedClass = null;
          _confidence = null;
          _topPredictions = null;
        });
        await _analyzeImage();
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<List<double>> _preprocessImage(File imageFile) async {
    // Read image file
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to model input size
    img.Image resized = img.copyResize(
      image,
      width: imgSize,
      height: imgSize,
      interpolation: img.Interpolation.linear,
    );

    // Convert to Float32List normalized to [0, 1]
    List<double> input = [];
    for (int y = 0; y < imgSize; y++) {
      for (int x = 0; x < imgSize; x++) {
        final pixel = resized.getPixel(x, y);
        input.add(pixel.r / 255.0);
        input.add(pixel.g / 255.0);
        input.add(pixel.b / 255.0);
      }
    }

    return input;
  }

  List<double> _applySoftmax(List<double> logits) {
    // Find max for numerical stability
    double maxLogit = logits.reduce((a, b) => a > b ? a : b);

    // Compute exp(x - max)
    List<double> expValues = logits.map((x) => math.exp(x - maxLogit)).toList();

    // Compute sum
    double sumExp = expValues.reduce((a, b) => a + b);

    // Normalize
    return expValues.map((x) => x / sumExp).toList();
  }

  Future<void> _analyzeImage() async {
    if (_interpreter == null || _selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Preprocess image
      List<double> input = await _preprocessImage(_selectedImage!);

      // Reshape to [1, 224, 224, 3]
      var inputTensor = [
        List.generate(
          imgSize,
          (y) => List.generate(
            imgSize,
            (x) => [
              input[(y * imgSize + x) * 3],
              input[(y * imgSize + x) * 3 + 1],
              input[(y * imgSize + x) * 3 + 2],
            ],
          ),
        ),
      ];

      // Prepare output tensor
      var output = List.filled(
        1 * classNames.length,
        0.0,
      ).reshape([1, classNames.length]);

      // Run inference
      _interpreter!.run(inputTensor, output);

      // Get predictions
      List<double> predictions = List<double>.from(output[0]);

      // Apply softmax if needed (check if outputs are logits)
      double sum = predictions.reduce((a, b) => a + b);
      if (sum > 2.0) {
        // Likely logits, apply softmax
        predictions = _applySoftmax(predictions);
      }

      // Get top 3 predictions
      List<MapEntry<String, double>> results = [];
      for (int i = 0; i < classNames.length; i++) {
        results.add(MapEntry(classNames[i], predictions[i]));
      }
      results.sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _predictedClass = results[0].key;
        _confidence = results[0].value;
        _topPredictions = results.take(3).toList();
        _isAnalyzing = false;
      });
    } catch (e) {
      debugPrint('❌ Error analyzing image: $e');
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error analyzing image: $e')));
      }
    }
  }

  Color _getResultColor() {
    if (_confidence == null || _predictedClass == null) {
      return Colors.grey;
    }

    if (_confidence! < minConfidence) {
      return Colors.orange;
    } else if (_predictedClass == 'mel' || _predictedClass == 'bcc') {
      return Colors.red;
    } else if (_predictedClass == 'akiec') {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getResultText() {
    if (_confidence == null || _predictedClass == null) {
      return '';
    }

    if (_confidence! < minConfidence) {
      return '⚠️ UNCERTAIN';
    } else if (_predictedClass == 'mel' || _predictedClass == 'bcc') {
      return '🚨 POSSIBLY MALIGNANT';
    } else if (_predictedClass == 'akiec') {
      return '⚠️ PRECANCEROUS';
    } else {
      return '✅ LIKELY BENIGN';
    }
  }

  String _getAdvice() {
    if (_confidence == null || _predictedClass == null) {
      return '';
    }

    if (_confidence! < minConfidence) {
      return 'Image quality may be poor - See a doctor';
    } else if (_predictedClass == 'mel' || _predictedClass == 'bcc') {
      return 'URGENT: Consult dermatologist immediately';
    } else if (_predictedClass == 'akiec') {
      return 'Schedule dermatologist appointment';
    } else {
      return 'Monitor for changes, routine checkup';
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔬 Skin Cancer Detector'),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        _isModelLoaded
                            ? Icons.check_circle
                            : Icons.hourglass_empty,
                        size: 48,
                        color: _isModelLoaded ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isModelLoaded ? '✅ Model Ready' : '⏳ Loading Model...',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload a clear, well-lit photo of a skin lesion',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Image picker buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isModelLoaded && !_isAnalyzing
                          ? () => _pickImage(ImageSource.camera)
                          : null,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isModelLoaded && !_isAnalyzing
                          ? () => _pickImage(ImageSource.gallery)
                          : null,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Image display
              if (_selectedImage != null) ...[
                Card(
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
                      if (_isAnalyzing)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('🔬 Analyzing with AI...'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Results
                if (!_isAnalyzing && _predictedClass != null) ...[
                  Card(
                    elevation: 4,
                    color: _getResultColor().withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              _getResultText(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getResultColor(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            '🎯 Prediction',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            classDescriptions[_predictedClass!]!,
                            style: const TextStyle(fontSize: 16),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            '📊 Confidence',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _confidence,
                            minHeight: 20,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getResultColor(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_confidence! * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            '💡 Advice',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getAdvice(),
                            style: const TextStyle(fontSize: 16),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            '📊 Top 3 Possibilities',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          ..._topPredictions!.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String className = entry.value.key;
                            double confidence = entry.value.value;

                            String indicator = '🟢';
                            if (className == 'mel' || className == 'bcc') {
                              indicator = '🔴';
                            } else if (className == 'akiec') {
                              indicator = '🟡';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    '${idx + 1}. $indicator',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      classDescriptions[className]!,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Text(
                                    '${(confidence * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Disclaimer
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ MEDICAL DISCLAIMER',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• This AI is for EDUCATIONAL purposes ONLY\n'
                            '• NOT FDA approved for medical diagnosis\n'
                            '• NOT a substitute for professional advice\n'
                            '• ALWAYS consult a dermatologist\n'
                            '• Early detection saves lives',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
