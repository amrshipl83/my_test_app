import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';

class ChatSupportWidget extends StatefulWidget {
  const ChatSupportWidget({super.key});

  @override
  State<ChatSupportWidget> createState() => _ChatSupportWidgetState();
}

class _ChatSupportWidgetState extends State<ChatSupportWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // 🎯 للتحكم في التمرير
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final String apiGatewayUrl = "https://st6zcrb8k1.execute-api.us-east-1.amazonaws.com/dev/chat";

  // دالة التمرير التلقائي لأسفل
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse(apiGatewayUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({"message": text}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({"role": "bot", "text": data['message'] ?? "لا يوجد رد"});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "text": "عذراً، حدث خطأ في الاتصال."});
      });
    } finally {
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85.h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // الهيدر المحسن
              _buildHeader(),
              
              // منطقة الرسائل
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final msg = _messages[i];
                    return _buildMessageBubble(msg['text']!, msg['role'] == 'user');
                  },
                ),
              ),

              if (_isTyping) _buildTypingIndicator(),

              // منطقة الإدخال
              _buildInputSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(height: 1.5.h),
        Container(
          width: 45,
          height: 5,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Text(
            "مساعد أكسب الذكي",
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.green[900]),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 75.w),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? Colors.green[700] : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.4, // تباعد أسطر ممتاز
            fontWeight: FontWeight.w500,
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 6.w, bottom: 1.h),
      child: Text("جاري الكتابة...", style: TextStyle(fontSize: 9.sp, color: Colors.grey[600], fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.only(
        left: 4.w, right: 4.w, top: 1.5.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 2.h,
      ),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
      ]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "اسأل عن أسعار الجملة أو التسجيل...",
                hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          GestureDetector(
            onTap: _sendMessage,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.green[700],
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
