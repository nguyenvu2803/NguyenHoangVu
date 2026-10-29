import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/auth.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  runApp(AttendanceApp(session: Session(Api())));
}

class AttendanceApp extends StatelessWidget {
  final Session session;
  const AttendanceApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NguyenHoangVu · Chấm công',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: session,
      builder: (context, _) => session.user == null
          ? AuthScreen(session: session)
          : AppShell(
              key: ValueKey('${session.user!['id']}-${session.api.demo}'),
              session: session,
            ),
    ),
  );
}
