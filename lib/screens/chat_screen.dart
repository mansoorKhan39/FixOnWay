import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/ui_helpers.dart';
import '../models/app_user.dart';
import '../models/chat_message.dart';

class ChatArgs {
  const ChatArgs(this.requestId, this.title);

  final String requestId;
  final String title;
}

/// UC-16: chat between the customer and the mechanic.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.args});

  final ChatArgs args;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _text = TextEditingController();
  ChatController? _chat;

  @override
  void initState() {
    super.initState();
    final ChatController chat = context.read<ChatController>();
    final AppUser? user = context.read<AuthController>().user;
    _chat = chat;
    chat.reset();
    if (user != null) chat.start(widget.args.requestId, user);
  }

  @override
  void dispose() {
    _chat?.stop();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final AppUser? user = context.read<AuthController>().user;
    if (user == null) return;
    final String value = _text.text;
    final bool ok = await context
        .read<ChatController>()
        .send(widget.args.requestId, user, value);
    if (ok) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ChatController chat = context.watch<ChatController>();
    final String myId = context.watch<AuthController>().user?.id ?? '';
    final List<ChatMessage> items = chat.messages.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.args.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Say hello!',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (BuildContext context, int i) {
                            final ChatMessage m = items[i];
                            final bool mine = m.senderId == myId;
                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      m.text,
                                      style: TextStyle(
                                        color: mine
                                            ? Colors.white
                                            : AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatDateTime(m.sentAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: mine
                                            ? Colors.white70
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (chat.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      chat.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _text,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: chat.isSending ? null : _send,
                        icon: const Icon(Icons.send),
                        tooltip: 'Send',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
