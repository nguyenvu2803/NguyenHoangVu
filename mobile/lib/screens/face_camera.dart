import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../core/api.dart';
import '../core/live.dart' show faceImageBase64;

Uint8List prepareFacePhoto((Uint8List, bool) input) {
  final decoded = img.decodeImage(input.$1);
  if (decoded == null) throw ApiException('Không đọc được ảnh camera.');
  var photo = img.bakeOrientation(decoded);
  if (input.$2) photo = img.flipHorizontal(photo);
  if (photo.width > 1024 || photo.height > 1024) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 1024 : null,
      height: photo.height > photo.width ? 1024 : null,
    );
  }
  return Uint8List.fromList(img.encodeJpg(photo, quality: 85));
}

Future<String?> captureFace(BuildContext context, {bool mirror = true}) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => FaceCameraPage(mirror: mirror)),
    );

class FaceCameraPage extends StatefulWidget {
  final bool mirror;
  const FaceCameraPage({super.key, this.mirror = true});
  @override
  State<FaceCameraPage> createState() => _FaceCameraPageState();
}

class _FaceCameraPageState extends State<FaceCameraPage>
    with WidgetsBindingObserver {
  CameraController? controller;
  bool busy = false, opening = false;
  bool foreground = true;
  int cameraEpoch = 0;
  late bool mirror = widget.mirror;
  Uint8List? photo;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    openCamera();
  }

  Future<void> openCamera() async {
    if (opening || controller != null || !foreground) return;
    opening = true;
    final epoch = cameraEpoch;
    CameraController? next;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw ApiException('Thiết bị không có camera.');
      final camera =
          cameras
              .where((c) => c.lensDirection == CameraLensDirection.front)
              .firstOrNull ??
          cameras.first;
      next = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted || !foreground || epoch != cameraEpoch) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        error = null;
      });
    } on CameraException catch (e) {
      await next?.dispose();
      if (mounted) {
        setState(
          () => error = e.code.contains('AccessDenied')
              ? 'Cấp quyền Camera trong Cài đặt Android rồi thử lại.'
              : 'Không mở được camera (${e.code}). Đóng ứng dụng khác đang dùng camera rồi thử lại.',
        );
      }
    } catch (_) {
      await next?.dispose();
      if (mounted) {
        setState(
          () => error =
              'Camera chưa sẵn sàng. Kiểm tra camera thiết bị rồi thử lại.',
        );
      }
    } finally {
      opening = false;
      if (mounted && foreground && epoch != cameraEpoch) openCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      foreground = false;
      cameraEpoch++;
      final previous = controller;
      controller = null;
      previous?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      foreground = true;
      openCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  Future<void> shoot() async {
    final camera = controller;
    if (busy || camera == null || !camera.value.isInitialized) return;
    setState(() {
      busy = true;
      error = null;
    });
    XFile? file;
    try {
      file = await camera.takePicture();
      final bytes = await compute(prepareFacePhoto, (
        await file.readAsBytes(),
        mirror,
      ));
      if (mounted) setState(() => photo = bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Chưa chụp được ảnh. Thử lại khi camera đã sẵn sàng.',
        );
      }
    } finally {
      if (file != null) {
        try {
          await File(file.path).delete();
        } catch (_) {
          /* Temporary photo may already be removed. */
        }
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = controller;
    final front =
        camera?.description.lensDirection == CameraLensDirection.front;
    return Scaffold(
      appBar: AppBar(title: const Text('Quét khuôn mặt')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Đưa một khuôn mặt vào giữa khung, nhìn thẳng và chọn nơi đủ sáng.',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: photo != null
                      ? Image.memory(photo!, fit: BoxFit.contain)
                      : camera?.value.isInitialized == true
                      // CameraX already mirrors front preview. Captured JPEG is normalized separately.
                      ? Transform.flip(
                          flipX: mirror != front,
                          child: CameraPreview(camera!),
                        )
                      : error == null
                      ? const CircularProgressIndicator()
                      : const Icon(
                          Icons.no_photography_outlined,
                          color: Colors.white,
                          size: 64,
                        ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (photo == null)
              SwitchListTile(
                title: const Text('Đối xứng như gương'),
                value: mirror,
                onChanged: busy ? null : (v) => setState(() => mirror = v),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (photo != null) ...[
                    OutlinedButton(
                      onPressed: () => setState(() => photo = null),
                      child: const Text('Chụp lại'),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, faceImageBase64(photo!)),
                      icon: const Icon(Icons.check),
                      label: const Text('Dùng ảnh này'),
                    ),
                  ] else if (error != null && camera == null)
                    FilledButton(
                      onPressed: openCamera,
                      child: const Text('Thử lại camera'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: busy || camera == null ? null : shoot,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(busy ? 'Đang chụp…' : 'Chụp khuôn mặt'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
