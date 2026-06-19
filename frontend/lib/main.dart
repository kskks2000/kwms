import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/firebase_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = await FirebaseAuthService.initialize();
  runApp(KwmsApp(authService: authService));
}

class KwmsApp extends StatelessWidget {
  const KwmsApp({super.key, this.authService});

  final FirebaseAuthService? authService;

  static const Color brandOrange = Color(0xFFC97045);
  static const Color brandOrangeDark = Color(0xFF9E4F2F);
  static const Color ink = Color(0xFF1F2528);
  static const Color steel = Color(0xFF48646B);
  static const Color surface = Color(0xFFFFFBF7);
  static const Color fieldFill = Color(0xFFF7F1EC);

  static bool get _dashboardPreviewEnabled {
    var enabled = false;
    assert(() {
      enabled = const bool.fromEnvironment('KWMS_DASHBOARD_PREVIEW');
      return true;
    }());
    return enabled;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: brandOrange,
          brightness: Brightness.light,
        ).copyWith(
          primary: brandOrange,
          onPrimary: Colors.white,
          secondary: steel,
          surface: surface,
          onSurface: ink,
        );

    return MaterialApp(
      title: 'KWMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F0EA),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: fieldFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2D7CF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2D7CF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: brandOrange, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFB84032)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          labelStyle: const TextStyle(color: Color(0xFF566267)),
          prefixIconColor: const Color(0xFF7A6A60),
          suffixIconColor: const Color(0xFF7A6A60),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: brandOrangeDark,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: _dashboardPreviewEnabled
          ? WmsDashboardScreen(
              profile: const DashboardUserProfile(
                name: 'KWMS 운영관리자',
                email: 'ops.manager@metaseoul.net',
                emailVerified: true,
              ),
              onSignOut: () async {},
            )
          : AuthGate(
              authService: authService ?? FirebaseAuthService.unconfigured(),
            ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authService});

  final FirebaseAuthService authService;

  @override
  Widget build(BuildContext context) {
    if (!authService.isConfigured) {
      return LoginScreen(authService: authService);
    }

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(authService: authService);
        }

        return SignedInScreen(authService: authService, user: user);
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

enum _AuthMode { signIn, signUp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final FirebaseAuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  _AuthMode _authMode = _AuthMode.signIn;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberLogin = true;
  bool _isSigningIn = false;
  String _warehouse = 'main';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isSignUp => _authMode == _AuthMode.signUp;

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await _runAuthRequest(() async {
      await widget.authService.setRememberLogin(_rememberLogin);
      return widget.authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    });
  }

  Future<void> _submitSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await _runAuthRequest(() {
      return widget.authService.signUpWithEmail(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    });
  }

  void _setAuthMode(_AuthMode mode) {
    if (_authMode == mode || _isSigningIn) {
      return;
    }

    setState(() {
      _authMode = mode;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submitGoogle() {
    return _runAuthRequest(() async {
      await widget.authService.setRememberLogin(_rememberLogin);
      return widget.authService.signInWithGoogle();
    });
  }

  Future<void> _runAuthRequest(Future<Object?> Function() request) async {
    if (_isSigningIn) {
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    try {
      await request();
    } on FirebaseAuthException catch (error) {
      _showAuthError(_firebaseErrorMessage(error));
    } on AuthUnavailableException catch (error) {
      _showAuthError(error.message);
    } catch (_) {
      _showAuthError('인증 처리 중 문제가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  void _showAuthError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => '이메일 형식을 확인하세요.',
      'invalid-credential' => '이메일 또는 비밀번호가 올바르지 않습니다.',
      'email-already-in-use' => '이미 가입된 이메일입니다.',
      'user-disabled' => '비활성화된 계정입니다.',
      'user-not-found' => '등록된 계정을 찾을 수 없습니다.',
      'weak-password' => '비밀번호는 6자 이상으로 설정하세요.',
      'wrong-password' => '비밀번호가 올바르지 않습니다.',
      'popup-closed-by-user' => 'Google 로그인 창이 닫혔습니다.',
      'operation-not-allowed' => 'Firebase Console에서 로그인 제공자를 활성화하세요.',
      'too-many-requests' => '요청이 많습니다. 잠시 후 다시 시도하세요.',
      _ => '인증에 실패했습니다. (${error.code})',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;

          if (isWide) {
            return Row(
              children: const [
                Expanded(flex: 11, child: _OperationsPanel()),
                Expanded(flex: 9, child: _LoginPane()),
              ],
            );
          }

          return const _MobileLoginLayout();
        },
      ),
    );
  }
}

class _MobileLoginLayout extends StatelessWidget {
  const _MobileLoginLayout();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_CompactBrandHeader(), SizedBox(height: 22), _LoginForm()],
        ),
      ),
    );
  }
}

class _LoginPane extends StatelessWidget {
  const _LoginPane();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 42, vertical: 32),
            child: _LoginForm(),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  _LoginScreenState get _screenState =>
      context.findAncestorStateOfType<_LoginScreenState>()!;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isSignUp = _screenState._isSignUp;

    return Form(
      key: _screenState._formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.sizeOf(context).width >= 920) ...[
            const _BrandLockup(),
            const SizedBox(height: 52),
          ],
          Text(
            isSignUp ? '회원가입' : '로그인',
            style: textTheme.headlineMedium?.copyWith(
              color: KwmsApp.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSignUp ? 'KWMS 작업 계정을 생성하세요.' : '창고 운영 계정으로 접속하세요.',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF69767B),
              height: 1.4,
            ),
          ),
          if (!_screenState.widget.authService.isConfigured) ...[
            const SizedBox(height: 18),
            _FirebaseSetupNotice(
              message:
                  _screenState.widget.authService.configurationMessage ??
                  'Firebase 연결 대기',
            ),
          ],
          const SizedBox(height: 24),
          SegmentedButton<_AuthMode>(
            segments: const [
              ButtonSegment<_AuthMode>(
                value: _AuthMode.signIn,
                icon: Icon(Icons.login_rounded),
                label: Text('로그인'),
              ),
              ButtonSegment<_AuthMode>(
                value: _AuthMode.signUp,
                icon: Icon(Icons.person_add_alt_1_rounded),
                label: Text('회원가입'),
              ),
            ],
            selected: {_screenState._authMode},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return KwmsApp.brandOrangeDark;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return KwmsApp.brandOrange;
                }
                return const Color(0xFFFFF6EF);
              }),
              side: WidgetStateProperty.all(
                const BorderSide(color: Color(0xFFD8C9BF)),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            onSelectionChanged: (selection) {
              _screenState._setAuthMode(selection.first);
            },
          ),
          const SizedBox(height: 18),
          if (isSignUp) ...[
            TextFormField(
              controller: _screenState._nameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: '이름',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (!isSignUp) {
                  return null;
                }
                if (value == null || value.trim().isEmpty) {
                  return '이름을 입력하세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _screenState._emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: '이메일',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return '이메일을 입력하세요.';
              }
              if (!email.contains('@')) {
                return '이메일 형식을 확인하세요.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _screenState._passwordController,
            obscureText: _screenState._obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: '비밀번호',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _screenState._obscurePassword ? '보기' : '숨기기',
                onPressed: () {
                  setState(() {
                    _screenState._obscurePassword =
                        !_screenState._obscurePassword;
                  });
                },
                icon: Icon(
                  _screenState._obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '비밀번호를 입력하세요.';
              }
              if (isSignUp && value.length < 6) {
                return '비밀번호는 6자 이상이어야 합니다.';
              }
              return null;
            },
            onFieldSubmitted: (_) => isSignUp
                ? _screenState._submitSignUp()
                : _screenState._submitEmailPassword(),
          ),
          if (isSignUp) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _screenState._confirmPasswordController,
              obscureText: _screenState._obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  tooltip: _screenState._obscureConfirmPassword ? '보기' : '숨기기',
                  onPressed: () {
                    setState(() {
                      _screenState._obscureConfirmPassword =
                          !_screenState._obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _screenState._obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (!isSignUp) {
                  return null;
                }
                if (value == null || value.isEmpty) {
                  return '비밀번호를 한 번 더 입력하세요.';
                }
                if (value != _screenState._passwordController.text) {
                  return '비밀번호가 일치하지 않습니다.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _screenState._submitSignUp(),
            ),
          ] else ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _screenState._warehouse,
              decoration: const InputDecoration(
                labelText: '작업 창고',
                prefixIcon: Icon(Icons.warehouse_outlined),
              ),
              borderRadius: BorderRadius.circular(8),
              items: const [
                DropdownMenuItem(value: 'main', child: Text('서울 허브센터')),
                DropdownMenuItem(value: 'cold', child: Text('냉장 자동화센터')),
                DropdownMenuItem(value: 'return', child: Text('반품 검수센터')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _screenState._warehouse = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _screenState._rememberLogin,
                  activeColor: KwmsApp.brandOrange,
                  side: const BorderSide(color: Color(0xFFCDBEB4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _screenState._rememberLogin = value ?? false;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    '로그인 유지',
                    style: TextStyle(
                      color: Color(0xFF455057),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('계정 찾기')),
              ],
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _screenState._isSigningIn
                ? null
                : isSignUp
                ? _screenState._submitSignUp
                : _screenState._submitEmailPassword,
            icon: _screenState._isSigningIn
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isSignUp
                        ? Icons.person_add_alt_1_rounded
                        : Icons.login_rounded,
                  ),
            label: Text(
              _screenState._isSigningIn
                  ? '처리 중'
                  : isSignUp
                  ? '이메일로 가입'
                  : '이메일 로그인',
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _screenState._isSigningIn
                ? null
                : _screenState._submitGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: Text(isSignUp ? 'Google로 가입/로그인' : 'Google로 로그인'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KwmsApp.ink,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Color(0xFFD8C9BF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (!isSignUp) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _screenState._isSigningIn ? null : () {},
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('작업자 카드로 접속'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5D666A),
                minimumSize: const Size.fromHeight(44),
                side: const BorderSide(color: Color(0xFFD8C9BF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 30),
          const _SecurityStrip(),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _WarehouseLogo(size: 54),
        SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KWMS',
              style: TextStyle(
                color: KwmsApp.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '창고관리 시스템',
              style: TextStyle(
                color: Color(0xFF69767B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _WarehouseLogo(size: 48),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KWMS',
                style: TextStyle(
                  color: KwmsApp.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '창고관리 시스템',
                style: TextStyle(
                  color: Color(0xFF69767B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarehouseLogo extends StatelessWidget {
  const _WarehouseLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'KWMS',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _WarehouseLogoPainter()),
      ),
    );
  }
}

class _WarehouseLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(width * .18),
    );

    final shadowPaint = Paint()
      ..color = const Color(0x269E4F2F)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * .16);
    canvas.drawRRect(outer.shift(Offset(0, width * .08)), shadowPaint);

    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE38554), Color(0xFFC97045), Color(0xFF9E4F2F)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(outer, basePaint);

    final sheenPath = Path()
      ..moveTo(width * .1, width * .04)
      ..lineTo(width * .83, width * .04)
      ..lineTo(width * .35, width * .48)
      ..lineTo(width * .1, width * .38)
      ..close();
    canvas.drawPath(
      sheenPath,
      Paint()..color = Colors.white.withValues(alpha: .12),
    );

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * .025;
    canvas.drawRRect(outer.deflate(width * .015), borderPaint);

    final markShadow = Paint()
      ..color = const Color(0x309E4F2F)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * .04);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(width * .27, width * .39, width * .46, width * .34),
      Radius.circular(width * .075),
    );
    canvas.drawRRect(bodyRect.shift(Offset(0, width * .025)), markShadow);

    final creamPaint = Paint()..color = const Color(0xFFFFF5EB);
    final roofPath = Path()
      ..moveTo(width * .22, width * .43)
      ..lineTo(width * .5, width * .25)
      ..lineTo(width * .78, width * .43)
      ..lineTo(width * .72, width * .5)
      ..lineTo(width * .5, width * .36)
      ..lineTo(width * .28, width * .5)
      ..close();
    canvas.drawPath(roofPath, creamPaint);
    canvas.drawRRect(bodyRect, creamPaint);

    final detailPaint = Paint()
      ..color = const Color(0xFFC97045)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * .042;
    canvas.drawLine(
      Offset(width * .36, width * .51),
      Offset(width * .36, width * .62),
      detailPaint,
    );
    canvas.drawLine(
      Offset(width * .64, width * .51),
      Offset(width * .64, width * .62),
      detailPaint,
    );
    canvas.drawLine(
      Offset(width * .42, width * .56),
      Offset(width * .58, width * .56),
      detailPaint,
    );

    final boxPaint = Paint()..color = const Color(0xFFFFD8BE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * .41, width * .61, width * .18, width * .16),
        Radius.circular(width * .035),
      ),
      boxPaint,
    );
    canvas.drawLine(
      Offset(width * .5, width * .62),
      Offset(width * .5, width * .75),
      Paint()
        ..color = const Color(0xFFC97045)
        ..strokeWidth = width * .025,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF263134)),
      child: Stack(
        children: [
          const Positioned.fill(child: _WarehouseGridBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 46, 48, 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandLockupOnDark(),
                  const Spacer(),
                  Text(
                    '오늘의 물류 흐름',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      '입고부터 출하까지 한 화면에서 이어지는 KWMS 운영 콘솔',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFD7E2E2),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _DockFlowBoard(),
                  const SizedBox(height: 28),
                  const _MetricRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLockupOnDark extends StatelessWidget {
  const _BrandLockupOnDark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _WarehouseLogo(size: 46),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KWMS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Warehouse Management',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFBFCAC9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarehouseGridBackground extends StatelessWidget {
  const _WarehouseGridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WarehouseGridPainter());
  }
}

class _WarehouseGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x1FFFFFFF)
      ..strokeWidth = 1;
    final railPaint = Paint()
      ..color = const Color(0x24C97045)
      ..strokeWidth = 2;
    final glowPaint = Paint()
      ..color = const Color(0x22C97045)
      ..style = PaintingStyle.fill;

    for (double x = -size.height; x < size.width; x += 46) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        gridPaint,
      );
    }

    for (double y = 48; y < size.height; y += 82) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), railPaint);
    }

    canvas.drawCircle(
      Offset(size.width * .82, size.height * .22),
      150,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .18, size.height * .82),
      110,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DockFlowBoard extends StatelessWidget {
  const _DockFlowBoard();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _FlowStep(
        icon: Icons.move_to_inbox_rounded,
        title: '입고',
        value: '128',
        accent: Color(0xFFFFB37D),
      ),
      _FlowStep(
        icon: Icons.inventory_2_outlined,
        title: '적치',
        value: '92',
        accent: Color(0xFF9ED0C6),
      ),
      _FlowStep(
        icon: Icons.qr_code_2_rounded,
        title: '피킹',
        value: '316',
        accent: Color(0xFFFFD27D),
      ),
      _FlowStep(
        icon: Icons.local_shipping_outlined,
        title: '출하',
        value: '74',
        accent: Color(0xFFA8BDD0),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6303C3F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              Expanded(child: steps[index]),
              if (index < steps.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0x88FFFFFF),
                    size: 22,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: accent, size: 22),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFC8D4D3),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _MetricTile(label: '재고 정확도', value: '99.2%'),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MetricTile(label: '출하 SLA', value: '97.8%'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x26394648),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.verified_outlined,
              color: Color(0xFFFFB37D),
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFCAD5D4),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignedInScreen extends StatelessWidget {
  const SignedInScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final FirebaseAuthService authService;
  final User user;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName?.trim();
    final title = displayName == null || displayName.isEmpty
        ? user.email ?? 'KWMS 사용자'
        : displayName;

    return WmsDashboardScreen(
      profile: DashboardUserProfile(
        name: title,
        email: user.email ?? user.uid,
        photoUrl: user.photoURL,
        emailVerified: user.emailVerified,
      ),
      onSignOut: authService.signOut,
    );
  }
}

class DashboardUserProfile {
  const DashboardUserProfile({
    required this.name,
    required this.email,
    required this.emailVerified,
    this.photoUrl,
  });

  final String name;
  final String email;
  final String? photoUrl;
  final bool emailVerified;
}

class _TenantContext {
  const _TenantContext({
    required this.code,
    required this.name,
    required this.legalName,
    required this.planLabel,
    required this.scopeLabel,
    required this.defaultWarehouse,
    required this.warehouses,
    required this.owners,
    required this.badgeColor,
  });

  final String code;
  final String name;
  final String legalName;
  final String planLabel;
  final String scopeLabel;
  final String defaultWarehouse;
  final List<String> warehouses;
  final List<String> owners;
  final Color badgeColor;
}

const _tenantContexts = [
  _TenantContext(
    code: 'META',
    name: '메타서울 운영',
    legalName: 'Meta Seoul KWMS',
    planLabel: 'Enterprise',
    scopeLabel: '수도권 풀필먼트',
    defaultWarehouse: '서울 허브센터',
    warehouses: ['서울 허브센터', '냉장 자동화센터', '반품 검수센터'],
    owners: ['Meta Seoul Retail', 'Fresh Prime'],
    badgeColor: KwmsApp.brandOrange,
  ),
  _TenantContext(
    code: 'FRESH',
    name: '프레시 프라임',
    legalName: 'Fresh Prime Logistics',
    planLabel: 'Cold Chain',
    scopeLabel: '신선물류 전용',
    defaultWarehouse: '프레시 동탄센터',
    warehouses: ['프레시 동탄센터', '냉동 안성센터', '새벽배송 크로스독'],
    owners: ['Fresh Prime', 'Daily Market'],
    badgeColor: Color(0xFF2F8F6B),
  ),
  _TenantContext(
    code: 'GLOBAL',
    name: '글로벌 파츠',
    legalName: 'Global Parts Korea',
    planLabel: 'B2B',
    scopeLabel: '부품/설비 물류',
    defaultWarehouse: '부품 중앙센터',
    warehouses: ['부품 중앙센터', '수출 포장센터', 'A/S 반품센터'],
    owners: ['Global Parts Korea', 'Factory Service'],
    badgeColor: Color(0xFF477DA8),
  ),
];

class WmsDashboardScreen extends StatefulWidget {
  const WmsDashboardScreen({
    super.key,
    required this.profile,
    required this.onSignOut,
  });

  final DashboardUserProfile profile;
  final Future<void> Function() onSignOut;

  @override
  State<WmsDashboardScreen> createState() => _WmsDashboardScreenState();
}

class _WmsDashboardScreenState extends State<WmsDashboardScreen> {
  int _selectedIndex = 0;
  late _TenantContext _tenant = _tenantContexts.first;
  late String _warehouse = _tenant.defaultWarehouse;

  static const _navItems = [
    _DashboardNavItem(
      icon: Icons.space_dashboard_outlined,
      activeIcon: Icons.space_dashboard_rounded,
      label: '대시보드',
    ),
    _DashboardNavItem(
      icon: Icons.manage_search_outlined,
      activeIcon: Icons.manage_search_rounded,
      label: '마스터 관리',
    ),
    _DashboardNavItem(
      icon: Icons.move_to_inbox_outlined,
      activeIcon: Icons.move_to_inbox_rounded,
      label: '입고관리',
    ),
    _DashboardNavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: '재고관리',
    ),
    _DashboardNavItem(
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping_rounded,
      label: '출하관리',
    ),
    _DashboardNavItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics_rounded,
      label: '분석',
    ),
  ];

  void _changeTenant(_TenantContext tenant) {
    setState(() {
      _tenant = tenant;
      _warehouse = tenant.warehouses.contains(_warehouse)
          ? _warehouse
          : tenant.defaultWarehouse;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1120;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F7),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex.clamp(0, 4),
                  height: 68,
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0xFFFFE5D4),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: '홈',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.manage_search_outlined),
                      selectedIcon: Icon(Icons.manage_search_rounded),
                      label: '마스터',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.move_to_inbox_outlined),
                      selectedIcon: Icon(Icons.move_to_inbox_rounded),
                      label: '입고',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: '재고',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.local_shipping_outlined),
                      selectedIcon: Icon(Icons.local_shipping_rounded),
                      label: '출하',
                    ),
                  ],
                  onDestinationSelected: (value) {
                    setState(() {
                      _selectedIndex = value;
                    });
                  },
                ),
          body: SafeArea(
            child: isDesktop
                ? Row(
                    children: [
                      _DashboardSidebar(
                        selectedIndex: _selectedIndex,
                        items: _navItems,
                        profile: widget.profile,
                        tenant: _tenant,
                        onSelected: (value) {
                          setState(() {
                            _selectedIndex = value;
                          });
                        },
                        onSignOut: widget.onSignOut,
                      ),
                      Expanded(
                        child: _WorkspaceContent(
                          selectedIndex: _selectedIndex,
                          profile: widget.profile,
                          tenant: _tenant,
                          tenants: _tenantContexts,
                          warehouse: _warehouse,
                          isDesktop: true,
                          onTenantChanged: _changeTenant,
                          onWarehouseChanged: (value) {
                            setState(() {
                              _warehouse = value;
                            });
                          },
                          onSignOut: widget.onSignOut,
                        ),
                      ),
                    ],
                  )
                : _WorkspaceContent(
                    selectedIndex: _selectedIndex,
                    profile: widget.profile,
                    tenant: _tenant,
                    tenants: _tenantContexts,
                    warehouse: _warehouse,
                    isDesktop: false,
                    onTenantChanged: _changeTenant,
                    onWarehouseChanged: (value) {
                      setState(() {
                        _warehouse = value;
                      });
                    },
                    onSignOut: widget.onSignOut,
                  ),
          ),
        );
      },
    );
  }
}

class _DashboardNavItem {
  const _DashboardNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.selectedIndex,
    required this.items,
    required this.profile,
    required this.tenant,
    required this.onSelected,
    required this.onSignOut,
  });

  final int selectedIndex;
  final List<_DashboardNavItem> items;
  final DashboardUserProfile profile;
  final _TenantContext tenant;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      color: const Color(0xFF20292C),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandLockupOnDark(),
            const SizedBox(height: 30),
            for (var index = 0; index < items.length; index++) ...[
              _SidebarNavButton(
                item: items[index],
                selected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
              const SizedBox(height: 6),
            ],
            const Spacer(),
            _SidebarStatusPanel(tenant: tenant),
            const SizedBox(height: 14),
            _SidebarUserTile(profile: profile, onSignOut: onSignOut),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavButton extends StatelessWidget {
  const _SidebarNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _DashboardNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          selected ? item.activeIcon : item.icon,
          color: selected ? Colors.white : const Color(0xFFBBC7C7),
          size: 21,
        ),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFBBC7C7),
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: selected
              ? KwmsApp.brandOrange
              : Colors.white.withValues(alpha: .04),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _SidebarStatusPanel extends StatelessWidget {
  const _SidebarStatusPanel({required this.tenant});

  final _TenantContext tenant;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: tenant.badgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tenant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${tenant.code} · ${tenant.scopeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC1CCCC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'RLS 스코프 · ${tenant.planLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8FA1A1),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarUserTile extends StatelessWidget {
  const _SidebarUserTile({required this.profile, required this.onSignOut});

  final DashboardUserProfile profile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _UserAvatar(profile: profile, radius: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                profile.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB7C1C1),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '로그아웃',
          onPressed: () async {
            await onSignOut();
          },
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFB7C1C1)),
        ),
      ],
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.selectedIndex,
    required this.profile,
    required this.tenant,
    required this.tenants,
    required this.warehouse,
    required this.isDesktop,
    required this.onTenantChanged,
    required this.onWarehouseChanged,
    required this.onSignOut,
  });

  final int selectedIndex;
  final DashboardUserProfile profile;
  final _TenantContext tenant;
  final List<_TenantContext> tenants;
  final String warehouse;
  final bool isDesktop;
  final ValueChanged<_TenantContext> onTenantChanged;
  final ValueChanged<String> onWarehouseChanged;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 1) {
      return _MasterManagementContent(
        profile: profile,
        tenant: tenant,
        tenants: tenants,
        warehouse: warehouse,
        isDesktop: isDesktop,
        onTenantChanged: onTenantChanged,
        onWarehouseChanged: onWarehouseChanged,
        onSignOut: onSignOut,
      );
    }

    return _DashboardContent(
      profile: profile,
      tenant: tenant,
      tenants: tenants,
      warehouse: warehouse,
      isDesktop: isDesktop,
      onTenantChanged: onTenantChanged,
      onWarehouseChanged: onWarehouseChanged,
      onSignOut: onSignOut,
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.profile,
    required this.tenant,
    required this.tenants,
    required this.warehouse,
    required this.isDesktop,
    required this.onTenantChanged,
    required this.onWarehouseChanged,
    required this.onSignOut,
  });

  final DashboardUserProfile profile;
  final _TenantContext tenant;
  final List<_TenantContext> tenants;
  final String warehouse;
  final bool isDesktop;
  final ValueChanged<_TenantContext> onTenantChanged;
  final ValueChanged<String> onWarehouseChanged;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 22 : 18,
        isDesktop ? 20 : 16,
        isDesktop ? 22 : 18,
        isDesktop ? 34 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardTopBar(
            profile: profile,
            tenant: tenant,
            tenants: tenants,
            warehouse: warehouse,
            isDesktop: isDesktop,
            onTenantChanged: onTenantChanged,
            onWarehouseChanged: onWarehouseChanged,
            onSignOut: onSignOut,
          ),
          const SizedBox(height: 16),
          _QuickActionBar(isDesktop: isDesktop),
          const SizedBox(height: 16),
          const _KpiGrid(),
          const SizedBox(height: 16),
          if (isDesktop)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _PipelinePanel()),
                SizedBox(width: 16),
                Expanded(flex: 5, child: _ExceptionPanel()),
              ],
            )
          else ...[
            const _PipelinePanel(),
            const SizedBox(height: 16),
            const _ExceptionPanel(),
          ],
          const SizedBox(height: 16),
          if (isDesktop)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _StorageUtilizationPanel()),
                SizedBox(width: 16),
                Expanded(flex: 6, child: _DockSchedulePanel()),
              ],
            )
          else ...[
            const _StorageUtilizationPanel(),
            const SizedBox(height: 16),
            const _DockSchedulePanel(),
          ],
        ],
      ),
    );
  }
}

enum _MasterType { warehouse, owner, product, uom, location, carrier, supplier }

class _MasterDefinition {
  const _MasterDefinition({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    required this.detailLabel,
    required this.attributeLabel,
  });

  final _MasterType type;
  final String label;
  final String description;
  final IconData icon;
  final String detailLabel;
  final String attributeLabel;
}

class _MasterRecord {
  const _MasterRecord({
    required this.code,
    required this.name,
    required this.detail,
    required this.attribute,
    required this.active,
    required this.updatedAt,
  });

  final String code;
  final String name;
  final String detail;
  final String attribute;
  final bool active;
  final String updatedAt;

  _MasterRecord copyWith({
    String? code,
    String? name,
    String? detail,
    String? attribute,
    bool? active,
    String? updatedAt,
  }) {
    return _MasterRecord(
      code: code ?? this.code,
      name: name ?? this.name,
      detail: detail ?? this.detail,
      attribute: attribute ?? this.attribute,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class _MasterManagementContent extends StatefulWidget {
  const _MasterManagementContent({
    required this.profile,
    required this.tenant,
    required this.tenants,
    required this.warehouse,
    required this.isDesktop,
    required this.onTenantChanged,
    required this.onWarehouseChanged,
    required this.onSignOut,
  });

  final DashboardUserProfile profile;
  final _TenantContext tenant;
  final List<_TenantContext> tenants;
  final String warehouse;
  final bool isDesktop;
  final ValueChanged<_TenantContext> onTenantChanged;
  final ValueChanged<String> onWarehouseChanged;
  final Future<void> Function() onSignOut;

  @override
  State<_MasterManagementContent> createState() =>
      _MasterManagementContentState();
}

class _MasterManagementContentState extends State<_MasterManagementContent> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _detailController = TextEditingController();
  final _attributeController = TextEditingController();

  _MasterType _selectedType = _MasterType.warehouse;
  String? _editingCode;
  bool _active = true;

  static const _definitions = [
    _MasterDefinition(
      type: _MasterType.warehouse,
      label: '창고',
      description: '센터, 보관 유형, 운영 범위',
      icon: Icons.warehouse_outlined,
      detailLabel: '보관 유형',
      attributeLabel: '면적/용량',
    ),
    _MasterDefinition(
      type: _MasterType.owner,
      label: '화주',
      description: '고객사, 계약 서비스, SLA',
      icon: Icons.business_center_outlined,
      detailLabel: '서비스 유형',
      attributeLabel: '월 처리량',
    ),
    _MasterDefinition(
      type: _MasterType.product,
      label: '제품',
      description: 'SKU, 온도대, 로트 정책',
      icon: Icons.inventory_2_outlined,
      detailLabel: '기준 단위',
      attributeLabel: '관리 정책',
    ),
    _MasterDefinition(
      type: _MasterType.uom,
      label: 'UOM',
      description: 'EA, BOX, PLT 변환 기준',
      icon: Icons.straighten_outlined,
      detailLabel: '단위 구분',
      attributeLabel: '환산 수량',
    ),
    _MasterDefinition(
      type: _MasterType.location,
      label: '로케이션',
      description: '존, 랙, 셀, 피킹 위치',
      icon: Icons.my_location_outlined,
      detailLabel: '작업 구분',
      attributeLabel: '현재 사용률',
    ),
    _MasterDefinition(
      type: _MasterType.carrier,
      label: '운송사',
      description: '택배사, 차량, 도크 예약',
      icon: Icons.local_shipping_outlined,
      detailLabel: '운송 유형',
      attributeLabel: '리드타임',
    ),
    _MasterDefinition(
      type: _MasterType.supplier,
      label: '공급사',
      description: '매입처, 입고 예약, 검수 기준',
      icon: Icons.factory_outlined,
      detailLabel: '공급 유형',
      attributeLabel: '검수 등급',
    ),
  ];

  late final Map<String, Map<_MasterType, List<_MasterRecord>>>
  _recordsByTenant = {
    for (final tenant in _tenantContexts) tenant.code: _seedRecords(tenant),
  };

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _detailController.dispose();
    _attributeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MasterManagementContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenant.code != widget.tenant.code) {
      _selectedType = _MasterType.warehouse;
      _clearForm(resetState: false);
    }
  }

  static Map<_MasterType, List<_MasterRecord>> _seedRecords(
    _TenantContext tenant,
  ) {
    final secondaryWarehouse = tenant.warehouses.length > 1
        ? tenant.warehouses[1]
        : tenant.defaultWarehouse;
    final primaryOwner = tenant.owners.first;
    final secondaryOwner = tenant.owners.length > 1
        ? tenant.owners[1]
        : tenant.owners.first;

    return {
      _MasterType.warehouse: [
        _MasterRecord(
          code: 'WH-${tenant.code}',
          name: tenant.defaultWarehouse,
          detail: tenant.scopeLabel,
          attribute: tenant.code == 'FRESH' ? '18,500 m²' : '42,000 m²',
          active: true,
          updatedAt: '오늘 09:12',
        ),
        _MasterRecord(
          code: 'WH-${tenant.code}-SUB',
          name: secondaryWarehouse,
          detail: tenant.code == 'GLOBAL' ? '포장/반품' : '냉장/냉동',
          attribute: tenant.code == 'GLOBAL' ? '12,400 m²' : '18,500 m²',
          active: true,
          updatedAt: '어제 18:04',
        ),
      ],
      _MasterType.owner: [
        _MasterRecord(
          code: 'OWN-${tenant.code}',
          name: primaryOwner,
          detail: tenant.planLabel,
          attribute: tenant.code == 'GLOBAL' ? '월 36K건' : '월 125K건',
          active: true,
          updatedAt: '오늘 08:30',
        ),
        _MasterRecord(
          code: 'OWN-${tenant.code}-02',
          name: secondaryOwner,
          detail: tenant.scopeLabel,
          attribute: tenant.code == 'FRESH' ? '월 82K건' : '월 48K건',
          active: true,
          updatedAt: '06.17 15:20',
        ),
      ],
      _MasterType.product: [
        _MasterRecord(
          code: 'SKU-${tenant.code}-100',
          name: tenant.code == 'GLOBAL' ? '정밀 베어링 세트' : '프리미엄 라운드 박스',
          detail: 'EA/BOX',
          attribute: tenant.code == 'FRESH' ? '유통기한관리' : '로트관리',
          active: true,
          updatedAt: '오늘 10:02',
        ),
        _MasterRecord(
          code: 'SKU-${tenant.code}-204',
          name: tenant.code == 'FRESH' ? '냉장 베이직 키트' : '표준 패킹 키트',
          detail: 'EA',
          attribute: tenant.code == 'GLOBAL' ? '시리얼관리' : '유통기한관리',
          active: true,
          updatedAt: '어제 17:45',
        ),
      ],
      _MasterType.uom: [
        const _MasterRecord(
          code: 'EA',
          name: 'Each',
          detail: '기준 단위',
          attribute: '1',
          active: true,
          updatedAt: '06.16 11:05',
        ),
        const _MasterRecord(
          code: 'BOX',
          name: 'Box',
          detail: '포장 단위',
          attribute: '12 EA',
          active: true,
          updatedAt: '06.16 11:05',
        ),
      ],
      _MasterType.location: [
        _MasterRecord(
          code: '${tenant.code}-A-12-04',
          name: '${tenant.defaultWarehouse} A존 12열 04단',
          detail: '피킹',
          attribute: tenant.code == 'FRESH' ? '76%' : '82%',
          active: true,
          updatedAt: '오늘 09:56',
        ),
        _MasterRecord(
          code: '${tenant.code}-C-03-02',
          name: '$secondaryWarehouse C존 03열 02단',
          detail: '보관',
          attribute: tenant.code == 'GLOBAL' ? '64%' : '71%',
          active: true,
          updatedAt: '오늘 07:44',
        ),
      ],
      _MasterType.carrier: [
        const _MasterRecord(
          code: 'CAR-CJ',
          name: 'CJ 대한통운',
          detail: '택배',
          attribute: 'D+1',
          active: true,
          updatedAt: '오늘 08:12',
        ),
        _MasterRecord(
          code: tenant.code == 'GLOBAL' ? 'CAR-DHL' : 'CAR-HJ',
          name: tenant.code == 'GLOBAL' ? 'DHL Supply Chain' : '한진',
          detail: tenant.code == 'GLOBAL' ? '국제/간선' : '택배',
          attribute: tenant.code == 'GLOBAL' ? 'D+2' : 'D+1',
          active: true,
          updatedAt: '06.17 13:35',
        ),
      ],
      _MasterType.supplier: [
        _MasterRecord(
          code: 'SUP-${tenant.code}',
          name: tenant.code == 'FRESH' ? '로컬 신선물류' : '오리온 공급센터',
          detail: tenant.code == 'GLOBAL' ? '부품 직납' : '정기 매입',
          attribute: 'A등급',
          active: true,
          updatedAt: '오늘 10:18',
        ),
        _MasterRecord(
          code: 'SUP-${tenant.code}-02',
          name: tenant.code == 'GLOBAL' ? 'Factory Service Hub' : '로컬 협력사',
          detail: tenant.code == 'FRESH' ? '냉장 직납' : '보조 공급',
          attribute: 'B등급',
          active: false,
          updatedAt: '06.15 16:40',
        ),
      ],
    };
  }

  Map<_MasterType, List<_MasterRecord>> get _records {
    return _recordsByTenant.putIfAbsent(
      widget.tenant.code,
      () => _seedRecords(widget.tenant),
    );
  }

  _MasterDefinition get _selectedDefinition {
    return _definitions.firstWhere((item) => item.type == _selectedType);
  }

  List<_MasterRecord> get _selectedRecords => _records[_selectedType] ?? [];

  int get _totalRecordCount {
    return _records.values.fold(0, (total, records) => total + records.length);
  }

  int get _activeRecordCount {
    return _records.values.fold(
      0,
      (total, records) =>
          total + records.where((record) => record.active).length,
    );
  }

  void _selectType(_MasterType type) {
    if (_selectedType == type) {
      return;
    }

    setState(() {
      _selectedType = type;
      _clearForm(resetState: false);
    });
  }

  void _editRecord(_MasterRecord record) {
    setState(() {
      _editingCode = record.code;
      _active = record.active;
      _codeController.text = record.code;
      _nameController.text = record.name;
      _detailController.text = record.detail;
      _attributeController.text = record.attribute;
    });
  }

  void _clearForm({bool resetState = true}) {
    _formKey.currentState?.reset();
    _editingCode = null;
    _active = true;
    _codeController.clear();
    _nameController.clear();
    _detailController.clear();
    _attributeController.clear();

    if (resetState) {
      setState(() {});
    }
  }

  void _saveRecord() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final code = _codeController.text.trim().toUpperCase();
    final record = _MasterRecord(
      code: code,
      name: _nameController.text.trim(),
      detail: _detailController.text.trim(),
      attribute: _attributeController.text.trim(),
      active: _active,
      updatedAt: '방금 전',
    );
    final records = List<_MasterRecord>.from(_selectedRecords);
    final editingIndex = records.indexWhere(
      (item) => item.code == _editingCode,
    );
    final duplicateIndex = records.indexWhere((item) => item.code == code);

    if (_editingCode == null && duplicateIndex >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 등록된 코드입니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      if (editingIndex >= 0) {
        records[editingIndex] = record;
      } else {
        records.insert(0, record);
      }
      _records[_selectedType] = records;
      _clearForm(resetState: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDefinition = _selectedDefinition;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        widget.isDesktop ? 22 : 18,
        widget.isDesktop ? 20 : 16,
        widget.isDesktop ? 22 : 18,
        widget.isDesktop ? 34 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardTopBar(
            profile: widget.profile,
            tenant: widget.tenant,
            tenants: widget.tenants,
            warehouse: widget.warehouse,
            isDesktop: widget.isDesktop,
            onTenantChanged: widget.onTenantChanged,
            onWarehouseChanged: widget.onWarehouseChanged,
            onSignOut: widget.onSignOut,
            title: '마스터 관리',
            subtitle: '${widget.tenant.name} 기준정보 · 마스터 등록/수정',
          ),
          const SizedBox(height: 16),
          _MasterSummaryStrip(
            totalCount: _totalRecordCount,
            activeCount: _activeRecordCount,
            inactiveCount: _totalRecordCount - _activeRecordCount,
            typeCount: _definitions.length,
          ),
          const SizedBox(height: 16),
          if (widget.isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 282,
                  child: _MasterCategoryPanel(
                    definitions: _definitions,
                    selectedType: _selectedType,
                    counts: {
                      for (final definition in _definitions)
                        definition.type: _records[definition.type]?.length ?? 0,
                    },
                    onSelected: _selectType,
                    isDesktop: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 7,
                  child: _MasterListPanel(
                    definition: selectedDefinition,
                    records: _selectedRecords,
                    editingCode: _editingCode,
                    onEdit: _editRecord,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: _MasterFormPanel(
                    formKey: _formKey,
                    definition: selectedDefinition,
                    isEditing: _editingCode != null,
                    active: _active,
                    codeController: _codeController,
                    nameController: _nameController,
                    detailController: _detailController,
                    attributeController: _attributeController,
                    onActiveChanged: (value) {
                      setState(() {
                        _active = value;
                      });
                    },
                    onSave: _saveRecord,
                    onClear: _clearForm,
                  ),
                ),
              ],
            )
          else ...[
            _MasterCategoryPanel(
              definitions: _definitions,
              selectedType: _selectedType,
              counts: {
                for (final definition in _definitions)
                  definition.type: _records[definition.type]?.length ?? 0,
              },
              onSelected: _selectType,
              isDesktop: false,
            ),
            const SizedBox(height: 16),
            _MasterListPanel(
              definition: selectedDefinition,
              records: _selectedRecords,
              editingCode: _editingCode,
              onEdit: _editRecord,
            ),
            const SizedBox(height: 16),
            _MasterFormPanel(
              formKey: _formKey,
              definition: selectedDefinition,
              isEditing: _editingCode != null,
              active: _active,
              codeController: _codeController,
              nameController: _nameController,
              detailController: _detailController,
              attributeController: _attributeController,
              onActiveChanged: (value) {
                setState(() {
                  _active = value;
                });
              },
              onSave: _saveRecord,
              onClear: _clearForm,
            ),
          ],
        ],
      ),
    );
  }
}

class _MasterSummaryStrip extends StatelessWidget {
  const _MasterSummaryStrip({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.typeCount,
  });

  final int totalCount;
  final int activeCount;
  final int inactiveCount;
  final int typeCount;

  @override
  Widget build(BuildContext context) {
    final summaries = [
      _MasterSummaryData('전체 마스터', '$totalCount건', Icons.dataset_outlined),
      _MasterSummaryData('활성 데이터', '$activeCount건', Icons.verified_outlined),
      _MasterSummaryData('점검 필요', '$inactiveCount건', Icons.rule_outlined),
      _MasterSummaryData('관리 영역', '$typeCount개', Icons.category_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520
            ? 2
            : constraints.maxWidth >= 900
            ? 4
            : 2;

        return GridView.builder(
          itemCount: summaries.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 88,
          ),
          itemBuilder: (context, index) {
            return _MasterSummaryTile(data: summaries[index]);
          },
        );
      },
    );
  }
}

class _MasterSummaryData {
  const _MasterSummaryData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MasterSummaryTile extends StatelessWidget {
  const _MasterSummaryTile({required this.data});

  final _MasterSummaryData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE3E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: KwmsApp.brandOrange.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(data.icon, color: KwmsApp.brandOrangeDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF68757A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KwmsApp.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterCategoryPanel extends StatelessWidget {
  const _MasterCategoryPanel({
    required this.definitions,
    required this.selectedType,
    required this.counts,
    required this.onSelected,
    required this.isDesktop,
  });

  final List<_MasterDefinition> definitions;
  final _MasterType selectedType;
  final Map<_MasterType, int> counts;
  final ValueChanged<_MasterType> onSelected;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: '마스터 그룹',
      icon: Icons.account_tree_outlined,
      child: isDesktop
          ? Column(
              children: [
                for (var index = 0; index < definitions.length; index++) ...[
                  _MasterCategoryButton(
                    definition: definitions[index],
                    count: counts[definitions[index].type] ?? 0,
                    selected: definitions[index].type == selectedType,
                    onTap: () => onSelected(definitions[index].type),
                  ),
                  if (index < definitions.length - 1) const SizedBox(height: 8),
                ],
              ],
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final definition in definitions)
                  _MasterCategoryChip(
                    definition: definition,
                    count: counts[definition.type] ?? 0,
                    selected: definition.type == selectedType,
                    onTap: () => onSelected(definition.type),
                  ),
              ],
            ),
    );
  }
}

class _MasterCategoryButton extends StatelessWidget {
  const _MasterCategoryButton({
    required this.definition,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _MasterDefinition definition;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : KwmsApp.ink,
          backgroundColor: selected
              ? KwmsApp.brandOrange
              : const Color(0xFFF7FAFB),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            Icon(
              definition.icon,
              color: selected ? Colors.white : KwmsApp.brandOrangeDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    definition.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: .8)
                          : const Color(0xFF758187),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _MasterCategoryChip extends StatelessWidget {
  const _MasterCategoryChip({
    required this.definition,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _MasterDefinition definition;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(definition.icon, size: 18),
      label: Text('${definition.label} $count'),
      selectedColor: KwmsApp.brandOrange,
      backgroundColor: const Color(0xFFF7FAFB),
      labelStyle: TextStyle(
        color: selected ? Colors.white : KwmsApp.ink,
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _MasterListPanel extends StatelessWidget {
  const _MasterListPanel({
    required this.definition,
    required this.records,
    required this.editingCode,
    required this.onEdit,
  });

  final _MasterDefinition definition;
  final List<_MasterRecord> records;
  final String? editingCode;
  final ValueChanged<_MasterRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: '${definition.label} 리스트',
      icon: definition.icon,
      trailing: StatusPill(
        icon: Icons.list_alt_outlined,
        label: '${records.length}건',
        color: KwmsApp.brandOrangeDark,
      ),
      child: Column(
        children: [
          _MasterListHeader(definition: definition),
          const Divider(height: 22, color: Color(0xFFE8EEF0)),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                '등록된 마스터가 없습니다.',
                style: TextStyle(
                  color: Color(0xFF748086),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            for (var index = 0; index < records.length; index++) ...[
              _MasterRecordRow(
                record: records[index],
                selected: records[index].code == editingCode,
                onTap: () => onEdit(records[index]),
              ),
              if (index < records.length - 1)
                const Divider(height: 18, color: Color(0xFFF0F3F4)),
            ],
        ],
      ),
    );
  }
}

class _MasterListHeader extends StatelessWidget {
  const _MasterListHeader({required this.definition});

  final _MasterDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 94, child: _TableHeaderText('코드')),
        const SizedBox(width: 14),
        const Expanded(flex: 3, child: _TableHeaderText('명칭')),
        Expanded(flex: 2, child: _TableHeaderText(definition.detailLabel)),
        Expanded(flex: 2, child: _TableHeaderText(definition.attributeLabel)),
        const SizedBox(width: 72, child: _TableHeaderText('상태')),
      ],
    );
  }
}

class _MasterRecordRow extends StatelessWidget {
  const _MasterRecordRow({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final _MasterRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF1E8) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 94,
                child: Text(
                  record.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KwmsApp.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: _MasterCellText(record.name, strong: true),
              ),
              Expanded(flex: 2, child: _MasterCellText(record.detail)),
              Expanded(flex: 2, child: _MasterCellText(record.attribute)),
              SizedBox(
                width: 72,
                child: _MiniStatusBadge(
                  label: record.active ? '사용' : '중지',
                  color: record.active
                      ? const Color(0xFF2F8F6B)
                      : const Color(0xFFC45A45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasterCellText extends StatelessWidget {
  const _MasterCellText(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: strong ? KwmsApp.ink : const Color(0xFF59666C),
        fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
      ),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  const _MiniStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MasterFormPanel extends StatelessWidget {
  const _MasterFormPanel({
    required this.formKey,
    required this.definition,
    required this.isEditing,
    required this.active,
    required this.codeController,
    required this.nameController,
    required this.detailController,
    required this.attributeController,
    required this.onActiveChanged,
    required this.onSave,
    required this.onClear,
  });

  final GlobalKey<FormState> formKey;
  final _MasterDefinition definition;
  final bool isEditing;
  final bool active;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController detailController;
  final TextEditingController attributeController;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: isEditing ? '${definition.label} 수정' : '${definition.label} 신규 등록',
      icon: isEditing ? Icons.edit_note_outlined : Icons.add_box_outlined,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: codeController,
              readOnly: isEditing,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: '${definition.label} 코드',
                prefixIcon: const Icon(Icons.tag_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '코드를 입력하세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: '${definition.label} 명칭',
                prefixIcon: Icon(definition.icon),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '명칭을 입력하세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: detailController,
              decoration: InputDecoration(
                labelText: definition.detailLabel,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: attributeController,
              decoration: InputDecoration(
                labelText: definition.attributeLabel,
                prefixIcon: const Icon(Icons.tune_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                value: active,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                activeThumbColor: KwmsApp.brandOrange,
                title: const Text(
                  '사용 여부',
                  style: TextStyle(
                    color: KwmsApp.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: const Text('비활성화된 마스터는 신규 작업 배정에서 제외됩니다.'),
                onChanged: onActiveChanged,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onSave,
              icon: Icon(isEditing ? Icons.save_outlined : Icons.add_rounded),
              label: Text(isEditing ? '수정 저장' : '마스터 등록'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('입력 초기화'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KwmsApp.ink,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: Color(0xFFD8C9BF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.profile,
    required this.tenant,
    required this.tenants,
    required this.warehouse,
    required this.isDesktop,
    required this.onTenantChanged,
    required this.onWarehouseChanged,
    required this.onSignOut,
    this.title = '운영 대시보드',
    this.subtitle = '입고 · 재고 · 피킹 · 출하 통합 관제',
  });

  final DashboardUserProfile profile;
  final _TenantContext tenant;
  final List<_TenantContext> tenants;
  final String warehouse;
  final bool isDesktop;
  final ValueChanged<_TenantContext> onTenantChanged;
  final ValueChanged<String> onWarehouseChanged;
  final Future<void> Function() onSignOut;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) ...[const _BrandLockup(), const SizedBox(height: 18)],
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: KwmsApp.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$subtitle · Tenant ${tenant.code}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF647176),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final controlItems = [
      _TenantSelector(
        tenant: tenant,
        tenants: tenants,
        onChanged: onTenantChanged,
      ),
      _WarehouseSelector(
        value: warehouse,
        warehouses: tenant.warehouses,
        onChanged: onWarehouseChanged,
      ),
      StatusPill(
        icon: Icons.verified_user_outlined,
        label: '${tenant.code} 스코프',
        color: tenant.badgeColor,
      ),
      StatusPill(
        icon: Icons.circle,
        label: profile.emailVerified ? '인증 완료' : '이메일 확인 대기',
        color: profile.emailVerified
            ? const Color(0xFF2F8F6B)
            : const Color(0xFFB9802E),
      ),
      if (isDesktop)
        _ProfileMenu(profile: profile, onSignOut: onSignOut)
      else
        IconButton.filledTonal(
          tooltip: '로그아웃',
          onPressed: () async {
            await onSignOut();
          },
          icon: const Icon(Icons.logout_rounded),
        ),
    ];

    final wrappedControls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: isDesktop ? WrapAlignment.end : WrapAlignment.start,
      children: controlItems,
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [titleBlock, const SizedBox(height: 14), wrappedControls],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1040) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleBlock, const SizedBox(height: 12), wrappedControls],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < controlItems.length; index++) ...[
                  controlItems[index],
                  if (index < controlItems.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TenantSelector extends StatelessWidget {
  const _TenantSelector({
    required this.tenant,
    required this.tenants,
    required this.onChanged,
  });

  final _TenantContext tenant;
  final List<_TenantContext> tenants;
  final ValueChanged<_TenantContext> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE3E5)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: tenant.code,
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            items: [
              for (final item in tenants)
                DropdownMenuItem(
                  value: item.code,
                  child: Row(
                    children: [
                      Icon(
                        Icons.domain_verification_outlined,
                        color: item.badgeColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.name} · ${item.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (selected) {
              if (selected == null || selected == tenant.code) {
                return;
              }

              final nextTenant = tenants.firstWhere(
                (item) => item.code == selected,
                orElse: () => tenant,
              );
              onChanged(nextTenant);
            },
          ),
        ),
      ),
    );
  }
}

class _WarehouseSelector extends StatelessWidget {
  const _WarehouseSelector({
    required this.value,
    required this.warehouses,
    required this.onChanged,
  });

  final String value;
  final List<String> warehouses;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue = warehouses.contains(value)
        ? value
        : warehouses.first;

    return SizedBox(
      width: 166,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE3E5)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedValue,
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            items: [
              for (final warehouse in warehouses)
                DropdownMenuItem(
                  value: warehouse,
                  child: Text(
                    warehouse,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (selected) {
              if (selected != null) {
                onChanged(selected);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.profile, required this.onSignOut});

  final DashboardUserProfile profile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE3E5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UserAvatar(profile: profile, radius: 15),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KwmsApp.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '로그아웃',
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await onSignOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.profile, required this.radius});

  final DashboardUserProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFE3D1),
      backgroundImage: profile.photoUrl == null
          ? null
          : NetworkImage(profile.photoUrl!),
      child: profile.photoUrl == null
          ? Icon(
              Icons.person_rounded,
              color: KwmsApp.brandOrangeDark,
              size: radius + 5,
            )
          : null,
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: icon == Icons.circle ? 9 : 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionBar extends StatelessWidget {
  const _QuickActionBar({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    const actions = [
      _QuickAction(
        icon: Icons.add_box_outlined,
        label: '입고 등록',
        color: KwmsApp.brandOrange,
      ),
      _QuickAction(
        icon: Icons.swap_horiz_rounded,
        label: '재고 이동',
        color: Color(0xFF48646B),
      ),
      _QuickAction(
        icon: Icons.assignment_turned_in_outlined,
        label: '피킹 배정',
        color: Color(0xFF2F8F6B),
      ),
      _QuickAction(
        icon: Icons.fact_check_outlined,
        label: '출하 확정',
        color: Color(0xFF7B6EB2),
      ),
    ];

    final children = [
      for (final action in actions)
        _QuickActionButton(action: action, expanded: isDesktop),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            Expanded(child: children[index]),
            if (index < children.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 330 ? 1 : 2;

        return GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 48,
          ),
          itemBuilder: (context, index) {
            return _QuickActionButton(action: actions[index], expanded: true);
          },
        );
      },
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action, required this.expanded});

  final _QuickAction action;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(action.icon, color: action.color),
        label: Text(action.label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          alignment: expanded ? Alignment.center : Alignment.centerLeft,
          foregroundColor: KwmsApp.ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDDE3E5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid();

  static const _items = [
    _KpiData(
      title: '출하 진행률',
      value: '87.4%',
      detail: 'SLA +4.2%',
      icon: Icons.local_shipping_outlined,
      accent: KwmsApp.brandOrange,
      statusColor: Color(0xFF2F8F6B),
    ),
    _KpiData(
      title: '입고 대기',
      value: '42건',
      detail: '도크 6개 배정',
      icon: Icons.move_to_inbox_outlined,
      accent: Color(0xFF48646B),
      statusColor: Color(0xFF48646B),
    ),
    _KpiData(
      title: '재고 정확도',
      value: '99.2%',
      detail: '전일 대비 +0.3%',
      icon: Icons.verified_outlined,
      accent: Color(0xFF2F8F6B),
      statusColor: Color(0xFF2F8F6B),
    ),
    _KpiData(
      title: '긴급 이슈',
      value: '7건',
      detail: '지연 위험 3건',
      icon: Icons.report_problem_outlined,
      accent: Color(0xFFC45A45),
      statusColor: Color(0xFFC45A45),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 430
            ? 1
            : constraints.maxWidth >= 900
            ? 4
            : 2;

        return GridView.builder(
          itemCount: _items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 168,
          ),
          itemBuilder: (context, index) {
            return _KpiTile(data: _items[index]);
          },
        );
      },
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
    required this.statusColor,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;
  final Color statusColor;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE3E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C111111),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: data.accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(data.icon, color: data.accent, size: 22),
                  ),
                ),
                const Spacer(),
                Icon(Icons.trending_up_rounded, color: data.statusColor),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                style: const TextStyle(
                  color: KwmsApp.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5F6A70),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              data.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8A959A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE3E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: KwmsApp.brandOrangeDark, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: KwmsApp.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PipelinePanel extends StatelessWidget {
  const _PipelinePanel();

  static const _steps = [
    _PipelineData('입고예정', '128', .74, Color(0xFF48646B)),
    _PipelineData('검수', '37', .42, Color(0xFFB9802E)),
    _PipelineData('적치', '92', .68, Color(0xFF2F8F6B)),
    _PipelineData('피킹', '316', .81, KwmsApp.brandOrange),
    _PipelineData('패킹', '84', .56, Color(0xFF7B6EB2)),
    _PipelineData('상차', '74', .63, Color(0xFF477DA8)),
  ];

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: '작업 파이프라인',
      icon: Icons.account_tree_outlined,
      trailing: const StatusPill(
        icon: Icons.bolt_rounded,
        label: '실시간',
        color: Color(0xFF2F8F6B),
      ),
      child: Column(
        children: [
          for (var index = 0; index < _steps.length; index++) ...[
            _PipelineStep(data: _steps[index]),
            if (index < _steps.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0xFFE8EEF0)),
              ),
          ],
        ],
      ),
    );
  }
}

class _PipelineData {
  const _PipelineData(this.label, this.value, this.progress, this.color);

  final String label;
  final String value;
  final double progress;
  final Color color;
}

class _PipelineStep extends StatelessWidget {
  const _PipelineStep({required this.data});

  final _PipelineData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            data.label,
            style: const TextStyle(
              color: Color(0xFF59666C),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: data.progress,
              color: data.color,
              backgroundColor: const Color(0xFFE9EEF0),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 54,
          child: Text(
            data.value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: KwmsApp.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExceptionPanel extends StatelessWidget {
  const _ExceptionPanel();

  static const _items = [
    _ExceptionData(
      label: '로케이션 재고 차이',
      detail: 'A-12-04 · SKU 3종 재검 필요',
      severity: '높음',
      color: Color(0xFFC45A45),
      icon: Icons.crisis_alert_outlined,
    ),
    _ExceptionData(
      label: '출하 SLA 위험',
      detail: '19:00 출고 차수 · 27건 대기',
      severity: '주의',
      color: Color(0xFFB9802E),
      icon: Icons.schedule_outlined,
    ),
    _ExceptionData(
      label: '냉장존 온도 편차',
      detail: 'COLD-B · 기준 +0.8도',
      severity: '관찰',
      color: Color(0xFF477DA8),
      icon: Icons.device_thermostat_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: '예외 처리 큐',
      icon: Icons.rule_folder_outlined,
      trailing: TextButton(onPressed: () {}, child: const Text('전체 보기')),
      child: Column(
        children: [
          for (var index = 0; index < _items.length; index++) ...[
            _ExceptionRow(data: _items[index]),
            if (index < _items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFE8EEF0)),
              ),
          ],
        ],
      ),
    );
  }
}

class _ExceptionData {
  const _ExceptionData({
    required this.label,
    required this.detail,
    required this.severity,
    required this.color,
    required this.icon,
  });

  final String label;
  final String detail;
  final String severity;
  final Color color;
  final IconData icon;
}

class _ExceptionRow extends StatelessWidget {
  const _ExceptionRow({required this.data});

  final _ExceptionData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: KwmsApp.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF748086),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        StatusPill(icon: Icons.circle, label: data.severity, color: data.color),
      ],
    );
  }
}

class _StorageUtilizationPanel extends StatelessWidget {
  const _StorageUtilizationPanel();

  static const _zones = [
    _ZoneData('A', '상온', 82, KwmsApp.brandOrange),
    _ZoneData('B', '상온', 64, Color(0xFF2F8F6B)),
    _ZoneData('C', '냉장', 71, Color(0xFF477DA8)),
    _ZoneData('D', '냉동', 58, Color(0xFF7B6EB2)),
    _ZoneData('E', '반품', 39, Color(0xFFB9802E)),
    _ZoneData('F', '보류', 26, Color(0xFFC45A45)),
  ];

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: '창고 존 사용률',
      icon: Icons.warehouse_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 420 ? 2 : 3;

          return GridView.builder(
            itemCount: _zones.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 92,
            ),
            itemBuilder: (context, index) {
              return _ZoneTile(data: _zones[index]);
            },
          );
        },
      ),
    );
  }
}

class _ZoneData {
  const _ZoneData(this.zone, this.type, this.percent, this.color);

  final String zone;
  final String type;
  final int percent;
  final Color color;
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.data});

  final _ZoneData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: data.color.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${data.zone}존',
                  style: TextStyle(
                    color: data.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  data.type,
                  style: const TextStyle(
                    color: Color(0xFF68757A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: data.percent / 100,
                color: data.color,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${data.percent}% 사용',
              style: const TextStyle(
                color: KwmsApp.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockSchedulePanel extends StatelessWidget {
  const _DockSchedulePanel();

  static const _rows = [
    _DockRowData('D-01', 'CJ 대한통운', '09:40', '상차중', Color(0xFF2F8F6B)),
    _DockRowData('D-04', '한진', '10:10', '대기', Color(0xFFB9802E)),
    _DockRowData('D-06', '롯데글로벌', '10:30', '검수', Color(0xFF477DA8)),
    _DockRowData('D-08', '쿠팡', '11:00', '예약', Color(0xFF7B6EB2)),
  ];

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: '도크 스케줄',
      icon: Icons.view_timeline_outlined,
      child: Column(
        children: [
          const _DockHeaderRow(),
          const Divider(height: 24, color: Color(0xFFE8EEF0)),
          for (var index = 0; index < _rows.length; index++) ...[
            _DockDataRow(data: _rows[index]),
            if (index < _rows.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _DockRowData {
  const _DockRowData(
    this.dock,
    this.carrier,
    this.time,
    this.status,
    this.color,
  );

  final String dock;
  final String carrier;
  final String time;
  final String status;
  final Color color;
}

class _DockHeaderRow extends StatelessWidget {
  const _DockHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 58, child: _TableHeaderText('도크')),
        Expanded(child: _TableHeaderText('운송사')),
        SizedBox(width: 56, child: _TableHeaderText('시간')),
        SizedBox(width: 94, child: _TableHeaderText('상태')),
      ],
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  const _TableHeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF8B979C),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _DockDataRow extends StatelessWidget {
  const _DockDataRow({required this.data});

  final _DockRowData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            data.dock,
            style: const TextStyle(
              color: KwmsApp.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            data.carrier,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF59666C),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            data.time,
            style: const TextStyle(
              color: KwmsApp.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          width: 94,
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              icon: Icons.circle,
              label: data.status,
              color: data.color,
            ),
          ),
        ),
      ],
    );
  }
}

class _FirebaseSetupNotice extends StatelessWidget {
  const _FirebaseSetupNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7C7B1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.cloud_sync_outlined,
              color: KwmsApp.brandOrangeDark,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF684B3A),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityStrip extends StatelessWidget {
  const _SecurityStrip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3D6CC)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              color: KwmsApp.brandOrangeDark,
              size: 21,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '테넌트 보안 세션',
                style: TextStyle(
                  color: Color(0xFF5E4D43),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.lock_clock_outlined, color: Color(0xFF7E6E65), size: 20),
          ],
        ),
      ),
    );
  }
}
