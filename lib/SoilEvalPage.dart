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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  await dotenv.load(fileName: ".env");
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TFLite Mobile Model Loader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ModelLoadingPage(cameras: cameras),
    );
  }
}

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
              color: const Color.fromARGB(255, 239, 237, 167),
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

class ModelLoadingPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ModelLoadingPage({Key? key, required this.cameras}) : super(key: key);

  @override
  _ModelLoadingPageState createState() => _ModelLoadingPageState();
}

class _ModelLoadingPageState extends State<ModelLoadingPage> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  bool _isLoaded = false;
  bool _isLoading = false;

  String _statusMessage = 'Model not loaded';
  String _errorMessage = '';
  Interpreter? _interpreter;
  int num_classes = 4;
  String predictedLabel = "Unable to Detect";

  String? apiKey = dotenv.env['GEMINI_API_KEY'];

  GenerativeModel? model;
  String aiResponse = '';

  File? _image;

  // Add a list of labels corresponding to the output classes
  List<String> labels = [
    'Alluvial soil',
    'Black Soil',
    'Clay soil',
    'Red soil',
  ];

  // to check connection
  String _connectionStatus = 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadModel();
    initializeCamera();
    if (apiKey == null) {
      print('No \$API_KEY environment variable');
      exit(1);
    }
    model = GenerativeModel(model: 'gemini-2.0-flash-001', apiKey: apiKey!);
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

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
        'assets/soil_model_v1.5.tflite',
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

      var input = imageToByteListFloat32(resizedImage, 160);

      var inputTensor = input.reshape([1, 160, 160, 3]);

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
          "list only name of all the crops that can be grown in $label and nutrient content of $label. any description is not required even about the soil.";
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soil Information')),
      body: Column(
        children: [
          // Camera Preview
          Expanded(
            child:
                _isCameraInitialized
                    ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CameraPreview(_controller),
                    )
                    : const Center(child: Text('Initializing camera...')),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () async {
                            await _captureImage();

                            if (_image != null) {
                              await _classifyImage(_image!);

                              print(_statusMessage);

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ImagePreview(
                                        image: _image!,
                                        message: _statusMessage,
                                        responseContent: aiResponse,
                                      ),
                                ),
                              );
                            }
                          },
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.camera),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton(
                  onPressed: () async {
                    await _pickImage();
                    if (_image != null) {
                      await _classifyImage(_image!);

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => ImagePreview(
                                image: _image!,
                                message: _statusMessage,
                                responseContent: aiResponse,
                              ),
                        ),
                      );
                    }
                  },
                  child: const Icon(Icons.image),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
