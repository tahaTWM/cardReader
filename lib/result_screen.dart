import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'card_parser.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final String cardNumber;
  final String? expiryDate;
  final String? cardHolderName;
  final String imagePath;
  final int cardType;

  const ResultScreen({
    super.key,
    required this.cardNumber,
    required this.imagePath,
    this.expiryDate,
    this.cardHolderName,
    this.cardType = 0,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  initState() {
    setState(() {
      CardParser.cards.add(widget.cardNumber.toString());
    });
    super.initState();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Copy: puts the value on the clipboard, leaves the list untouched.
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Cut: copies the value, then removes it from the source list.
  Future<void> cutToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanned card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(widget.imagePath),
                  height: 160, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width - 100,
                  height: 300,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text(
                          CardParser.cards.reversed
                              .toList()
                              .join('\n')
                              .toString(),
                          style: const TextStyle(
                            fontSize: 22,
                          )),
                    ),
                  ),
                ),
                SizedBox(
                    width: 40,
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.green),
                          onPressed: () {
                            copyToClipboard(
                                CardParser.cards.reversed.toList().toString());
                            _showSnack('Copied to clipboard');
                          },
                        ),
                        const SizedBox(height: 10),
                        IconButton(
                          icon: const Icon(Icons.cut, color: Colors.blue),
                          onPressed: () {
                            cutToClipboard(
                                CardParser.cards.reversed.toList().toString());
                            setState(() {
                              CardParser.cards.clear();
                            });
                            _showSnack('Cuted to clipboard');
                          },
                        ),
                        const SizedBox(height: 10),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              CardParser.cards.clear();
                            });
                            _showSnack('Delete');
                          },
                        ),
                      ],
                    )),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(widget.cardType == 0
                    ? 'Scan another Qi card'
                    : 'Scan another MC/Co-badge card'),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Home Screen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
