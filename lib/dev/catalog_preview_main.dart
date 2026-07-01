// 개발용 미리보기 진입점 — 위젯 카탈로그만 단독 렌더링.
// 공통 위젯 디자인을 빠르게 보고 고칠 때 사용:
//   flutter run -d chrome -t lib/dev/catalog_preview_main.dart
// (앱 전체·로그인·라우터 없이 카탈로그만 떠서 핫리로드 반복이 빠름)
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'widget_catalog_screen.dart';

void main() => runApp(const _CatalogPreviewApp());

class _CatalogPreviewApp extends StatelessWidget {
  const _CatalogPreviewApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const WidgetCatalogScreen(),
      );
}
