import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Reuse the auth flow's fallback-contacts sheet instead of duplicating it —
// this file only *imports* lib/pages/auth/auth_shell.dart, it does not
// edit it.
import '../auth/auth_shell.dart' show AuthTroubleButton;

/// AI客服 (AI support) screen — a real native chat UI talking to the
/// already-implemented, already-authenticated `POST /ai/chat` endpoint
/// (`HgfastRepository.aiChat`), instead of trying to resolve an external
/// webview URL.
///
/// A prior version of this screen tried to open an external browser tab at
/// a URL read from `config()`'s `ai_agent`/`client_webview` fields
/// (`url`/`webview_url`/`entry_url`/`href`). Reading the real backend source
/// (`app/core/client_api/data.js`'s `getClientConfig()`) shows that
/// `ai_agent` never actually carries a field with any of those names — it
/// carries `endpoint: '/api/client/{platform}/v1/ai/chat'` (a REST API
/// path, already what `aiChat()` calls) and a `ui.web_page_route`/
/// `ui.client_webview.load_url` pair of *relative* paths meant for the
/// separate web frontend's own in-page router, not a URL for this native
/// app to open. So `_resolveAiAgentUrl` could never match anything real —
/// the button always fell through to the disabled state in production.
///
/// The backend's `/ai/chat` handler (`data.js`'s `aiReply()`) is itself
/// currently a fixed stub — `{ reply: 'AI 客服暂未开放，请通过在线客服联系人工',
/// actions: [], fallback: true }` regardless of what's asked — not
/// connected to the separate, much more capable `hgfast-ai-support` service
/// that already exists in production. That's a real, separate, backend-side
/// gap (out of scope for a client-only change) — but the endpoint itself is
/// real, authenticated, and reachable, so this screen calls it honestly and
/// renders whatever it actually returns (including the stub reply and its
/// `fallback: true` flag) rather than either faking a smarter response or
/// silently disabling the whole screen the way the previous version did.
class SupportView extends ConsumerStatefulWidget {
  const SupportView({super.key});

  @override
  ConsumerState<SupportView> createState() => _SupportViewState();
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isFallback = false,
  });

  final String text;
  final bool isUser;
  final bool isFallback;
}

class _SupportViewState extends ConsumerState<SupportView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: '你好，我是 HGFAST 智能客服，请描述你遇到的问题。',
      isUser: false,
    ),
  ];
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _describeError(HgfastError error) {
    return switch (error) {
      HgfastAuthFailed() => '登录已失效，请重新登录后再试',
      HgfastClientApiStateUnavailable() => '服务暂不可用，请稍后再试',
      _ => '发送失败，请稍后再试',
    };
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
      _errorMessage = null;
    });
    _messageController.clear();
    _scrollToBottom();

    final HgfastResult<HgfastAiResponse, HgfastError> result;
    try {
      result = await ref.read(hgfastRepositoryProvider).aiChat(message: text);
    } on Object catch (error) {
      // Defensive backstop, same reasoning as login_view.dart's
      // _handleLogin: don't let an exception below this layer leave
      // _isSending stuck true with no feedback.
      commonPrint.log(
        'aiChat threw: ${error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
        _errorMessage = '发送失败，请稍后再试';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    switch (result) {
      case HgfastResultSuccess<HgfastAiResponse, HgfastError>(:final value):
        final rawReply = value.values['reply'];
        final isFallback = value.values['fallback'] == true;
        final reply = rawReply is String && rawReply.trim().isNotEmpty
            ? rawReply.trim()
            : '暂时没有收到回复，请使用右上角"遇到问题？"联系人工客服。';
        setState(() {
          _isSending = false;
          _messages.add(
            _ChatMessage(text: reply, isUser: false, isFallback: isFallback),
          );
        });
      case HgfastResultFailure<HgfastAiResponse, HgfastError>(:final error):
        setState(() {
          _isSending = false;
          _errorMessage = _describeError(error);
        });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return HgfastAuthScope(
      child: CommonScaffold(
        title: appLocalizations.support,
        actions: const [AuthTroubleButton()],
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return const _TypingIndicatorBubble();
                  }
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: HgfastTextField(
                        controller: _messageController,
                        hintText: '输入你的问题…',
                        leadingIcon: Icons.chat_bubble_outline_rounded,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: HgfastSpacing.sm),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: HgfastGradientButton(
                        height: 52,
                        onPressed: _isSending ? null : _send,
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
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
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                gradient: HgfastGradients.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: isUser ? HgfastGradients.brand : null,
                color: isUser ? null : colorScheme.surface,
                border: isUser
                    ? null
                    : Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : colorScheme.onSurface,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: HgfastGradients.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outline),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }
}
