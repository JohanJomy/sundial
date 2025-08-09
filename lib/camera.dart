import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _lastPicture;
  bool _isCameraPermissionGranted = false;
  Position? _position;
  double? _pitch;
  double? _roll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
    _getLocation();
    accelerometerEvents.listen((event) {
      // Calculate pitch and roll from accelerometer data
      final ax = event.x;
      final ay = event.y;
      final az = event.z;
      final pitch = atan2(-ax, sqrt(ay * ay + az * az)) * 180 / pi;
      final roll = atan2(ay, az) * 180 / pi;
      setState(() {
        _pitch = pitch;
        _roll = roll;
      });
    });
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
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
      _controller = controller;
      _initializeControllerFuture = controller.initialize();
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
      setState(() => _lastPicture = file);
    } catch (e) {
      debugPrint('Take picture error: $e');
    }
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
      appBar: AppBar(title: const Text('Camera')),
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
                // Camera button overlay
                Positioned(
                  bottom: 45,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    onPressed: _takePicture,
                    child: const Icon(Icons.camera, color: Colors.black),
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
                if (_lastPicture != null)
                  Row(
                    children: [
                      Image.file(File(_lastPicture!.path), height: 40),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastPicture!.path.split('/').last,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, color: Colors.white),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: Image.file(File(_lastPicture!.path)),
                            ),
                          );
                        },
                      )
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
