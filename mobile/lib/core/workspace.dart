import 'package:flutter/material.dart';
import 'api.dart';
import 'session.dart';

class Workspace extends ChangeNotifier {
  final Session session;
  List<Json> attendance = [],
      branches = [],
      shifts = [],
      assignments = [],
      leaves = [],
      employees = [],
      locations = [],
      audits = [];
  Json insights = {};
  bool loading = false;
  bool _alive = true;
  String? error;
  Workspace(this.session);
  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  Api get api => session.api;
  Json get user => session.user!;
  bool get admin => session.isAdmin;
  String get today => day(DateTime.now());
  String day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  Json? get todayAttendance => attendance
      .where((e) => e['user_id'] == user['id'] && e['work_date'] == today)
      .firstOrNull;
  Json? get todayAssignment => assignments
      .where((e) => e['user_id'] == user['id'] && e['work_date'] == today)
      .firstOrNull;
  Json? get todayShift =>
      shifts.where((e) => e['id'] == todayAssignment?['shift_id']).firstOrNull;
  Json? get todayBranch =>
      branches.where((e) => e['id'] == todayShift?['branch_id']).firstOrNull;
  String employeeName(dynamic id) =>
      employees.where((e) => e['id'] == id).firstOrNull?['name'] ??
      (id == user['id'] ? user['name'] : 'Nhân viên #$id');
  String shiftName(dynamic id) =>
      shifts.where((e) => e['id'] == id).firstOrNull?['name'] ?? 'Ca #$id';
  String branchName(dynamic id) =>
      branches.where((e) => e['id'] == id).firstOrNull?['name'] ??
      'Chi nhánh #$id';

  Future<void> reload() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (session.isCustomer) return;
      final paths = [
        '/attendance',
        '/branches',
        '/shifts',
        '/assignments',
        '/leaves',
        '/insights',
        if (admin) ...['/employees', '/locations', '/audit'],
      ];
      final result = await Future.wait(paths.map((p) => api.request('GET', p)));
      if (!_alive) return;
      List<Json> list(int i) =>
          (result[i] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      attendance = list(0);
      branches = list(1);
      shifts = list(2);
      assignments = list(3);
      leaves = list(4);
      insights = Map<String, dynamic>.from(result[5]);
      if (admin) {
        employees = list(6);
        locations = list(7);
        audits = list(8);
      }
      await session.syncBiometricToken();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      if (_alive) notifyListeners();
    }
  }
}
