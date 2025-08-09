import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
// import 'api.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraPermissionGranted = false;
  Position? _position;
  double? _pitch;
  double? _roll;
  double? _direction; // in degrees
  List<double>? _accelerometer;
  List<double>? _magnetometer;
  var data_init;
  String data = "12:00";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
    _getLocation();

    accelerometerEvents.listen((event) {
      setState(() {
        _accelerometer = [event.x, event.y, event.z];
        final ax = event.x;
        final ay = event.y;
        final az = event.z;
        final pitch = atan2(-ax, sqrt(ay * ay + az * az)) * 180 / pi;
        final roll = atan2(ay, az) * 180 / pi;
        _pitch = pitch;
        _roll = roll;
      });
      _updateAzimuth();
    });

    magnetometerEvents.listen((event) {
      setState(() {
        _magnetometer = [event.x, event.y, event.z];
      });
      _updateAzimuth();
    });
  }

  void _updateAzimuth() {
    if (_accelerometer != null && _magnetometer != null) {
      final ax = _accelerometer![0];
      final ay = _accelerometer![1];
      final az = _accelerometer![2];
      final mx = _magnetometer![0];
      final my = _magnetometer![1];
      final mz = _magnetometer![2];

      // Normalize accelerometer vector
      final normA = sqrt(ax * ax + ay * ay + az * az);
      final axn = ax / normA;
      final ayn = ay / normA;
      final azn = az / normA;

      // Normalize magnetometer vector
      final normM = sqrt(mx * mx + my * my + mz * mz);
      final mxn = mx / normM;
      final myn = my / normM;
      final mzn = mz / normM;

      // Calculate horizontal component of magnetic field
      final hx = myn * azn - mzn * ayn;
      final hy = mzn * axn - mxn * azn;

      // Calculate azimuth (compass heading)
      double azimuth = atan2(hy, hx) * 180 / pi;
      if (azimuth < 0) azimuth += 360;
      setState(() {
        _direction = azimuth;
      });
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Ask user to turn on location
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services (GPS)')),
        );
      }
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition();
    setState(() => _position = pos);
  }

  Future<void> _setup() async {
    await _requestPermission();
    if (!_isCameraPermissionGranted) return;
    await _initCamera();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isCameraPermissionGranted = true);
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller?.dispose();
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off); // <-- Ensure flash is off
      _controller = controller;
      _initializeControllerFuture = Future.value();
      setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null) return;
    try {
      await _initializeControllerFuture;
      if (!_controller!.value.isInitialized || _controller!.value.isTakingPicture) return;
      final file = await _controller!.takePicture();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Picture taken')),
      );
      await uploadImageToApi(file.path); // <-- Upload to API
    } catch (e) {
      debugPrint('Take picture error: $e');
    }
  }

  // Call this after taking the picture
  Future<void> uploadImageToApi(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final imgBase64 = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('http://10.228.187.45:5000/detect_sun'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image_base64': imgBase64}),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      // result['sun_detected'], result['center'], result['annotated_image_base64']
      print("result: ${result['sun_detected']}");
      // You can display result['annotated_image_base64'] as an image in Flutter
    } else {
      print('API error: ${response.body}');
    }
  }

  String getDirectionLabel() {
    if (_direction == null) return '';
    final deg = _direction!;
    if (deg >= 337.5 || deg < 22.5) return 'North';
    if (deg >= 22.5 && deg < 67.5) return 'North-East';
    if (deg >= 67.5 && deg < 112.5) return 'East';
    if (deg >= 112.5 && deg < 157.5) return 'South-East';
    if (deg >= 157.5 && deg < 202.5) return 'South';
    if (deg >= 202.5 && deg < 247.5) return 'South-West';
    if (deg >= 247.5 && deg < 292.5) return 'West';
    return 'North-West';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraPermissionGranted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: Center(
          child: ElevatedButton(
            onPressed: _requestPermission,
            child: const Text('Grant Camera Permission'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Sun Dial',
          style: TextStyle(
            fontWeight: FontWeight.bold, // <-- Make title bold
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Camera preview with button overlay
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _initializeControllerFuture == null
                    ? const Center(child: CircularProgressIndicator())
                    : FutureBuilder(
                        future: _initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            final controller = _controller;
                            if (controller == null || !controller.value.isInitialized) {
                              return const Center(child: Text('Camera not available', style: TextStyle(color: Colors.white)));
                            }
                            return CameraPreview(controller);
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                            );
                          }
                          return const Center(child: CircularProgressIndicator());
                        },
                      ),
                // Add this widget for "12:00" text at the top
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      data,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Camera button overlay
                Positioned(
                  bottom: 45,
                  child: FloatingActionButton(
                    backgroundColor: Colors.black,
                    onPressed: _takePicture,
                    child: const Icon(Icons.camera, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Fixed size container for info text
          Container(
            color: Colors.black,
            height: 100,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    (_position != null) ?
                    'Lat: ${_position!.latitude} Lng: ${_position!.longitude}' : '',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              
                Center(
                  child: Text(
                    (_pitch != null && _roll != null) ?
                    'Pitch: ${_pitch!.toStringAsFixed(1)}°  Roll: ${_roll!.toStringAsFixed(1)}°' : '',
                    style: const TextStyle(color: Colors.yellow, fontSize: 16),
                  ),
                ),
                
                Center(
                  child: Text(
                    _direction != null
                        ? 'Direction: ${getDirectionLabel()} (${_direction!.toStringAsFixed(0)}°)'
                        : 'Direction: Unknown',
                    style: const TextStyle(color: Colors.cyan, fontSize: 18),
                  ),
                ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }
}