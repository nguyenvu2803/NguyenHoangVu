import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/auth.dart';
import 'screens/shell.dart';
import 'screens/live_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  final session = Session(Api());
  await session.preferences.load();
  runApp(AttendanceApp(session: session));
}

class AttendanceApp extends StatelessWidget {
  final Session session;
  const AttendanceApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session.preferences,
    builder: (context, _) => MaterialApp(
      title: 'NguyenHoangVu · Chấm công',
      debugShowCheckedModeBanner: false,
      theme: appTheme(background: session.preferences.backgroundColor),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) *
                session.preferences.fontScale,
          ),
        ),
        child: child!,
      ),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (session.user == null) return AuthScreen(session: session);
          if (session.api.demo) {
            return AppShell(
              key: ValueKey('${session.user!['id']}-demo'),
              session: session,
            );
          }
          if (session.user!['status'] != 'active' ||
              session.user!['emailVerified'] != true) {
            return AccountWaiting(session: session);
          }
          return LiveShell(
            key: ValueKey(
              '${session.user!['id']}-${session.user!['role']}-${session.user!['branchId']}',
            ),
            session: session,
          );
        },
      ),
    ),
  );
}
