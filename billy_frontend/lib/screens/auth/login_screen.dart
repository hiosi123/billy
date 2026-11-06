import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../providers/app_provider.dart';
import '../../widgets/common.dart';
import '../../app/router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiService();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      showSnack(context, '아이디와 비밀번호를 입력해주세요', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _api.login(_username.text.trim(), _password.text);
      await AuthService.saveSession(res['access_token'], Map<String, dynamic>.from(res['user']));
      if (!mounted) return;
      context.read<AppProvider>().clear();
      authState.value = true;
      context.go('/');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BillyColors.headerGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BillySpace.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 로고
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: BillyColors.surface,
                      borderRadius: BorderRadius.circular(BillyRadius.xl),
                      boxShadow: BillyColors.glow(BillyColors.textPrimary),
                    ),
                    child: const Icon(Icons.apartment_rounded, size: 38, color: BillyColors.primary),
                  ),
                  const SizedBox(height: BillySpace.lg),
                  Text('Billy', style: BillyText.display.copyWith(color: BillyColors.onDark, fontSize: 32)),
                  const SizedBox(height: BillySpace.xs),
                  Text('검침부터 명세서까지, 우리 건물 방식대로', style: BillyText.body.copyWith(color: BillyColors.onDarkMuted)),
                  const SizedBox(height: BillySpace.xxl),
                  // 로그인 카드
                  Container(
                    decoration: BoxDecoration(color: BillyColors.surface, borderRadius: BorderRadius.circular(BillyRadius.xl)),
                    padding: const EdgeInsets.all(BillySpace.xl),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _username,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(labelText: '아이디', prefixIcon: Icon(Icons.person_outline, size: 20)),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: BillySpace.md),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(labelText: '비밀번호', prefixIcon: Icon(Icons.lock_outline, size: 20)),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: BillySpace.xl),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: BillyColors.onDark))
                                  : const Text('로그인'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
