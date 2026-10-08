import 'package:flutter/material.dart';

import '../services/chat_lock_service.dart';
import 'chat_lock_dialogs.dart';

class ChatLockGate extends StatefulWidget {
  final String userId;
  final String conversationId;
  final ChatLockKind kind;
  final Widget child;
  final VoidCallback? onUnlocked;

  const ChatLockGate({
    super.key,
    required this.userId,
    required this.conversationId,
    required this.kind,
    required this.child,
    this.onUnlocked,
  });

  @override
  State<ChatLockGate> createState() => _ChatLockGateState();
}

class _ChatLockGateState extends State<ChatLockGate> {
  final ChatLockService _service = ChatLockService();
  bool _isReady = false;
  bool _isAuthorized = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    try {
      final enabled = await _service.isEnabled(
        userId: widget.userId,
        conversationId: widget.conversationId,
        kind: widget.kind,
      );
      if (!mounted) return;
      if (!enabled) {
        setState(() {
          _isReady = true;
          _isAuthorized = true;
        });
        widget.onUnlocked?.call();
        return;
      }
      setState(() {
        _isReady = true;
        _isChecking = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not check chat lock: $error')),
      );
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _authenticate() async {
    bool authorized;
    try {
      authorized = await ChatLockDialogs.authenticate(
        context,
        service: _service,
        userId: widget.userId,
        conversationId: widget.conversationId,
        kind: widget.kind,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not unlock chat: $error')));
      Navigator.of(context).maybePop();
      return;
    }
    if (!mounted) return;
    if (!authorized) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _isAuthorized = true;
      _isChecking = false;
    });
    widget.onUnlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady && _isAuthorized) return widget.child;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: _isChecking
            ? const CircularProgressIndicator(color: Color(0xFF5A4BFF))
            : const CircularProgressIndicator(color: Color(0xFF5A4BFF)),
      ),
    );
  }
}
