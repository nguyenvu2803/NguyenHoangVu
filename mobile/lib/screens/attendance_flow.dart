import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/common.dart';

Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw ApiException('Bật GPS trong cài đặt thiết bị để tiếp tục.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw ApiException(
      'Quyền vị trí đã bị chặn. Mở cài đặt ứng dụng để cấp lại.',
    );
  }
  if (permission == LocationPermission.denied) {
    throw ApiException('Cần quyền vị trí để xác nhận bạn đang ở văn phòng.');
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 18),
    ),
  );
  if (position.isMocked) throw ApiException('Không chấp nhận vị trí giả lập.');
  if (position.accuracy > 100) {
    throw ApiException(
      'GPS chưa đủ chính xác. Đến gần cửa sổ hoặc ra ngoài rồi thử lại.',
    );
  }
  return position;
}

Future<void> attendanceFlow(BuildContext context, Workspace data) async {
  if (data.todayAssignment == null && !data.api.demo) {
    toast(context, 'Bạn chưa được phân ca hôm nay. Liên hệ quản trị viên.');
    return;
  }
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: paper,
    builder: (_) => _AttendanceFlow(data: data),
  );
  if (result == true) {
    await data.reload();
    if (context.mounted) {
      toast(context, 'Chấm công thành công. Chúc bạn một ngày thật tốt!');
    }
  }
}

class _AttendanceFlow extends StatefulWidget {
  final Workspace data;
  const _AttendanceFlow({required this.data});
  @override
  State<_AttendanceFlow> createState() => _AttendanceFlowState();
}

class _AttendanceFlowState extends State<_AttendanceFlow> {
  bool busy = false;
  Position? position;
  String? qr, error;
  Future<void> locate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await currentPosition();
      if (mounted) setState(() => position = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (mounted && value != null) setState(() => qr = value);
  }

  Future<void> submit() async {
    final d = widget.data;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!d.api.demo && (position == null || qr == null)) {
        throw ApiException('Xác nhận vị trí và quét QR trước khi chấm công.');
      }
      // Refresh GPS immediately before submitting; never reuse a stale location fix.
      if (!d.api.demo) position = await currentPosition();
      await d.api.request(
        'POST',
        d.todayAttendance == null
            ? '/attendance/check-in'
            : '/attendance/check-out',
        {
          'latitude': position?.latitude ?? 10.7769,
          'longitude': position?.longitude ?? 106.7009,
          'accuracy': position?.accuracy ?? 10,
          'qr_token': qr ?? 'DEMO-QR-NOT-VALID-ON-SERVER',
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      26,
      10,
      26,
      28 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.data.todayAttendance == null
                  ? 'Bắt đầu một ngày tốt.'
                  : 'Kết thúc ca làm việc.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              widget.data.todayBranch?['name'] ?? 'Văn phòng của bạn',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 25),
            if (widget.data.api.demo)
              const Panel(
                color: mint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tag('MÔ PHỎNG CHẤM CÔNG', icon: Icons.science_outlined),
                    SizedBox(height: 12),
                    Text(
                      'Bản demo bỏ qua GPS và QR. Dữ liệu chỉ tồn tại trong phiên chạy, không gửi lên máy chủ.',
                    ),
                  ],
                ),
              ),
            if (!widget.data.api.demo) ...[
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '01 / XÁC NHẬN VỊ TRÍ',
                      style: TextStyle(
                        fontSize: 10,
                        color: muted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      position == null
                          ? 'Bạn đang ở văn phòng?'
                          : '${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)} · ±${position!.accuracy.round()}m',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : locate,
                      icon: Icon(
                        position == null
                            ? Icons.my_location
                            : Icons.check_circle_outline,
                        size: 17,
                      ),
                      label: Text(
                        position == null ? 'Lấy vị trí GPS' : 'Cập nhật vị trí',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '02 / QUÉT QR VĂN PHÒNG',
                      style: TextStyle(
                        fontSize: 10,
                        color: muted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      qr == null
                          ? 'Mã do quản trị viên hiển thị, hiệu lực 45 giây.'
                          : 'Đã nhận QR. Chấm công ngay trước khi mã hết hạn.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : scan,
                      icon: const Icon(Icons.qr_code_scanner, size: 17),
                      label: Text(
                        qr == null ? 'Mở camera quét mã' : 'Quét lại QR',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : submit,
                icon: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  busy
                      ? 'Đang xác nhận…'
                      : widget.data.api.demo
                      ? 'Mô phỏng chấm công'
                      : 'Xác nhận chấm công',
                ),
              ),
            ),
            const SizedBox(height: 13),
            const Text(
              'Vị trí chấm công chỉ được ghi tại thời điểm xác nhận. Chia sẻ vị trí là lựa chọn riêng trong Hồ sơ.',
              style: TextStyle(fontSize: 10, color: muted, height: 1.8),
            ),
          ],
        ),
      ),
    ),
  );
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool done = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ink,
    appBar: AppBar(
      title: const Text('Quét QR chấm công'),
      actions: [
        IconButton(
          tooltip: 'Đèn flash',
          onPressed: kIsWeb ? null : controller.toggleTorch,
          icon: const Icon(Icons.flashlight_on_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (done || value == null || value.length < 20) return;
              done = true;
              Navigator.pop(context, value);
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  'Không mở được camera. Cấp quyền camera trong cài đặt rồi thử lại.\n${error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'Đưa QR của văn phòng vào khung hình.\nMã tự đổi sau 45 giây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.8),
          ),
        ),
      ],
    ),
  );
}
