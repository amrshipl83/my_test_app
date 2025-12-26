// lib/widgets/chat_support_widget.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';

class ChatSupportWidget extends StatefulWidget {
  const ChatSupportWidget({super.key});

  @override
  State<ChatSupportWidget> createState() => _ChatSupportWidgetState();
}

class _ChatSupportWidgetState extends State<ChatSupportWidget> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final String apiGatewayUrl = "https://st6zcrb8k1.execute-api.us-east-1.amazonaws.com/dev/chat";

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });
    _controller.clear();

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
      } else {
        throw "Error: ${response.statusCode}";
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "text": "عذراً، حدث خطأ في الاتصال."});
      });
    } finally {
      setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.h,
      padding: EdgeInsets.all(4.w),
      child: Column(
        children: [
          // رأس الشات
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          SizedBox(height: 2.h),
          Text("مساعد أكسب الذكي", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.green[800])),
          Divider(),
          // قائمة الرسائل
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                bool isUser = _messages[i]['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.green[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(_messages[i]['text']!, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          if (_isTyping) LinearProgressIndicator(color: Colors.green, backgroundColor: Colors.green[50]),
          // صندوق الإرسال
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: "اكتب سؤالك هنا...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
                  ),
                ),
                IconButton(onPressed: _sendMessage, icon: Icon(Icons.send, color: Colors.green, size: 25.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

