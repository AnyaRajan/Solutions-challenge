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

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final cameras = await availableCameras();
//   await dotenv.load(fileName: ".env");
//   runApp(MyApp(cameras: cameras));
// }

// class MyApp extends StatelessWidget {
//   final List<CameraDescription> cameras;
//   MyApp({Key? key, required this.cameras}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'TFLite Mobile Model Loader',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: ModelLoadingPage(cameras: cameras),
//     );
//   }
// }

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
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*'); // Matches **{word}**
    int currentIndex = 0;

    for (final match in boldRegex.allMatches(text)) {
      // Add the text before the match
      if (match.start > currentIndex) {
        textSpans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(color: Colors.black),
          ),
        );
      }

      // Add the bold text
      textSpans.add(
        TextSpan(
          text: match.group(1), // The text inside **{word}**
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );

      // Update the current index
      currentIndex = match.end;
    }

    // Add the remaining text
    if (currentIndex < text.length) {
      textSpans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return textSpans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soil Information')),
      body: Column(
        children: [
          Expanded(
            flex: 3, // 80% of the screen height
            child: SizedBox(
              width: 200, // Set your desired width
              height: 300, // Set your desired height
              child: Image.file(
                image,
                fit: BoxFit.cover, // Ensures the image covers the space
              ),
            ),
          ),
          Center(
            child: Text(
              message,
              style: const TextStyle(
                color: Color.fromARGB(255, 27, 26, 26),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 7, // 20% of the screen height
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: SingleChildScrollView(
                child: Center(
                  child: RichText(
                    text: TextSpan(children: _parseText(responseContent)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SoilApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const SoilApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soil Classifier',
      theme: _buildAppTheme(),
      home: SoilClassificationPage(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      colorScheme: ColorScheme.light(
        primary: Colors.green[800]!,
        secondary: Colors.amber[700]!,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.green[800],
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class SoilClassificationPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SoilClassificationPage({Key? key, required this.cameras})
      : super(key: key);

  @override
  State<SoilClassificationPage> createState() => _SoilClassificationPageState();
}

class _SoilClassificationPageState extends State<SoilClassificationPage> {
  late CameraController _cameraController;
  bool _isCameraReady = false;
  bool _isModelLoaded = false;
  bool _isProcessing = false;

  String _statusMessage = 'Initializing...';
  Interpreter? _interpreter;
  final int _numClasses = 4;
  final int _inputSize = 224;

  File? _capturedImage;
  String? _apiKey;
  GenerativeModel? _model;
  String _aiResponse = '';
  String _connectionStatus = 'Unknown';

  final List<String> _soilLabels = [
    'Alluvial soil',
    'Black Soil',
    'Clay soil',
    'Red soil',
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initializeCamera();
    await _loadModel();
    _apiKey = dotenv.env['GEMINI_API_KEY'];
    if (_apiKey != null) {
      _model = GenerativeModel(model: 'gemini-2.0-flash-001', apiKey: _apiKey!);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      if (widget.cameras.isEmpty) throw Exception('No cameras available');

      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
      );

      await _cameraController.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        _statusMessage = 'Ready to capture';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Camera error: ${e.toString()}';
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Loading model...';
      });

      _interpreter =
          await Interpreter.fromAsset('assets/soil_model_v1.5.tflite');

      setState(() {
        _isModelLoaded = true;
        _isProcessing = false;
        _statusMessage = 'Model loaded successfully';
      });
    } catch (e) {
      setState(() {
        _isModelLoaded = false;
        _isProcessing = false;
        _statusMessage = 'Model loading failed';
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _connectionStatus = result.contains(ConnectivityResult.none)
          ? "No internet connection"
          : "Connected";
    });
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady || _isProcessing || !_isModelLoaded) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController.takePicture();
      setState(() => _capturedImage = File(image.path));
      await _classifyImage(_capturedImage!);
    } catch (e) {
      setState(() => _statusMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _capturedImage = File(image.path);
        _isProcessing = true;
      });

      await _classifyImage(_capturedImage!);
    } catch (e) {
      setState(() => _statusMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _classifyImage(File image) async {
    try {
      final imageBytes = await image.readAsBytes();
      final imageTemp = img.decodeImage(imageBytes);
      if (imageTemp == null) throw Exception('Failed to decode image');

      final resizedImage = img.copyResize(
        imageTemp,
        width: _inputSize,
        height: _inputSize,
      );

      final input = _prepareImageInput(resizedImage);
      final output = List.filled(1 * _numClasses, 0).reshape([1, _numClasses]);

      _interpreter!.run(input, output);

      final prediction = _processOutput(output[0]);
      setState(() => _statusMessage = prediction);

      if (prediction != "Unable to determine soil type") {
        await _getSoilInfo(prediction);
      }

      if (mounted) {
        _navigateToResults();
      }
    } catch (e) {
      setState(() => _statusMessage = 'Classification error: ${e.toString()}');
    }
  }

  List<List<List<List<double>>>> _prepareImageInput(img.Image image) {
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (_) => List.generate(
          _inputSize,
          (_) => List.generate(3, (_) => 0.0),
        ),
      ),
    );

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        input[0][y][x][0] = pixel.r.toDouble();
        input[0][y][x][1] = pixel.g.toDouble();
        input[0][y][x][2] = pixel.b.toDouble();
      }
    }

    return input;
  }

  String _processOutput(List<double> output) {
    try {
      final maxScore = output.reduce((a, b) => a > b ? a : b);
      final predictedIndex = output.indexOf(maxScore);

      return maxScore > 0.65
          ? _soilLabels[predictedIndex]
          : "Unable to determine soil type";
    } catch (e) {
      return "Error processing results";
    }
  }

  Future<void> _getSoilInfo(String soilType) async {
    await _checkConnectivity();

    if (_connectionStatus == "No internet connection") {
      setState(() => _aiResponse = 'No internet connection');
      return;
    }

    try {
      final prompt =
          "List only the names of crops suitable for $soilType and its nutrient content. "
          "Provide concise bullet points without descriptions.";

      final response = await _model!.generateContent([Content.text(prompt)]);
      setState(() => _aiResponse = response.text ?? 'No information available');
    } catch (e) {
      setState(() => _aiResponse = 'Error fetching information');
    }
  }

  void _navigateToResults() {
    if (_capturedImage == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SoilResultsScreen(
          image: _capturedImage!,
          soilType: _statusMessage,
          soilInfo: _aiResponse,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soil Classifier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
          if (_capturedImage != null)
            TextButton.icon(
              onPressed: _navigateToResults,
              icon: Icon(Icons.visibility, color: Colors.white),
              label:
                  Text('View Results', style: TextStyle(color: Colors.white)),
            ),
        ],
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
            Expanded(
              child: _buildCameraPreview(),
            ),
            _buildControlPanel(),
          ],
        ),
      ),

    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isCameraReady)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CameraPreview(_cameraController),
            ),
          )
        else
          const Center(child: CircularProgressIndicator()),
        if (_isProcessing)
          Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing Soil...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.camera_alt,
                label: 'Capture',
                onPressed: _isProcessing ? null : _captureImage,
              ),
              _buildActionButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                onPressed: _isProcessing ? null : _pickImage,
              ),
            ],
          ),
        ],
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
        Container(
          decoration: BoxDecoration(
            color: onPressed == null
                ? Colors.grey[200]
                : Theme.of(context).primaryColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, size: 32),
            color: onPressed == null
                ? Colors.grey
                : Theme.of(context).primaryColor,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: onPressed == null
                ? Colors.grey
                : Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Soil Classifier'),
        content: const Text(
          'This app helps identify soil types using your camera and suggests suitable crops. '
          'Capture or upload an image of soil to get analysis and recommendations.',
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class SoilResultsScreen extends StatelessWidget {
  final File image;
  final String soilType;
  final String soilInfo;

  const SoilResultsScreen({
    Key? key,
    required this.image,
    required this.soilType,
    required this.soilInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soil Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildImagePreview(),
              _buildSoilTypeIndicator(),
              const SizedBox(height: 24),
              _buildSoilInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 250,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildSoilTypeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _getSoilColor(soilType),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        soilType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<TextSpan> _parseText(String text) {
    final List<TextSpan> textSpans = [];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*'); // Matches **{word}**
    int currentIndex = 0;

    for (final match in boldRegex.allMatches(text)) {
      // Add the text before the match
      if (match.start > currentIndex) {
        textSpans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(color: Colors.black),
          ),
        );
      }

      // Add the bold text
      textSpans.add(
        TextSpan(
          text: match.group(1), // The text inside **{word}**
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );

      // Update the current index
      currentIndex = match.end;
    }

    // Add the remaining text
    if (currentIndex < text.length) {
      textSpans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return textSpans;
  }

  Widget _buildSoilInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: Colors.green[800]),
              const SizedBox(width: 8),
              Text(
                'Crop Suggestions & Nutrients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color.fromARGB(255, 255, 255, 255),
            child: SingleChildScrollView(
              child: Center(
                child: RichText(
                  text: TextSpan(children: _parseText(soilInfo)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSoilColor(String soilType) {
    switch (soilType) {
      case 'Alluvial soil':
        return Colors.brown[600]!;
      case 'Black Soil':
        return Colors.grey[800]!;
      case 'Clay soil':
        return Colors.orange[800]!;
      case 'Red soil':
        return Colors.red[600]!;
      default:
        return Colors.green;
    }
  }
}
