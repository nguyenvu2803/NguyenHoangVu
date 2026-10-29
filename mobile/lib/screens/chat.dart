import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/chat.dart';
import '../core/live.dart';
import '../core/message_translation.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ChatContacts extends StatefulWidget {
  final Session session;
  const ChatContacts({super.key, required this.session});
  @override
  State<ChatContacts> createState() => _ChatContactsState();
}

class _ChatContactsState extends State<ChatContacts> {
  List<Json> contacts = [];
  String search = '';
  String? error;
  bool busy = true;
  late final userId = widget.session.user?['id'];
  @override
  void initState() {
    super.initState();
    widget.session.addListener(checkSession);
    load();
  }

  void checkSession() {
    if (widget.session.user?['id'] != userId ||
        widget.session.user?['status'] != 'active') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(checkSession);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = objects(
        await widget.session.api.request('GET', '/chat/contacts'),
      );
      if (mounted) setState(() => contacts = rows);
    } catch (e) {
      if (mounted) setState(() => error = chatError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tin nhắn'),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          tooltip: 'Tải lại danh bạ',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: mint,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hiểu nhau, cùng tiến.',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 25,
                    color: forest,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Trò chuyện trong chi nhánh hoặc với quản trị viên. Dịch tự động Việt · Anh · Trung trên thiết bị.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Tìm đồng nghiệp',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => search = value.toLowerCase()),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (!busy && error == null && contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Chưa có đồng nghiệp đang hoạt động. Nhờ admin duyệt tài khoản và gán chi nhánh.',
                      ),
                    ),
                  for (final peer in contacts.where(
                    (row) => row['fullName'].toString().toLowerCase().contains(
                      search,
                    ),
                  ))
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: const CircleAvatar(
                          backgroundColor: mint,
                          child: Icon(Icons.person_outline, color: forest),
                        ),
                        title: Text(
                          peer['fullName'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${roleName(peer['role'])} · ${peer['branchName'] ?? 'Toàn hệ thống'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatConversation(
                              session: widget.session,
                              peer: peer,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ChatConversation extends StatefulWidget {
  final Session session;
  final Json peer;
  final ChatController? controller;
  final MessageTranslator? translator;
  const ChatConversation({
    super.key,
    required this.session,
    required this.peer,
    this.controller,
    this.translator,
  });
  @override
  State<ChatConversation> createState() => _ChatConversationState();
}

class _ChatConversationState extends State<ChatConversation>
    with WidgetsBindingObserver {
  late final chat =
      widget.controller ??
      ChatController(widget.session.api, widget.peer['id']);
  late final translator = widget.translator ?? DeviceMessageTranslator();
  final composer = TextEditingController();
  String source = 'vi', target = 'en';
  bool downloading = false, translating = false, enabled = false;
  String? translationError, preview;
  int revision = 0;
  Timer? debounce;
  final translated = <String, String>{};
  final inFlight = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    chat.addListener(changed);
    composer.addListener(draftChanged);
    chat.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      chat.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      chat.pause();
    }
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    translateMessages();
  }

  void draftChanged() {
    final version = ++revision;
    debounce?.cancel();
    if (mounted) {
      setState(() {
        preview = null;
        translating = false;
      });
    }
    if (!enabled || composer.text.trim().isEmpty) return;
    final text = composer.text, from = source, to = target;
    debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => translating = true);
      try {
        final result = await translator.translate(text, from, to);
        if (mounted && revision == version) {
          setState(() {
            preview = result;
            translationError = null;
          });
        }
      } catch (_) {
        if (mounted && revision == version) {
          setState(
            () => translationError =
                'Chưa dịch được. Bản gốc vẫn gửi bình thường.',
          );
        }
      } finally {
        if (mounted && revision == version) setState(() => translating = false);
      }
    });
  }

  Future<void> prepare() async {
    setState(() {
      downloading = true;
      translationError = null;
    });
    try {
      await translator.prepare();
      if (!mounted) return;
      setState(() => enabled = true);
      draftChanged();
      translateMessages();
    } catch (_) {
      if (mounted) {
        setState(
          () => translationError =
              'Tải gói dịch chưa thành công. Kiểm tra mạng/dung lượng rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  void translateMessages() {
    if (!enabled) return;
    final to = target;
    for (final row in chat.messages) {
      final key = '${row['id']}:$to';
      if (translated.containsKey(key) || inFlight.contains(key)) continue;
      inFlight.add(key);
      unawaited(() async {
        try {
          final result = await translator.translate(
            row['text'],
            row['sourceLanguage'],
            to,
          );
          if (mounted) {
            setState(() {
              translated[key] = result;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => translationError =
                  'Một số tin chưa dịch được. Bản gốc vẫn hiển thị.',
            );
          }
        } finally {
          inFlight.remove(key);
        }
      }());
    }
  }

  Future<void> send() async {
    final text = composer.text;
    final sent = await chat.send(text, source);
    if (mounted && sent && composer.text == text) composer.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    revision++;
    chat.removeListener(changed);
    chat.dispose();
    composer.dispose();
    unawaited(translator.close());
    super.dispose();
  }

  Widget language(String label, String value, ValueChanged<String?> changed) =>
      Expanded(
        child: DropdownButtonFormField<String>(
          key: ValueKey('$label:$value'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          items: [
            for (final entry in chatLanguages.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, style: const TextStyle(fontSize: 12)),
              ),
          ],
          onChanged: changed,
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.peer['fullName'].toString(),
            style: const TextStyle(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            chat.online ? 'Đang kết nối realtime' : 'Đang chờ kết nối',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Kết nối lại',
          onPressed: () {
            chat.pause();
            chat.start();
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                language('Bạn viết', source, (value) {
                  setState(() => source = value!);
                  draftChanged();
                }),
                const SizedBox(width: 8),
                language('Dịch sang', target, (value) {
                  setState(() => target = value!);
                  draftChanged();
                  translateMessages();
                }),
              ],
            ),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextButton.icon(
                onPressed: downloading ? null : prepare,
                icon: downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                label: Text(
                  downloading
                      ? 'Đang tải gói dịch…'
                      : 'Bật dịch · tải gói lần đầu (cần mạng)',
                ),
              ),
            ),
          if (enabled)
            const Padding(
              padding: EdgeInsets.all(6),
              child: Text(
                'Dịch tự động trên thiết bị · Giữ nguyên bản gốc',
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ),
          if (chat.error != null || translationError != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFEADD),
              padding: const EdgeInsets.all(10),
              child: Text(
                chat.error ?? translationError!,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          Expanded(
            child: chat.messages.isEmpty
                ? const Center(child: Text('Bắt đầu bằng một lời chào.'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: chat.messages.length + (chat.hasOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chat.messages.length) {
                        return TextButton(
                          onPressed: chat.loading ? null : chat.older,
                          child: const Text('Tin nhắn trước'),
                        );
                      }
                      final row =
                          chat.messages[chat.messages.length - index - 1];
                      final own = row['senderId'] == widget.session.user?['id'];
                      final result = translated['${row['id']}:$target'];
                      return Align(
                        alignment: own
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .85,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: own ? mint : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(row['text']),
                              if (result != null &&
                                  row['sourceLanguage'] != target) ...[
                                const Divider(height: 18),
                                Text(
                                  '${chatLanguages[target]} · Dịch tự động',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                                SelectableText(
                                  result,
                                  style: const TextStyle(color: forest),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                '${chatLanguages[row['sourceLanguage']]} · ${clockText(row['createdAt'])}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (preview != null || translating)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: mint,
              child: Text(
                translating
                    ? 'Đang dịch bản nháp…'
                    : 'Bản dịch xem trước: $preview',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: composer,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: 'Viết tin nhắn…',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Gửi bản gốc',
                  onPressed: chat.sending || composer.text.trim().isEmpty
                      ? null
                      : send,
                  icon: chat.sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
