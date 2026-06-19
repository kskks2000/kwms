import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('renders KWMS login screen', (tester) async {
    await tester.pumpWidget(const KwmsApp());

    expect(find.text('KWMS'), findsWidgets);
    expect(find.text('창고관리 시스템'), findsOneWidget);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('작업 창고'), findsOneWidget);
    expect(find.text('Google로 로그인'), findsOneWidget);
    expect(find.byIcon(Icons.warehouse_outlined), findsOneWidget);
  });

  testWidgets('validates required login fields', (tester) async {
    await tester.pumpWidget(const KwmsApp());

    final loginButton = find.widgetWithText(FilledButton, '이메일 로그인');
    await tester.ensureVisible(loginButton);
    await tester.pumpAndSettle();
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('이메일을 입력하세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력하세요.'), findsOneWidget);
  });

  testWidgets('switches to sign up form and validates fields', (tester) async {
    await tester.pumpWidget(const KwmsApp());

    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    expect(find.text('이름'), findsOneWidget);
    expect(find.text('비밀번호 확인'), findsOneWidget);
    expect(find.text('이메일로 가입'), findsOneWidget);
    expect(find.text('Google로 가입/로그인'), findsOneWidget);
    expect(find.text('작업 창고'), findsNothing);

    final signUpButton = find.widgetWithText(FilledButton, '이메일로 가입');
    await tester.ensureVisible(signUpButton);
    await tester.pumpAndSettle();
    await tester.tap(signUpButton);
    await tester.pump();

    expect(find.text('이름을 입력하세요.'), findsOneWidget);
    expect(find.text('이메일을 입력하세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력하세요.'), findsOneWidget);
    expect(find.text('비밀번호를 한 번 더 입력하세요.'), findsOneWidget);
  });

  testWidgets('renders enterprise WMS dashboard on desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: WmsDashboardScreen(
          profile: const DashboardUserProfile(
            name: '홍길동',
            email: 'hong@example.com',
            emailVerified: true,
          ),
          onSignOut: () async {},
        ),
      ),
    );

    expect(find.text('운영 대시보드'), findsOneWidget);
    expect(find.text('메타서울 운영 · META'), findsOneWidget);
    expect(find.text('META 스코프'), findsOneWidget);
    expect(find.text('대시보드'), findsOneWidget);
    expect(find.text('출하 진행률'), findsOneWidget);
    expect(find.text('작업 파이프라인'), findsOneWidget);
    expect(find.text('예외 처리 큐'), findsOneWidget);
    expect(find.text('창고 존 사용률'), findsOneWidget);
    expect(find.text('도크 스케줄'), findsOneWidget);
  });

  testWidgets('renders mobile WMS dashboard navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: WmsDashboardScreen(
          profile: const DashboardUserProfile(
            name: '모바일 사용자',
            email: 'mobile@example.com',
            emailVerified: false,
          ),
          onSignOut: () async {},
        ),
      ),
    );

    expect(find.text('운영 대시보드'), findsOneWidget);
    expect(find.text('메타서울 운영 · META'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('마스터'), findsOneWidget);
    expect(find.text('입고'), findsOneWidget);
    expect(find.text('재고'), findsOneWidget);
    expect(find.text('출하'), findsOneWidget);
    expect(find.text('이메일 확인 대기'), findsOneWidget);
  });

  testWidgets('opens master management and registers a warehouse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: WmsDashboardScreen(
          profile: const DashboardUserProfile(
            name: '마스터 관리자',
            email: 'master@example.com',
            emailVerified: true,
          ),
          onSignOut: () async {},
        ),
      ),
    );

    await tester.tap(find.text('마스터 관리'));
    await tester.pumpAndSettle();

    expect(find.text('마스터 관리'), findsWidgets);
    expect(find.text('마스터 그룹'), findsOneWidget);
    expect(find.text('창고 리스트'), findsOneWidget);
    expect(find.text('창고 신규 등록'), findsOneWidget);
    expect(find.text('화주'), findsOneWidget);
    expect(find.text('제품'), findsOneWidget);
    expect(find.text('UOM'), findsOneWidget);
    expect(find.text('로케이션'), findsOneWidget);
    expect(find.text('운송사'), findsOneWidget);
    expect(find.text('공급사'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'WH-TEST');
    await tester.enterText(find.byType(TextFormField).at(1), '테스트 물류센터');
    await tester.enterText(find.byType(TextFormField).at(2), '상온');
    await tester.enterText(find.byType(TextFormField).at(3), '5,000 m²');
    await tester.tap(find.widgetWithText(FilledButton, '마스터 등록'));
    await tester.pumpAndSettle();

    expect(find.text('WH-TEST'), findsOneWidget);
    expect(find.text('테스트 물류센터'), findsOneWidget);
  });

  testWidgets('switches tenant and scopes master records', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: WmsDashboardScreen(
          profile: const DashboardUserProfile(
            name: '테넌트 관리자',
            email: 'tenant@example.com',
            emailVerified: true,
          ),
          onSignOut: () async {},
        ),
      ),
    );

    await tester.tap(find.text('마스터 관리'));
    await tester.pumpAndSettle();

    expect(find.text('WH-META'), findsOneWidget);
    expect(find.text('프레시 동탄센터'), findsNothing);

    await tester.tap(find.text('메타서울 운영 · META'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('프레시 프라임 · FRESH').last);
    await tester.pumpAndSettle();

    expect(find.text('FRESH 스코프'), findsOneWidget);
    expect(find.text('프레시 동탄센터'), findsWidgets);
    expect(find.text('WH-FRESH'), findsOneWidget);
    expect(find.text('WH-META'), findsNothing);
  });
}
