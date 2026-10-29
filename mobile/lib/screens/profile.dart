import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/common.dart';
import 'attendance_flow.dart';

class ProfilePage extends StatefulWidget {
  final Workspace data;
  const ProfilePage({super.key, required this.data});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool busy = false;
  bool sharing = false;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          eyebrow: 'Tài khoản & kết nối',
          title: 'Góc của bạn.',
          subtitle: 'Thông tin cá nhân, bảo mật và chia sẻ vị trí.',
        ),
        Panel(
          child: Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: mint,
                child: Text(
                  initials(d.user['name']),
                  style: const TextStyle(
                    color: forest,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.user['name'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      d.user['email'],
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 9),
                    Tag(roleName(d.user['role'])),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            children: [
              _info(Icons.work_outline, 'Chức danh', d.user['title']),
              _info(
                Icons.apartment_outlined,
                'Phòng ban',
                d.user['department'],
              ),
              _info(
                Icons.phone_outlined,
                'Điện thoại',
                d.user['phone'].toString().isEmpty
                    ? 'Chưa cập nhật'
                    : d.user['phone'],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.face_retouching_natural, color: forest),
                  SizedBox(width: 10),
                  Text(
                    'Đăng nhập sinh trắc học',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              const Text(
                'Đăng nhập bằng OTP trước, sau đó bật Face ID hoặc vân tay đã đăng ký trên thiết bị. Dữ liệu khuôn mặt và vân tay do hệ điều hành quản lý.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.8),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await d.session.enableBiometrics();
                            if (context.mounted) {
                              toast(
                                context,
                                'Đã bật sinh trắc học. Khóa ứng dụng để thử đăng nhập lại.',
                              );
                            }
                          }),
                    icon: const Icon(Icons.fingerprint, size: 19),
                    label: const Text('Bật Face ID / vân tay'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => run(d.session.lock),
                    icon: const Icon(Icons.lock_outline, size: 17),
                    label: const Text('Khóa ứng dụng'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!d.session.isCustomer) ...[
          const SizedBox(height: 20),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: forest),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chia sẻ vị trí chủ động',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                const Text(
                  'Gửi vị trí hiện tại cho quản trị viên trong 1 giờ. Không theo dõi nền. Bạn có thể dừng chia sẻ bất kỳ lúc nào.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.8),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              if (d.api.demo) {
                                throw ApiException(
                                  'Chia sẻ vị trí thật cần kết nối API đã deploy.',
                                );
                              }
                              final p = await currentPosition();
                              await d.api.request('POST', '/locations/share', {
                                'latitude': p.latitude,
                                'longitude': p.longitude,
                                'accuracy': p.accuracy,
                              });
                              if (mounted) setState(() => sharing = true);
                              if (context.mounted) {
                                toast(
                                  context,
                                  'Đã chia sẻ vị trí trong 1 giờ.',
                                );
                              }
                            }),
                      icon: const Icon(Icons.near_me_outlined, size: 17),
                      label: Text(
                        sharing ? 'Cập nhật vị trí' : 'Chia sẻ trong 1 giờ',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              await d.api.request('DELETE', '/locations/share');
                              if (mounted) setState(() => sharing = false);
                              if (context.mounted) {
                                toast(context, 'Đã dừng chia sẻ vị trí.');
                              }
                            }),
                      child: const Text('Dừng chia sẻ'),
                    ),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              if (d.api.demo) {
                                throw ApiException(
                                  'Mở bản Android/iOS hoặc web HTTPS để lấy vị trí thật.',
                                );
                              }
                              final p = await currentPosition();
                              if (!context.mounted) return;
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              await SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      'Vị trí hiện tại của tôi: https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}',
                                  sharePositionOrigin: box == null
                                      ? null
                                      : box.localToGlobal(Offset.zero) &
                                            box.size,
                                ),
                              );
                            }),
                      icon: const Icon(Icons.ios_share, size: 17),
                      label: const Text('Chia sẻ liên kết bản đồ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (d.api.demo) ...[
          const SizedBox(height: 20),
          Panel(
            color: const Color(0xFFFAF0E4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Tag('KHÔNG GIAN DEMO', color: Color(0xFFA66B36)),
                const SizedBox(height: 12),
                const Text(
                  'Đổi vai trò để xem giao diện. Dữ liệu mẫu chỉ lưu trong phiên chạy.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in {
                      0: 'Nhân viên',
                      1: 'Quản trị viên',
                      2: 'Khách hàng',
                    }.entries)
                      OutlinedButton(
                        onPressed: () => d.session.enterDemo(e.key),
                        child: Text(e.value),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 25),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  if (!await confirm(
                    context,
                    'Đăng xuất tài khoản?',
                    'Phiên đăng nhập thiết bị và quyền mở lại bằng sinh trắc học sẽ bị thu hồi.',
                  )) {
                    return;
                  }
                  await run(d.session.logout);
                },
          icon: const Icon(Icons.logout, size: 17),
          label: const Text('Đăng xuất'),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 25),
        const Text(
          'NguyenHoangVu · Workroom 1.0.0\nLiên hệ quản trị viên để chỉnh thông tin hoặc cấp quyền nhân viên.',
          style: TextStyle(fontSize: 10, height: 1.8, color: muted),
        ),
      ],
    );
  }

  Widget _info(IconData icon, String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Icon(icon, size: 20, color: muted),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class CustomerPage extends StatelessWidget {
  final Workspace data;
  const CustomerPage({super.key, required this.data});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageTitle(
        eyebrow: 'Không gian khách hàng',
        title: 'Chào ${data.user['name'].toString().split(' ').last}.',
        subtitle: 'Tài khoản của bạn đã được xác thực.',
      ),
      Panel(
        color: mint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.waving_hand_outlined, size: 45, color: forest),
            const SizedBox(height: 25),
            const Text(
              'Kết nối bắt đầu từ đây.',
              style: TextStyle(fontFamily: 'Lora', fontSize: 29),
            ),
            const SizedBox(height: 15),
            const Text(
              'Bạn đang sử dụng tài khoản khách hàng. Nếu bạn là nhân viên, liên hệ quản trị viên để được cấp quyền và phân ca làm việc.',
              style: TextStyle(height: 1.9, color: muted),
            ),
            const SizedBox(height: 22),
            Tag(data.user['email'], icon: Icons.verified_outlined),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Panel(
        child: EmptyState(
          'Hồ sơ của bạn luôn sẵn sàng',
          'Mở mục Hồ sơ để xem thông tin và thiết lập bảo mật.',
          icon: Icons.person_outline,
        ),
      ),
    ],
  );
}
