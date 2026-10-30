import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'face_camera.dart';

class AuthScreen extends StatefulWidget {
  final Session session;
  const AuthScreen({super.key, required this.session});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(), password = TextEditingController();
  final email = TextEditingController(),
      name = TextEditingController(),
      code = TextEditingController();
  bool register = false, busy = false, obscure = true;
  Json? challenge;
  String? error;
  DateTime? resendAt;
  Timer? timer;
  int get seconds =>
      (DateTime.tryParse(
                challenge?['expiresAt'] ?? '',
              )?.difference(widget.session.api.serverNow).inSeconds ??
              0)
          .clamp(0, 3600);
  int get cooldown =>
      (resendAt?.difference(widget.session.api.serverNow).inSeconds ?? 0).clamp(
        0,
        3600,
      );
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && challenge != null) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [username, password, email, name, code]) {
      c.dispose();
    }
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

  void setChallenge(dynamic value) {
    if (!mounted) return;
    setState(() {
      challenge = Json.from(value);
      resendAt = widget.session.api.serverNow.add(
        Duration(
          seconds: (challenge!['retryAfterSeconds'] as num?)?.toInt() ?? 60,
        ),
      );
      code.clear();
    });
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      final api = widget.session.api;
      if (challenge != null) {
        final result = await api.request('POST', '/auth/verify-otp', {
          'challengeId': challenge!['challengeId'],
          'code': code.text.trim(),
        });
        await widget.session.accept(Json.from(result));
        return;
      }
      setChallenge(
        await api.request('POST', register ? '/auth/register' : '/auth/login', {
          'username': username.text.trim().toLowerCase(),
          'password': password.text,
          if (register) 'fullName': name.text.trim(),
          if (register) 'email': email.text.trim().toLowerCase(),
        }),
      );
    });
  }

  Future<void> faceLogin() => run(() async {
    final saved = await widget.session.savedFaceAccount();
    if (!mounted) return;
    final typedUsername = username.text.trim().toLowerCase();
    final faceUsername = typedUsername.isNotEmpty
        ? typedUsername
        : saved?['username'] as String? ?? '';
    if (saved != null &&
        saved['username'] == faceUsername &&
        await widget.session.supportsQuickFaceLogin()) {
      if (!mounted) return;
      final image = await captureFace(
        context,
        mirror: widget.session.preferences.mirrorCamera,
      );
      if (image != null) await widget.session.unlockWithFace(image);
      return;
    }
    if (!mounted) return;
    if (!RegExp(r'^[a-z0-9][a-z0-9_.]{2,31}$').hasMatch(faceUsername)) {
      throw ApiException(
        'Nhập tên đăng nhập đã đăng ký mặt. Nếu chưa có mẫu, đăng nhập mật khẩu + OTP rồi vào Cài đặt để thiết lập.',
      );
    }
    if (!await confirm(
      context,
      'Đăng nhập bằng khuôn mặt',
      'Ảnh được gửi qua HTTPS để đối chiếu với mẫu đã đăng ký, sau đó xác thực OTP email. Nếu chưa có mẫu, đăng nhập mật khẩu + OTP rồi mở Cài đặt để thiết lập khuôn mặt.',
    )) {
      return;
    }
    if (!mounted) return;
    final image = await captureFace(
      context,
      mirror: widget.session.preferences.mirrorCamera,
    );
    if (image == null) return;
    setChallenge(
      await widget.session.api.request('POST', '/auth/face-login', {
        'username': faceUsername,
        'imageBase64': image,
      }),
    );
  });

  Widget field(
    TextEditingController c,
    String label, {
    bool secret = false,
    bool mail = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextFormField(
      controller: c,
      enabled: !busy,
      obscureText: secret && obscure,
      autocorrect: false,
      keyboardType: mail ? TextInputType.emailAddress : TextInputType.text,
      autofillHints: c == username
          ? const [AutofillHints.username]
          : secret
          ? const [AutofillHints.password]
          : null,
      maxLength: c == name
          ? 100
          : mail
          ? 254
          : secret
          ? 128
          : 32,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: secret
            ? IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return 'Nhập ${label.toLowerCase()}';
        if (c == username &&
            !RegExp(
              r'^[a-z0-9][a-z0-9_.]{2,31}$',
            ).hasMatch(text.toLowerCase())) {
          return '3–32 ký tự: a-z, 0-9, dấu _ hoặc .';
        }
        if (c == name && text.length < 2) return 'Họ tên tối thiểu 2 ký tự';
        if (secret && register && (value?.length ?? 0) < 10) {
          return 'Mật khẩu tối thiểu 10 ký tự';
        }
        if (mail && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return 'Email chưa hợp lệ';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    final content = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 40 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: forest,
                    child: Icon(Icons.spa_outlined, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'NguyenHoangVu',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Tag('CHẤM CÔNG · KẾT NỐI ĐỘI NGŨ'),
              const SizedBox(height: 16),
              Text(
                challenge != null
                    ? 'Kiểm tra email.'
                    : register
                    ? 'Bắt đầu cùng nhau.'
                    : 'Chào ngày mới.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                challenge != null
                    ? 'Mã 6 số đã gửi đến ${challenge!['maskedEmail']}. Còn ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.'
                    : register
                    ? 'Đăng ký email, xác thực OTP và chờ quản trị viên duyệt.'
                    : 'Mật khẩu + OTP email, hoặc khuôn mặt đã thiết lập trong Cài đặt.',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 28),
              Form(
                key: form,
                child: Column(
                  children: [
                    if (challenge == null) ...[
                      if (register) field(name, 'Họ và tên'),
                      field(username, 'Tên đăng nhập'),
                      if (register) field(email, 'Email', mail: true),
                      field(password, 'Mật khẩu', secret: true),
                    ] else
                      TextFormField(
                        controller: code,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'OTP email',
                          prefixIcon: Icon(Icons.mark_email_read_outlined),
                        ),
                        // Server checks expiry; a device clock offset must not reject valid OTP.
                        validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                            ? null
                            : 'Nhập đủ 6 chữ số',
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : submit,
                        child: Text(
                          busy
                              ? 'Đang kết nối…'
                              : challenge != null
                              ? 'Xác nhận & đăng nhập'
                              : register
                              ? 'Tạo tài khoản'
                              : 'Tiếp tục với OTP',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Máy chủ Free có thể cần khoảng 90 giây để khởi động.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ),
              if (challenge != null)
                Center(
                  child: TextButton(
                    onPressed: busy || cooldown > 0
                        ? null
                        : () => run(() async {
                            setChallenge(
                              await widget.session.api.request(
                                'POST',
                                '/auth/resend-otp',
                                {'challengeId': challenge!['challengeId']},
                              ),
                            );
                          }),
                    child: Text(
                      cooldown > 0 ? 'Gửi lại sau ${cooldown}s' : 'Gửi lại OTP',
                    ),
                  ),
                ),
              if (challenge == null && !register) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : faceLogin,
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Đăng nhập bằng khuôn mặt'),
                  ),
                ),
              ],
              Center(
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          if (challenge != null) {
                            challenge = null;
                            code.clear();
                          } else {
                            register = !register;
                          }
                          error = null;
                        }),
                  child: Text(
                    challenge != null
                        ? 'Quay lại'
                        : register
                        ? 'Đã có tài khoản? Đăng nhập'
                        : 'Chưa có tài khoản? Đăng ký',
                  ),
                ),
              ),
              if (const bool.fromEnvironment(
                'SHOW_DEMO',
                defaultValue: true,
              )) ...[
                const Divider(),
                Center(
                  child: TextButton.icon(
                    onPressed: busy ? null : () => widget.session.enterDemo(),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Khám phá bản demo'),
                  ),
                ),
                const Text(
                  'Demo dùng dữ liệu mẫu riêng; không gửi OTP hay chấm công thật.',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
              const SizedBox(height: 22),
              const Row(
                children: [
                  Icon(Icons.https_outlined, size: 15, color: muted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Email OTP · API HTTPS · Dữ liệu theo phân quyền',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF153F35), Color(0xFF1A6B56)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tag(
                        'MAKE ROOM FOR A BETTER DAY',
                        color: Color(0xFFC9E9C9),
                      ),
                      SizedBox(height: 34),
                      Text(
                        'Đi làm có nhịp.\nCuộc sống\ncó khoảng.',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          color: Colors.white,
                          fontSize: 51,
                          height: 1.3,
                          letterSpacing: -1.5,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Chấm công thông minh. Kết nối đội ngũ.\nTrọn vẹn từng ngày làm việc.',
                        style: TextStyle(color: Color(0xFFAFD0BF), height: 1.9),
                      ),
                      SizedBox(height: 40),
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: peach,
                        child: Icon(
                          Icons.wb_sunny_outlined,
                          color: forest,
                          size: 70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
