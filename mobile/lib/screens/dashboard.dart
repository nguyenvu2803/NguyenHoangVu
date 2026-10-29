import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/common.dart';
import 'records.dart';

class Dashboard extends StatefulWidget {
  final Workspace data;
  final VoidCallback onAttendance;
  final ValueChanged<int> onNavigate;
  const Dashboard({
    super.key,
    required this.data,
    required this.onAttendance,
    required this.onNavigate,
  });
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final today = d.todayAttendance;
    final checkedIn = today != null;
    final complete = today?['check_out'] != null;
    final own = d.attendance
        .where((e) => e['user_id'] == d.user['id'])
        .toList();
    final onTime = own.where((e) => e['late_minutes'] == 0).length;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Chào buổi sáng'
        : now.hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          eyebrow: 'Không gian của bạn',
          title: '$greeting, ${d.user['name'].toString().split(' ').last}.',
          subtitle: 'Một chút tập trung. Một chút cân bằng. Một ngày thật tốt.',
          action: MediaQuery.sizeOf(context).width > 600
              ? const Tag(
                  'HÔM NAY, MÌNH LÀM TỐT',
                  icon: Icons.auto_awesome_outlined,
                )
              : null,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 740;
            final hero = _hero(d, checkedIn, complete, wide);
            final wellbeing = _wellbeing(d);
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: hero),
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: wellbeing),
                    ],
                  )
                : Column(
                    children: [hero, const SizedBox(height: 17), wellbeing],
                  );
          },
        ),
        const SizedBox(height: 23),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _stat(
                'Ngày đã chấm công',
                own.length.toString().padLeft(2, '0'),
                'Trong ${own.isEmpty ? 'dữ liệu hiện có' : 'bảng công'}',
                Icons.calendar_today_outlined,
                forest,
              ),
              _stat(
                'Tỷ lệ đúng giờ',
                '${own.isEmpty ? 0 : (onTime / own.length * 100).round()}%',
                '$onTime ngày bắt đầu đúng nhịp',
                Icons.timelapse_rounded,
                const Color(0xFFB47D4F),
              ),
              _stat(
                d.admin ? 'Đơn chờ duyệt' : 'Đơn nghỉ chờ duyệt',
                d.leaves
                    .where((e) => e['status'] == 'pending')
                    .length
                    .toString()
                    .padLeft(2, '0'),
                d.admin
                    ? 'Đội ngũ đang chờ phản hồi'
                    : 'Theo dõi tại mục Nghỉ phép',
                Icons.beach_access_outlined,
                const Color(0xFF739080),
              ),
            ];
            return constraints.maxWidth > 620
                ? Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 17),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card,
                        ),
                    ],
                  );
          },
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, constraints) {
            final week = _week(d);
            final branch = _branch(d);
            return constraints.maxWidth > 740
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: week),
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: branch),
                    ],
                  )
                : Column(children: [week, const SizedBox(height: 18), branch]);
          },
        ),
        const SizedBox(height: 26),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20, color: forest),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Những ngày vừa qua',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigate(2),
                    child: const Text(
                      'Xem tất cả',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (d.attendance.isEmpty)
                const EmptyState(
                  'Chưa có bảng công',
                  'Ngày làm việc đầu tiên đang chờ bạn.',
                )
              else
                ...d.attendance
                    .take(4)
                    .map((item) => AttendanceRow(item: item, data: d)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'ĐƯỢC TẠO CHO NHỮNG NGÀY LÀM VIỆC TỐT HƠN.',
            style: TextStyle(fontSize: 8, letterSpacing: 1.6, color: muted),
          ),
        ),
      ],
    );
  }

  Widget _hero(
    Workspace d,
    bool checked,
    bool complete,
    bool wide,
  ) => Container(
    constraints: const BoxConstraints(minHeight: 307),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF164E40), Color(0xFF1C6651)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          right: -55,
          top: -65,
          child: Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .07),
                width: 40,
              ),
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: wide ? 75 : 135,
          child: Opacity(
            opacity: .65,
            child: CustomPaint(
              size: Size(wide ? 130 : 100, 130),
              painter: ClockArt(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(27),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Tag(
                    complete
                        ? 'ĐÃ HOÀN THÀNH CA'
                        : checked
                        ? 'ĐANG TRONG CA'
                        : 'CHÀO NGÀY LÀM VIỆC MỚI',
                    color: const Color(0xFFD6ECCA),
                    background: Colors.white.withValues(alpha: .1),
                    icon: Icons.circle,
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                complete
                    ? 'Cảm ơn bạn,\nmột ngày trọn vẹn.'
                    : checked
                    ? 'Đã vào ca.\nGiữ nhịp thật tốt.'
                    : 'Sẵn sàng cho\nmột ngày tốt lành.',
                style: const TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 28,
                  height: 1.3,
                  color: Colors.white,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      DateFormat('ss').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFFAECEB8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 15,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: complete ? null : widget.onAttendance,
                    style: FilledButton.styleFrom(
                      backgroundColor: peach,
                      foregroundColor: ink,
                      disabledBackgroundColor: const Color(0xFF9DB5A5),
                      disabledForegroundColor: ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 19,
                        vertical: 17,
                      ),
                    ),
                    icon: Icon(
                      complete
                          ? Icons.check_circle_outline
                          : Icons.qr_code_scanner_rounded,
                      size: 18,
                    ),
                    label: Text(
                      complete
                          ? 'Ca đã hoàn thành'
                          : checked
                          ? 'Chấm công ra ca'
                          : 'Chấm công vào ca',
                    ),
                  ),
                  Text(
                    d.todayShift == null
                        ? 'Chưa được phân ca hôm nay'
                        : '${d.todayShift!['start']} — ${d.todayShift!['end']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB8D5C1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _wellbeing(Workspace d) => Panel(
    color: const Color(0xFFEAF0DD),
    padding: const EdgeInsets.all(25),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Tag(
              'WORK / LIFE',
              color: Color(0xFF547043),
              background: Color(0xFFDDE7CA),
            ),
            Spacer(),
            Icon(Icons.spa_outlined, color: Color(0xFF547043), size: 24),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Nhịp làm việc\ncủa bạn.',
          style: TextStyle(fontFamily: 'Lora', fontSize: 25, height: 1.3),
        ),
        const SizedBox(height: 19),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${((d.insights['week_minutes'] ?? 0) / 60).toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            const Flexible(
              child: Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ 40 giờ tuần này',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ((d.insights['load_percent'] ?? 0) as num) / 100,
            minHeight: 7,
            color: const Color(0xFF6F8F5D),
            backgroundColor: const Color(0xFFD9E2CA),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          (d.insights['suggestions'] as List?)?.firstOrNull ??
              'Giờ làm được tổng hợp từ bảng công của bạn.',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF5C7052),
            height: 1.8,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Gợi ý theo giờ công · Không phải đánh giá y tế',
          style: TextStyle(fontSize: 8, color: muted),
        ),
      ],
    ),
  );

  Widget _stat(
    String label,
    String value,
    String note,
    IconData icon,
    Color color,
  ) => Panel(
    padding: const EdgeInsets.all(21),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(note, style: const TextStyle(fontSize: 9, color: muted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ],
    ),
  );

  Widget _week(Workspace d) {
    final monday = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tuần này của bạn',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(1),
                child: const Text('Xem lịch', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              final selected = d.day(day) == d.today;
              final assigned = d.assignments.any(
                (e) =>
                    e['user_id'] == d.user['id'] &&
                    e['work_date'] == d.day(day),
              );
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 6 ? 5 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? forest : paper,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        i == 6 ? 'CN' : 'T${i + 2}',
                        style: TextStyle(
                          color: selected ? Colors.white70 : muted,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: assigned
                              ? (selected ? peach : forest)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              Container(
                width: 4,
                height: 30,
                decoration: BoxDecoration(
                  color: peach,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.todayShift?['name'] ?? 'Hôm nay chưa có lịch làm việc',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.todayBranch?['name'] ??
                          'Liên hệ quản trị viên để được phân ca',
                      style: const TextStyle(fontSize: 9, color: muted),
                    ),
                  ],
                ),
              ),
              if (d.todayShift != null)
                Tag('${d.todayShift!['start']} — ${d.todayShift!['end']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _branch(Workspace d) => Panel(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
          child: SizedBox(
            height: 118,
            width: double.infinity,
            child: CustomPaint(
              painter: MapArt(),
              child: const Center(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: forest,
                  child: Icon(
                    Icons.business_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.todayBranch?['name'] ?? 'Văn phòng của bạn',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                d.todayBranch?['address'] ??
                    'Chi nhánh hiển thị khi bạn được phân ca.',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: forest,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Phạm vi ${d.todayBranch?['radius'] ?? '—'}m',
                    style: const TextStyle(fontSize: 9, color: forest),
                  ),
                  const Spacer(),
                  const Text(
                    'Sơ đồ minh họa',
                    style: TextStyle(fontSize: 8, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ClockArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      c,
      size.width * .44,
      Paint()..color = const Color(0xFF7BA58D).withValues(alpha: .3),
    );
    canvas.drawCircle(c, size.width * .35, Paint()..color = peach);
    final paint = Paint()
      ..color = forest
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + Offset(0, -size.width * .2), paint);
    canvas.drawLine(c, c + Offset(size.width * .15, size.width * .06), paint);
    canvas.drawCircle(c, 4, paint);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final r = size.width * .29;
      canvas.drawCircle(
        c + Offset(math.sin(a) * r, -math.cos(a) * r),
        1.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MapArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8EEE3),
    );
    final road = Paint()
      ..color = const Color(0xFFF8F9F4)
      ..strokeWidth = 14;
    for (var i = -1; i < 6; i++) {
      canvas.drawLine(
        Offset(i * 80.0, 0),
        Offset(i * 80.0 - 60, size.height),
        road,
      );
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(0, i * 65.0 + 15),
        Offset(size.width, i * 65.0 - 20),
        road..strokeWidth = 10,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .69, 18, 42, 31),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFD4E3CB),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
