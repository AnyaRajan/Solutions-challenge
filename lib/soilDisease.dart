import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ImagePreview extends StatelessWidget {
  final File image;
  final String message;
  final String responseContent;

  const ImagePreview({
    Key? key,
    required this.image,
    required this.message,
    required this.responseContent,
  }) : super(key: key);

  List<TextSpan> _parseText(String text) {
    final List<TextSpan> textSpans = [];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int currentIndex = 0;

    for (final match in boldRegex.allMatches(text)) {
      if (match.start > currentIndex) {
        textSpans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(color: Colors.grey[800]),
          ),
        );
      }

      textSpans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: Colors.green[800],
            fontSize: 16,
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      textSpans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: Colors.grey[800]),
        ),
      );
    }

    return textSpans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Health Analysis'),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green[50]!,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              margin: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _getStatusColor(message),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommendations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 15),
                          children: _parseText(responseContent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('healthy')) {
      return Colors.green;
    } else if (status.contains('Unable to Detect')) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

class DiseaseDetectionPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const DiseaseDetectionPage({Key? key, required this.cameras}) : super(key: key);

  @override
  State<DiseaseDetectionPage> createState() => _DiseaseDetectionPageState();
}

class _DiseaseDetectionPageState extends State<DiseaseDetectionPage> {
  File? filePath;
  String label = '';
  double confidence = 0.0;

  late CameraController _controller;
  bool _isCameraInitialized = false;
  bool _isLoaded = false;
  bool _isLoading = false;

  String _statusMessage = 'Model not loaded';
  String _errorMessage = '';
  Interpreter? _interpreter;
  int num_classes = 38;
  String predictedLabel = "Unable to Detect";

  String? apiKey = dotenv.env['GEMINI_API_KEY'];

  GenerativeModel? model;
  String aiResponse = '';

  File? _image;

  List<String> labels = [
    "Apple___Apple_scab",
    "Apple___Black_rot",
    "Apple___Cedar_apple_rust",
    "Apple___healthy",
    "Blueberry___healthy",
    "Cherry_(including_sour)_Powdery_mildew",
    "Cherry_(including_sour)_healthy",
    "Corn_(maize)_Cercospora_leaf_spot Gray_leaf_spot",
    "Corn_(maize)_Common_rust",
    "Corn_(maize)_Northern_Leaf_Blight",
    "Corn_(maize)_healthy",
    "Grape___Black_rot",
    "Grape__Esca(Black_Measles)",
    "Grape__Leaf_blight(Isariopsis_Leaf_Spot)",
    "Grape___healthy",
    "Orange__Haunglongbing(Citrus_greening)",
    "Peach___Bacterial_spot",
    "Peach___healthy",
    "Pepper,bell__Bacterial_spot",
    "Pepper,bell__healthy",
    "Potato___Early_blight",
    "Potato___Late_blight",
    "Potato___healthy",
    "Raspberry___healthy",
    "Soybean___healthy",
    "Squash___Powdery_mildew",
    "Strawberry___Leaf_scorch",
    "Strawberry___healthy",
    "Tomato___Bacterial_spot",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Leaf_Mold",
    "Tomato___Septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite",
    "Tomato___Target_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus",
    "Tomato___healthy"
];

  String _connectionStatus = 'Unknown';

  Future<void> _checkConnectivity() async {
    final List<ConnectivityResult> result =
        await Connectivity().checkConnectivity();
    print(result);
    if (result.contains(ConnectivityResult.none)) {
      setState(() {
        _connectionStatus = "No internet Connection";
      });
    }
  }

  Future<void> _loadModel() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading model...';
      _errorMessage = '';
    });

    try {
      // Close any existing interpreter
      _interpreter?.close();

      // Load the model
      _interpreter = await Interpreter.fromAsset(
        'assets/disease_detection_model.tflite',
      );
      print(_interpreter);

      setState(() {
        _isLoaded = true;
        _isLoading = false;
        _statusMessage = 'Model loaded successfully!';
      });
    } catch (e) {
      setState(() {
        _isLoaded = false;
        _isLoading = false;
        _statusMessage = 'Failed to load model';
        _errorMessage = e.toString();
      });
      print('Error loading model: $e');
    }
  }

  Future<void> initializeCamera() async {
    try {
      if (widget.cameras.isEmpty) {
        print("No cameras found");
        return;
      }
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
      );
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
      print("Camera initialized successfully");
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }
  Future<void> _classifyImage(File image) async {
    try {
      final imageBytes = await image.readAsBytes();
      img.Image imageTemp = img.decodeImage(imageBytes)!;
      img.Image resizedImage = img.copyResize(
        imageTemp,
        width: 160,
        height: 160,
      );

      var input = imageToByteListFloat32(resizedImage, 128);

      var inputTensor = input.reshape([1, 128, 128, 3]);

      var output = List.filled(1 * num_classes, 0).reshape([1, num_classes]);

      _interpreter!.run(inputTensor, output);

      print(output[0]);

      final predictedLabelScore = output[0].reduce(
        (double a, double b) => a > b ? a : b,
      );
      final predictedLabelIndex = output[0].indexOf(predictedLabelScore);

      if (predictedLabelScore > 0.65) {
        setState(() {
          predictedLabel = labels[predictedLabelIndex];
          _statusMessage = "${predictedLabel}";
        });
      } else {
        _statusMessage = predictedLabel;
      }

      if (predictedLabel != "Unable to Detect") {
        await getInfo(predictedLabel);
      }
      print(_statusMessage);
    } catch (e) {
      print("Error classifying image: $e");
      return null;
    }
  }

  Float32List imageToByteListFloat32(img.Image image, int inputSize) {
    // Initialize a Float32List to store the normalized image data
    var convertedBytes = Float32List(
      1 * inputSize * inputSize * 3,
    ); // Shape: [1, 160, 160, 3]

    // Create a view of the buffer for easy manipulation
    var buffer = Float32List.view(convertedBytes.buffer);

    // Iterate over each pixel in the image
    int pixelIndex = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        // Get the pixel at (x, y)
        var pixel = image.getPixel(x, y);

        //store them in the buffer and no need to normalize the values
        buffer[pixelIndex++] = pixel.r.toDouble();
        buffer[pixelIndex++] = pixel.g.toDouble();
        buffer[pixelIndex++] = pixel.b.toDouble();
      }
    }

    // Return the Float32List directly
    return convertedBytes;
  }

  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _isLoading || !_isLoaded) return;

    setState(() => _isLoading = true);
    try {
      final image = await _controller.takePicture();
      if (image == null) return;

      setState(() {
        _image = File(image.path);
      });
    } catch (e) {
      print("Error capturing image: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      setState(() {
        _image = File(image.path);
      });
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> getInfo(String label) async {
    await _checkConnectivity();
    try {
      // Send the prompt to the model
      final prompt =
          "list precautionary measure for $label disease in my plant.";
      final content = [Content.text(prompt)];
      final response = await model!.generateContent(content);

      // Update the UI with the response
      setState(() {
        aiResponse = response.text ?? 'No response from the model.';
      });
      print(aiResponse);
    } catch (e) {
      setState(() {
        if (_connectionStatus != 'Unknown') {
          aiResponse = '$_connectionStatus, Please check your Connection';
        } else {
          aiResponse = 'Error: $e';
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadModel();
    initializeCamera();
    _interpreter?.close();
    if (apiKey == null) {
      print('No \$API_KEY environment variable');
      exit(1);
    }
    model = GenerativeModel(model: 'gemini-2.0-flash-001', apiKey: apiKey!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Disease Detection'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green[700]!,
              Colors.green[500]!,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_isCameraInitialized)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CameraPreview(_controller),
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Initializing camera...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Processing Image...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.camera_alt,
                    label: 'Capture',
                    onPressed: _isLoading ? null : _captureAndAnalyze,
                  ),
                  _buildActionButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onPressed: _isLoading ? null : _pickAndAnalyze,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: Colors.green[700],
          elevation: 2,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.green[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _captureAndAnalyze() async {
    await _captureImage();
    if (_image != null) {
      await _classifyImage(_image!);
      _navigateToResults();
    }
  }

  Future<void> _pickAndAnalyze() async {
    await _pickImage();
    if (_image != null) {
      await _classifyImage(_image!);
      _navigateToResults();
    }
  }

  void _navigateToResults() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImagePreview(
          image: _image!,
          message: _statusMessage,
          responseContent: aiResponse,
        ),
      ),
    );
  }
}