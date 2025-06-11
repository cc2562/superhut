// token_display_page.dart
import 'package:flutter/material.dart';

import '../bridge/getCoursePage.dart';
import '../utils/token.dart';

class TokenDisplayPage extends StatefulWidget {
  final String token;
  final bool renew;

  const TokenDisplayPage({super.key, required this.token, required this.renew});

  @override
  State<TokenDisplayPage> createState() => _TokenDisplayPageState();
}

class _TokenDisplayPageState extends State<TokenDisplayPage> {
  @override
  void initState() {
    super.initState();
    saveToken(widget.token);
    if (widget.renew) {
      //  Navigator.pop(context,"200");
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => Getcoursepage(renew: false)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Token信息')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '获取到的Token:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.token,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
