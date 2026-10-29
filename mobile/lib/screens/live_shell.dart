import 'package:flutter/material.dart';
import '../core/live.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'live_attendance.dart';
import 'live_manage.dart';
import 'live_profile.dart';

class LiveShell extends StatefulWidget {
  final Session session;
  const LiveShell({super.key, required this.session});
  @override
  State<LiveShell> createState() => _LiveShellState();
}

class _LiveShellState extends State<LiveShell> {
  late final data = LiveData(widget.session.api, widget.session.user!);
  int index = 0;
  bool busy = true, loaded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload({bool user = false}) async {
    if (mounted) {
      setState(() {
        busy = true;
        error = null;
      });
    }
    try {
      if (user) await widget.session.reloadUser();
      if (widget.session.user?['status'] != 'active') return;
      data.user = widget.session.user!;
      await data.load();
      if (mounted) setState(() => loaded = true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
      if (widget.session.user != null) await data.load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final labels = [
      'Tổng quan',
      'Ca của tôi',
      'Điều chỉnh',
      data.manages ? 'Quản lý' : 'Báo cáo',
      'Hồ sơ',
    ];
    final icons = [
      Icons.space_dashboard_outlined,
      Icons.calendar_today_outlined,
      Icons.fact_check_outlined,
      data.manages ? Icons.groups_outlined : Icons.analytics_outlined,
      Icons.person_outline,
    ];
    final pages = <Widget>[
      _Dashboard(
        data: data,
        onShifts: () => setState(() => index = 1),
        onCorrections: () => setState(() => index = 2),
      ),
      LiveShifts(data: data, act: act),
      LiveCorrections(data: data, act: act),
      data.manages
          ? LiveManagement(data: data, act: act)
          : LiveReport(data: data),
      LiveProfile(session: widget.session, data: data, act: act),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: paper,
        title: Row(
          children: [
            const Icon(Icons.spa_outlined, color: forest),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                wide ? 'NguyenHoangVu · Chấm công' : 'NguyenHoangVu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Báo cáo tháng',
            onPressed: !loaded || busy
                ? null
                : () => openLiveReport(context, data),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Tải lại dữ liệu',
            onPressed: busy ? null : () => reload(user: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Container(
                width: 240,
                margin: const EdgeInsets.fromLTRB(16, 0, 0, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: forest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Một ngày tốt\nbắt đầu từ bạn.',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 23,
                          height: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    for (var i = 0; i < labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            selected: index == i,
                            selectedTileColor: Colors.white.withValues(
                              alpha: .13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(icons[i], color: Colors.white),
                            title: Text(
                              labels[i],
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () => setState(() => index = i),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${widget.session.user?['fullName']}\n${roleName(widget.session.user?['role'])}',
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (busy) const LinearProgressIndicator(minHeight: 3),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFEADD),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              error!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Đóng thông báo',
                            onPressed: () => setState(() => error = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: !loaded
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (busy) ...[
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Đang tải dữ liệu. Máy chủ Free có thể cần 90 giây để khởi động.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ] else ...[
                                    const Text(
                                      'Chưa tải được dữ liệu từ máy chủ.',
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed: reload,
                                      child: const Text('Thử lại'),
                                    ),
                                    TextButton(
                                      onPressed: widget.session.logout,
                                      child: const Text('Đăng xuất'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : IgnorePointer(
                            ignoring: busy,
                            child: RefreshIndicator(
                              onRefresh: () => reload(user: true),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.all(wide ? 32 : 18),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1100,
                                    ),
                                    child: FadeIn(
                                      key: ValueKey(index),
                                      child: pages[index],
                                    ),
                                  ),
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
    );
  }
}

class AccountWaiting extends StatefulWidget {
  final Session session;
  const AccountWaiting({super.key, required this.session});
  @override
  State<AccountWaiting> createState() => _AccountWaitingState();
}

class _AccountWaitingState extends State<AccountWaiting> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final user = widget.session.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('NguyenHoangVu')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 46,
                    color: forest,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user['status'] == 'suspended'
                        ? 'Tài khoản tạm khóa.'
                        : 'Đã xác thực email.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user['status'] == 'suspended'
                        ? 'Liên hệ quản trị viên API để kiểm tra trạng thái tài khoản.'
                        : 'Chào ${user['fullName']}. Tài khoản đang chờ admin duyệt và gán chi nhánh để sử dụng chấm công.',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Tên đăng nhập: ${user['username']}\n${user['email']}',
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              await widget.session.reloadUser();
                            } catch (e) {
                              if (mounted) setState(() => error = e.toString());
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(
                      busy ? 'Đang kiểm tra…' : 'Kiểm tra trạng thái duyệt',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              await widget.session.logout();
                            } catch (_) {
                              /* Local session is cleared in finally. */
                            }
                          },
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final LiveData data;
  final VoidCallback onShifts, onCorrections;
  const _Dashboard({
    required this.data,
    required this.onShifts,
    required this.onCorrections,
  });
  @override
  Widget build(BuildContext context) {
    final totals = data.report['totals'] as Map? ?? {};
    final ownRows = objects(
      data.report['rows'] ?? [],
    ).where((r) => r['employeeId'] == data.user['id']).toList();
    final rhythm = rhythmSummary(ownRows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          eyebrow: '${roleName(data.user['role'])} · ${data.month}',
          title: 'Chào ${data.user['fullName'].toString().split(' ').last}.',
          subtitle:
              'Một nơi cho lịch làm việc, chấm công và nhịp sống của bạn.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF123E34), Color(0xFF26755C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Tag('MỖI NGÀY MỘT NHỊP TỐT', color: Color(0xFFD8EBC6)),
              const SizedBox(height: 20),
              const Text(
                'Sẵn sàng cho\nmột ngày tốt lành.',
                style: TextStyle(
                  fontFamily: 'Lora',
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hôm nay: ${data.dashboard['shiftCount'] ?? 0} ca · ${data.dashboard['checkedInCount'] ?? 0} lượt vào ca trong phạm vi của bạn.',
                style: const TextStyle(color: Color(0xFFCEE4D8)),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: peach,
                  foregroundColor: ink,
                ),
                onPressed: onShifts,
                icon: const Icon(Icons.north_east),
                label: const Text('Mở ca của tôi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final stat in [
                ['${totals['shiftCount'] ?? 0}', 'Ca trong tháng'],
                ['${totals['completedCount'] ?? 0}', 'Ca hoàn tất'],
                ['${totals['lateCount'] ?? 0}', 'Lượt đi muộn'],
                [
                  '${data.corrections.where((r) => r['status'] == 'pending').length}',
                  'Đơn chờ duyệt',
                ],
              ])
                SizedBox(
                  width:
                      (box.maxWidth - (box.maxWidth > 650 ? 36 : 12)) /
                      (box.maxWidth > 650 ? 4 : 2),
                  child: Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat[0],
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: forest,
                          ),
                        ),
                        Text(
                          stat[1],
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          color: mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.spa_outlined, color: forest),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nhịp cân bằng',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 23,
                        color: forest,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ownRows.isEmpty
                    ? 'Chưa có lịch cá nhân trong tháng để phân tích.'
                    : '${rhythm['shortRests']} khoảng nghỉ giữa ca dưới 11 giờ. ${rhythm['longShifts']} ca dự kiến dài hơn 10 giờ. ${rhythm['missing']} ca thiếu giờ vào/ra.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Gợi ý cá nhân từ lịch tháng và dữ liệu thiếu công. Không kết luận sức khỏe, lương hoặc tăng ca.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: onCorrections,
                    child: const Text('Đối soát giờ thiếu'),
                  ),
                  TextButton(
                    onPressed: () => openLiveReport(context, data),
                    child: const Text('Xem bảng tháng'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Ca gần nhất của bạn',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (data.ownShifts.isEmpty)
          const EmptyState(
            'Chưa có ca',
            'Quản lý sẽ phân ca sau khi duyệt tài khoản.',
          ),
        for (final s
            in (data.ownShifts
                .where(
                  (s) => DateTime.parse(s['endsAt']).isAfter(DateTime.now()),
                )
                .take(3)))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: forest),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['title']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${dateTimeText(s['startsAt'])} · ${s['branchName']}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onShifts,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
