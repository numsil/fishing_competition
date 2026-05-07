import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'app_update_service.g.dart';

class AppVersionInfo {
  final String version;
  final int buildNumber;
  final int currentBuildNumber;
  final String? apkUrl;
  final String? iosUrl;
  final String? releaseNotes;
  final bool forceUpdate;

  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.currentBuildNumber,
    this.apkUrl,
    this.iosUrl,
    this.releaseNotes,
    this.forceUpdate = false,
  });
}

class AppUpdateService {
  final SupabaseClient _supabase;
  AppUpdateService(this._supabase);

  // .env의 APP_ENV 값에 따라 체크할 환경 결정
  // develop → development, staging → staging, main → production
  String get _env => dotenv.env['APP_ENV'] ?? 'production';

  Future<AppVersionInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final row = await _supabase
          .from('app_versions')
          .select(
            'version, build_number, apk_url, ios_url, release_notes, force_update',
          )
          .eq('env', _env)
          .maybeSingle();

      if (row == null) return null;

      final remoteBuild = (row['build_number'] as num?)?.toInt() ?? 0;
      if (remoteBuild <= currentBuild) return null;

      return AppVersionInfo(
        version: row['version'] as String? ?? '',
        buildNumber: remoteBuild,
        currentBuildNumber: currentBuild,
        apkUrl: row['apk_url'] as String?,
        iosUrl: row['ios_url'] as String?,
        releaseNotes: row['release_notes'] as String?,
        forceUpdate: row['force_update'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadAndInstall(
    String apkUrl, {
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      var status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        // 해당 앱의 "출처를 알 수 없는 앱" 설정 페이지로 직접 이동
        final info = await PackageInfo.fromPlatform();
        final intent = AndroidIntent(
          action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
          data: 'package:${info.packageName}',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        throw Exception('install_permission_denied');
      }
    }

    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/nakstar_update.apk';

    await Dio().download(
      apkUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    final result = await OpenFile.open(savePath);
    if (result.type != ResultType.done) {
      throw Exception('설치 실패: ${result.message}');
    }
  }
}

@riverpod
AppUpdateService appUpdateService(Ref ref) {
  return AppUpdateService(Supabase.instance.client);
}
