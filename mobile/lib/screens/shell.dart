import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/session.dart';
import '../core/workspace.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'dashboard.dart';
import 'records.dart';
import 'manage.dart';
import 'profile.dart';
import 'attendance_flow.dart';

class AppShell extends StatefulWidget {
  final Session session;
  const AppShell({super.key, required this.session});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Workspace data;
  int page = 0;
  @override
  void initState() {
    super.initState();
    data = Workspace(widget.session);
    data.reload();
  }

  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  List<(IconData, String)> get items => widget.session.isCustomer
      ? [
          (Icons.home_outlined, 'Trang của bạn'),
          (Icons.person_outline, 'Hồ sơ'),
        ]
      : [
          (Icons.grid_view_rounded, 'Tổng quan'),
          (Icons.calendar_month_outlined, 'Lịch làm việc'),
          (Icons.receipt_long_outlined, 'Bảng công'),
          (Icons.beach_access_outlined, 'Nghỉ phép'),
          if (widget.session.isAdmin) (Icons.people_outline, 'Quản lý'),
          (Icons.person_outline, 'Hồ sơ'),
        ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: data,
    builder: (context, _) {
      final desktop = MediaQuery.sizeOf(context).width >= 1080;
      final nav = items;
      final profileIndex = nav.length - 1;
      final Widget body = widget.session.isCustomer
          ? (page == 0 ? CustomerPage(data: data) : ProfilePage(data: data))
          : page == profileIndex
          ? ProfilePage(data: data)
          : switch (page) {
              0 => Dashboard(
                data: data,
                onAttendance: () => attendanceFlow(context, data),
                onNavigate: (value) => setState(() => page = value),
              ),
              1 => SchedulePage(data: data),
              2 => AttendancePage(data: data),
              3 => LeavesPage(data: data),
              _ => ManagePage(data: data),
            };
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (desktop)
                Container(
                  width: 226,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 31, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.blur_on_rounded, size: 34, color: forest),
                          SizedBox(width: 8),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'workroom',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 42, top: 4),
                        child: Text(
                          'NGUYENHOANGVU',
                          style: TextStyle(
                            fontSize: 8,
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w800,
                            color: muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 47),
                      const Padding(
                        padding: EdgeInsets.only(left: 13, bottom: 15),
                        child: Text(
                          'KHÔNG GIAN LÀM VIỆC',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                            color: muted,
                          ),
                        ),
                      ),
                      for (var i = 0; i < nav.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Material(
                            color: page == i ? mint : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => page = i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      nav[i].$1,
                                      size: 20,
                                      color: page == i ? forest : muted,
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Text(
                                        nav[i].$2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: page == i ? forest : muted,
                                          fontWeight: page == i
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (i == 3 &&
                                        data.leaves
                                            .where(
                                              (e) => e['status'] == 'pending',
                                            )
                                            .isNotEmpty) ...[
                                      CircleAvatar(
                                        radius: 9,
                                        backgroundColor: peach,
                                        child: Text(
                                          '${data.leaves.where((e) => e['status'] == 'pending').length}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: paper,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.spa_outlined, color: forest, size: 25),
                            SizedBox(height: 12),
                            Text(
                              'Làm tốt. Sống vui.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Dành một khoảng nghỉ nhỏ cho chính mình hôm nay.',
                              style: TextStyle(
                                fontSize: 10,
                                color: muted,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'WORKROOM / 2026',
                        style: TextStyle(
                          fontSize: 8,
                          color: muted,
                          letterSpacing: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: desktop ? 87 : 70,
                      padding: EdgeInsets.symmetric(
                        horizontal: desktop ? 38 : 22,
                      ),
                      decoration: const BoxDecoration(
                        color: paper,
                        border: Border(bottom: BorderSide(color: line)),
                      ),
                      child: Row(
                        children: [
                          if (!desktop) ...[
                            const Icon(
                              Icons.blur_on_rounded,
                              color: forest,
                              size: 29,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'workroom',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -.7,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.wb_sunny_outlined,
                              size: 17,
                              color: muted,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              DateFormat(
                                'EEEE, dd MMMM yyyy',
                                'vi_VN',
                              ).format(DateTime.now()),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (desktop) const Spacer(),
                          if (widget.session.api.demo)
                            const Tag(
                              'DEMO',
                              color: Color(0xFFA66B36),
                              background: Color(0xFFFAEAD8),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Làm mới dữ liệu',
                            onPressed: data.loading ? null : data.reload,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: muted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => page = profileIndex),
                            borderRadius: BorderRadius.circular(30),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFEBD5BC),
                                  child: Text(
                                    initials(data.user['name']),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (desktop) ...[
                                  const SizedBox(width: 11),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data.user['name'],
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        roleName(data.user['role']),
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 17,
                                    color: muted,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data.loading)
                      const LinearProgressIndicator(minHeight: 2),
                    if (data.error != null)
                      MaterialBanner(
                        content: Text(data.error!),
                        actions: [
                          TextButton(
                            onPressed: data.reload,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: data.reload,
                        child: SingleChildScrollView(
                          key: ValueKey(page),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 38 : 22,
                            desktop ? 31 : 25,
                            desktop ? 38 : 22,
                            30,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1250),
                              child: FadeIn(key: ValueKey(page), child: body),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: desktop
            ? null
            : NavigationBar(
                height: 73,
                backgroundColor: Colors.white,
                indicatorColor: mint,
                selectedIndex: page,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                onDestinationSelected: (value) => setState(() => page = value),
                destinations: [
                  for (final item in nav)
                    NavigationDestination(
                      icon: Icon(item.$1, size: 21),
                      label: item.$2,
                    ),
                ],
              ),
      );
    },
  );
}
