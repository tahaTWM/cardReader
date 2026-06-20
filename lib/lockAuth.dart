import 'package:flutter/material.dart';

import 'package:local_auth/local_auth.dart';

/// Wraps any screen and requires the device's fingerprint / Face ID / PIN
/// before showing it. Usage:
///
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const LockScreen(child: CardsListScreen())),
/// );
/// ```
class LockScreen extends StatefulWidget {
  final Widget child;

  const LockScreen({super.key, required this.child});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isUnlocked = false;
  bool _isAuthenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Try to unlock automatically as soon as this screen opens.
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canCheckBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() {
          _isAuthenticating = false;
          _error = 'جهازك لا يدعم البصمة أو رمز القفل.';
        });
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'افتح القفل لعرض بطاقاتك',
        // false = يسمح أيضًا بالـ PIN/النمط كبديل عن البصمة، مو بصمة بس
        biometricOnly: false,
      );

      if (!mounted) return;
      setState(() {
        _isUnlocked = didAuthenticate;
        _isAuthenticating = false;
        if (!didAuthenticate) _error = 'فشلت عملية التحقق. حاول مرة أخرى.';
      });
    } on LocalAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _error = _arabicMessageFor(e.code);
      });
    }
  }

  String _arabicMessageFor(LocalAuthExceptionCode code) {
    if (code == LocalAuthExceptionCode.noBiometricHardware) {
      return 'جهازك لا يحتوي على خاصية بصمة أو تحقق بيومتري.';
    }
    if (code == LocalAuthExceptionCode.biometricLockout ||
        code == LocalAuthExceptionCode.temporaryLockout) {
      return 'تم إيقاف التحقق مؤقتًا بسبب محاولات كثيرة فاشلة. حاول لاحقًا.';
    }
    return 'تعذر التحقق من هويتك. حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    // Once unlocked, just show the real (protected) screen.
    if (_isUnlocked) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    size: 72, color: Colors.deepPurple),
                const SizedBox(height: 20),
                const Text(
                  'هذا القسم محمي',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'استخدم بصمتك أو رمز جهازك لعرض البطاقات المحفوظة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                _isAuthenticating
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('فتح القفل'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
