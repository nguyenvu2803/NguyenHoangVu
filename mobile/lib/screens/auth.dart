import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/session.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  final Session session;
  const AuthScreen({super.key, required this.session});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  bool register = false, busy = false, obscure = true;
  String channel = 'email';
  Json? challenge;
  String? error;
  StreamSubscription<Uri>? links;
  int seconds = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      final appLinks = AppLinks();
      links = appLinks.uriLinkStream.listen(_oauth, onError: (_) {});
      appLinks.getInitialLink().then((uri) {
        if (uri != null) _oauth(uri);
      });
    } else if (Uri.base.queryParameters['code'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _oauth(Uri.base));
    }
  }

  @override
  void dispose() {
    for (final c in [email, password, name, phone, code]) {
      c.dispose();
    }
    links?.cancel();
    timer?.cancel();
    super.dispose();
  }

  Future<void> _oauth(Uri uri) async {
    final value = uri.queryParameters['code'];
    if (value == null || (!kIsWeb && uri.scheme != 'nguyenhoangvu')) return;
    await run(() async {
      final verifier = await widget.session.storage.read(key: 'oauth_verifier');
      if (verifier == null) {
        throw ApiException('Phiên Google đã hết. Vui lòng đăng nhập lại.');
      }
      final result = await widget.session.api.request(
        'POST',
        '/auth/google/exchange',
        {'code': value, 'verifier': verifier},
      );
      await widget.session.storage.delete(key: 'oauth_verifier');
      await widget.session.accept(result);
    });
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

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      if (challenge != null) {
        if (widget.session.api.demo && code.text != '123456') {
          throw ApiException('Mã demo là 123456');
        }
        final result = await widget.session.api.request(
          'POST',
          '/auth/verify',
          {'challenge_id': challenge!['challenge_id'], 'code': code.text},
        );
        await widget.session.accept(result);
      } else {
        final response = await widget.session.api
            .request('POST', register ? '/auth/register' : '/auth/login', {
              'email': email.text.trim(),
              'password': password.text,
              if (register) 'name': name.text.trim(),
              if (register) 'phone': phone.text.trim(),
              if (!register) 'channel': channel,
            });
        setState(() {
          challenge = Map<String, dynamic>.from(response);
          seconds = 300;
        });
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted || seconds <= 0) {
            t.cancel();
            return;
          }
          setState(() => seconds--);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    final content = SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 56 : 26),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: forest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.blur_on_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'workroom',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'NGUYENHOANGVU',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 2.1,
                          color: muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                challenge != null
                    ? 'Một bước nữa thôi.'
                    : register
                    ? 'Bắt đầu kết nối.'
                    : 'Chào ngày mới.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                challenge != null
                    ? 'Nhập 6 số đã gửi đến ${challenge!['destination']}.'
                    : register
                    ? 'Tạo tài khoản để cùng làm việc tốt hơn.'
                    : 'Một nơi cho giờ làm, lịch nghỉ và những ngày cân bằng.',
                style: const TextStyle(color: muted, height: 1.8),
              ),
              const SizedBox(height: 30),
              if (widget.session.api.demo)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Tag(
                    'CHẾ ĐỘ DEMO · OTP: 123456',
                    color: Color(0xFF996133),
                    icon: Icons.science_outlined,
                  ),
                ),
              Form(
                key: form,
                child: Column(
                  children: [
                    if (challenge != null) ...[
                      TextFormField(
                        controller: code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Mã xác thực',
                          prefixIcon: Icon(Icons.password_rounded),
                        ),
                        validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                            ? null
                            : 'Nhập đủ 6 chữ số',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Hiệu lực còn ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    ] else ...[
                      if (register) ...[
                        TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v?.trim().length ?? 0) < 2
                              ? 'Nhập họ tên'
                              : null,
                        ),
                        const SizedBox(height: 15),
                      ],
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'ban@congty.vn',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (v) =>
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v ?? '')
                            ? null
                            : 'Email chưa hợp lệ',
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: password,
                        obscureText: obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v?.length ?? 0) < (register ? 10 : 1)
                            ? (register
                                  ? 'Tối thiểu 10 ký tự'
                                  : 'Nhập mật khẩu')
                            : null,
                      ),
                      const SizedBox(height: 15),
                      if (register)
                        TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Điện thoại (tùy chọn)',
                            hintText: '+84901234567',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) =>
                              v!.isNotEmpty &&
                                  !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(v)
                              ? 'Dùng định dạng +84901234567'
                              : null,
                        )
                      else
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Nhận OTP qua',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Email'),
                              selected: channel == 'email',
                              onSelected: (_) =>
                                  setState(() => channel = 'email'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('SMS'),
                              selected: channel == 'sms',
                              onSelected: (_) =>
                                  setState(() => channel = 'sms'),
                            ),
                          ],
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
                    const SizedBox(height: 23),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : submit,
                        child: busy
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                challenge != null
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
              const SizedBox(height: 15),
              if (challenge == null) ...[
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text(
                        'hoặc',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            if (widget.session.api.demo ||
                                !widget.session.api.configured) {
                              throw ApiException(
                                'Google OAuth cần API đã deploy và GOOGLE_CLIENT_ID.',
                              );
                            }
                            final random = Random.secure();
                            final verifier = base64UrlEncode(
                              List<int>.generate(
                                48,
                                (_) => random.nextInt(256),
                              ),
                            ).replaceAll('=', '');
                            await widget.session.storage.write(
                              key: 'oauth_verifier',
                              value: verifier,
                            );
                            final challenge = sha256
                                .convert(utf8.encode(verifier))
                                .toString();
                            await launchUrl(
                              Uri.parse(
                                '${Api.baseUrl}/auth/google/start?app_challenge=$challenge',
                              ),
                              mode: LaunchMode.externalApplication,
                              webOnlyWindowName: '_self',
                            );
                          }),
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    label: const Text('Tiếp tục với Google'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => run(widget.session.biometricLogin),
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Đăng nhập Face ID / vân tay'),
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
                        ? 'Quay lại / gửi mã mới'
                        : register
                        ? 'Đã có tài khoản? Đăng nhập'
                        : 'Chưa có tài khoản? Đăng ký',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: busy ? null : () => widget.session.enterDemo(),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Khám phá bản demo'),
                ),
              ),
              if (!widget.session.api.configured && !widget.session.api.demo)
                const Text(
                  'Chưa kết nối máy chủ. Bản demo dùng dữ liệu mẫu trên thiết bị; không gửi OTP thật.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 10),
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
                  padding: const EdgeInsets.all(50),
                  decoration: BoxDecoration(
                    color: forest,
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF153F35), Color(0xFF1A6B56)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Tag(
                        'MAKE ROOM FOR A BETTER DAY',
                        color: Color(0xFFC9E9C9),
                        background: Color(0xFF35705D),
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        'Đi làm có nhịp.\nCuộc sống\ncó khoảng.',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          color: Colors.white,
                          fontSize: 51,
                          height: 1.3,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Chấm công thông minh. Kết nối đội ngũ.\nTrọn vẹn từng ngày làm việc.',
                        style: TextStyle(color: Color(0xFFAFD0BF), height: 1.9),
                      ),
                      const SizedBox(height: 50),
                      Container(
                        width: 170,
                        height: 170,
                        decoration: const BoxDecoration(
                          color: peach,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wb_sunny_outlined,
                          color: forest,
                          size: 80,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        '01 / MỘT NGÀY TỐT BẮT ĐẦU TỪ BẠN',
                        style: TextStyle(
                          color: Color(0xFFAFD0BF),
                          letterSpacing: 1.8,
                          fontSize: 9,
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
