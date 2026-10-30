import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/preferences.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'face_camera.dart';

class SettingsPage extends StatefulWidget {
  final Session session;
  const SettingsPage({super.key, required this.session});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final form = GlobalKey<FormState>();
  late final fullName = TextEditingController(
    text: widget.session.user?['fullName'],
  );
  late final phone = TextEditingController(
    text: widget.session.user?['phone'] ?? '',
  );
  late final bio = TextEditingController(
    text: widget.session.user?['bio'] ?? '',
  );
  Json face = {};
  bool busy = false, loading = true, localFace = false;
  bool quickFaceLogin = false;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(sessionChanged);
    loadFace();
  }

  void sessionChanged() {
    if (widget.session.user == null && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> loadFace() async {
    try {
      final status = Json.from(
        await widget.session.api.request('GET', '/face/status'),
      );
      final saved = await widget.session.savedFaceAccount();
      final quick = await widget.session.supportsQuickFaceLogin();
      if (mounted) {
        setState(() {
          face = status;
          localFace = saved?['username'] == widget.session.user?['username'];
          quickFaceLogin = quick;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(sessionChanged);
    fullName.dispose();
    phone.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> enroll() async {
    await run(() async {
      final quick = await widget.session.supportsQuickFaceLogin();
      if (!mounted) return;
      setState(() => quickFaceLogin = quick);
      if (!await confirm(
        context,
        quick
            ? 'Bật đăng nhập khuôn mặt trên thiết bị này?'
            : 'Đăng ký khuôn mặt và OTP email?',
        quick
            ? 'Ảnh được gửi qua HTTPS để tạo mẫu khuôn mặt. Lần sau có thể quét mặt để đăng nhập, không cần mật khẩu hoặc OTP trên thiết bị đã thiết lập. Nhận diện ảnh 2D có thể bị giả mạo bằng ảnh, chưa có kiểm tra người thật. Chỉ bật nếu bạn chấp nhận giới hạn này. Chụp lại sẽ thay khóa thiết bị cũ.'
            : 'Ảnh được gửi qua HTTPS để tạo mẫu khuôn mặt. Lần sau nhập tên đăng nhập, quét mặt rồi nhập OTP email. API hiện tại vẫn yêu cầu OTP. Nhận diện ảnh 2D có thể bị giả mạo bằng ảnh, chưa có kiểm tra người thật. Chụp lại sẽ thay mẫu khuôn mặt cũ.',
      )) {
        return;
      }
      if (!mounted) return;
      final image = await captureFace(
        context,
        mirror: widget.session.preferences.mirrorCamera,
      );
      if (image == null) return;
      await widget.session.enrollFace(image, quickLogin: quick);
      await loadFace();
      if (mounted) {
        toast(
          context,
          quick
              ? 'Đã thiết lập. Lần sau chọn Đăng nhập bằng khuôn mặt.'
              : 'Đã đăng ký mặt. Lần sau quét mặt rồi nhập OTP email.',
        );
      }
    });
  }

  Future<void> saveProfile() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      await widget.session.updateProfile({
        'fullName': fullName.text.trim(),
        'phone': phone.text.trim(),
        'bio': bio.text.trim(),
      });
      if (mounted) toast(context, 'Đã cập nhật hồ sơ.');
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session.preferences,
    builder: (context, _) {
      final preferences = widget.session.preferences;
      return Scaffold(
        appBar: AppBar(title: const Text('Cài đặt')),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (busy || loading) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giao diện của bạn',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cỡ chữ · ${(preferences.fontScale * 100).round()}%',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in {
                            .85: 'Nhỏ',
                            1.0: 'Chuẩn',
                            1.15: 'Lớn',
                            1.3: 'Rất lớn',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: preferences.fontScale == entry.key,
                              onSelected: (_) => run(
                                () => preferences.update(scale: entry.key),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Màu nền'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in {
                            'mint': 'Lá nhạt',
                            'sand': 'Cát ấm',
                            'sky': 'Xanh trời',
                            'rose': 'Hồng nhạt',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              avatar: CircleAvatar(
                                backgroundColor:
                                    AppPreferences.backgrounds[entry.key],
                                radius: 9,
                              ),
                              selected: preferences.background == entry.key,
                              onSelected: (_) => run(
                                () => preferences.update(color: entry.key),
                              ),
                            ),
                        ],
                      ),
                      Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Camera đối xứng'),
                          subtitle: const Text(
                            'Xem trước và ảnh xác nhận như nhìn gương.',
                          ),
                          value: preferences.mirrorCamera,
                          onChanged: (v) =>
                              run(() => preferences.update(mirror: v)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => run(
                          () => preferences.update(
                            scale: 1,
                            color: 'mint',
                            mirror: true,
                          ),
                        ),
                        child: const Text('Khôi phục giao diện mặc định'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đăng nhập bằng khuôn mặt',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        !quickFaceLogin
                            ? face['enrolled'] == true
                                  ? 'Đã đăng ký mặt. Ở màn đăng nhập, nhập tên đăng nhập, quét mặt rồi nhập OTP email.'
                                  : 'Đăng nhập mật khẩu + OTP rồi thiết lập khuôn mặt. API này dùng khuôn mặt + OTP email.'
                            : face['quickLoginEnabled'] == true && localFace
                            ? 'Đã bật trên thiết bị này. Đăng xuất rồi chọn Đăng nhập bằng khuôn mặt để thử.'
                            : 'Đăng nhập mật khẩu và OTP trước. Sau đó thiết lập khuôn mặt để lần sau vào bằng camera.',
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ảnh 2D chưa kiểm tra người thật. Có thể xóa mẫu và khóa thiết bị tại đây.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      if (face['canEnrollQuickLogin'] == false)
                        const Text(
                          'Phiên này đăng nhập bằng khuôn mặt. Đăng xuất và dùng mật khẩu + OTP để thiết lập lại.',
                        ),
                      FilledButton.icon(
                        onPressed:
                            loading || face['canEnrollQuickLogin'] == false
                            ? null
                            : enroll,
                        icon: const Icon(Icons.face_retouching_natural),
                        label: Text(
                          face['enrolled'] == true
                              ? 'Thiết lập lại khuôn mặt'
                              : 'Thiết lập khuôn mặt',
                        ),
                      ),
                      if (face['enrolled'] == true)
                        TextButton.icon(
                          onPressed: () => run(() async {
                            if (!await confirm(
                              context,
                              'Xóa đăng nhập khuôn mặt?',
                              quickFaceLogin
                                  ? 'Mẫu khuôn mặt, khóa thiết bị và các phiên mở bằng khuôn mặt sẽ bị thu hồi. Dùng mật khẩu và OTP để vào lại.'
                                  : 'Mẫu khuôn mặt sẽ bị xóa. Dùng mật khẩu và OTP để đăng nhập; có thể đăng ký mặt lại sau.',
                            )) {
                              return;
                            }
                            await widget.session.api.request(
                              'DELETE',
                              '/face/enroll',
                            );
                            await widget.session.forgetFaceDevice();
                            await loadFace();
                          }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Xóa mẫu khuôn mặt'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Panel(
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cập nhật hồ sơ',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.session.user?['username']} · ${widget.session.user?['email']}',
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: fullName,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                          ),
                          validator: (v) => (v?.trim().length ?? 0) < 2
                              ? 'Họ tên tối thiểu 2 ký tự'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phone,
                          maxLength: 20,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                          ),
                          validator: (v) =>
                              RegExp(r'^[+()0-9 .-]*$').hasMatch(v ?? '')
                              ? null
                              : 'Số điện thoại chưa hợp lệ',
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: bio,
                          maxLength: 300,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Giới thiệu',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: saveProfile,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Lưu hồ sơ'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );
}
