import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../services/media_permissions_service.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  int _filterIndex = 0;
  bool _isInitializing = true;
  bool _isRecording = false;
  String? _lastCaptureLabel;

  static const _filters = [
    ('Original', <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]),
    ('Warm', <double>[1.1, 0, 0, 0, 12, 0, 0.96, 0, 0, 2, 0, 0, 0.85, 0, -4, 0, 0, 0, 1, 0]),
    ('Cool', <double>[0.9, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1.15, 0, 8, 0, 0, 0, 1, 0]),
    ('Vivid', <double>[1.25, 0, 0, 0, -18, 0, 1.15, 0, 0, -8, 0, 0, 1.1, 0, -6, 0, 0, 0, 1, 0]),
    ('Noir', <double>[0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0]),
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera({int? cameraIndex}) async {
    if (!await MediaPermissionsService.requestCamera()) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw StateError('No camera found');
      _cameraIndex = cameraIndex ?? _cameraIndex;
      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      await _controller?.dispose();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isInitializing = false);
      _showError('Camera could not start: $error');
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isRecording) return;
    try {
      await controller.takePicture();
      if (mounted) setState(() => _lastCaptureLabel = 'Photo captured');
    } on CameraException catch (error) {
      _showError(error.description ?? 'Photo capture failed');
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isRecording) return;
    if (!await MediaPermissionsService.requestMicrophone()) return;
    try {
      await controller.startVideoRecording();
      if (mounted) setState(() => _isRecording = true);
    } on CameraException catch (error) {
      _showError(error.description ?? 'Video recording failed to start');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecording) return;
    try {
      await controller.stopVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _lastCaptureLabel = 'Video captured';
        });
      }
    } on CameraException catch (error) {
      if (mounted) setState(() => _isRecording = false);
      _showError(error.description ?? 'Video recording failed');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    setState(() => _isInitializing = true);
    await _initializeCamera(cameraIndex: (_cameraIndex + 1) % _cameras.length);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filters[_filterIndex];
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              ColorFiltered(
                colorFilter: ColorFilter.matrix(filter.$2),
                child: CameraPreview(controller),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _roundButton(Icons.close_rounded, () => Navigator.pop(context)),
                  if (_isRecording)
                    const Text('REC', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  _roundButton(Icons.flip_camera_ios_rounded, _switchCamera),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                children: [
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _filters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, index) => GestureDetector(
                        onTap: () => setState(() => _filterIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: index == _filterIndex ? Colors.white : Colors.black54,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _filters[index].$1,
                            style: TextStyle(color: index == _filterIndex ? Colors.black : Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _takePhoto,
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecording(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _isRecording ? 84 : 72,
                      height: _isRecording ? 84 : 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.redAccent : Colors.white,
                        border: Border.all(color: Colors.white70, width: 5),
                      ),
                      child: _isRecording ? const Icon(Icons.stop_rounded, color: Colors.white, size: 38) : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording ? 'Release to stop' : 'Tap photo  |  Hold video',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (_lastCaptureLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(_lastCaptureLabel!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (_isInitializing)
              Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onPressed) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      child: IconButton(onPressed: onPressed, icon: Icon(icon, color: Colors.white)),
    );
  }
}
