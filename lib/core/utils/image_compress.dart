import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 업로드 전 이미지를 JPEG로 변환·압축해 3MB 이하를 보장합니다.
/// minWidth/minHeight는 출력 최대 해상도입니다 (1440이면 긴 변이 1440 이하).
/// picker가 원본을 그대로 넘기므로 여기서 1패스만 인코딩합니다(이중 인코딩 방지).
Future<File> compressForUpload(File file,
    {int maxSizeBytes = 3 * 1024 * 1024, int maxDimension = 1440}) async {
  // 긴 변 maxDimension 이하 + JPEG 품질 85로 1패스 압축 (HEIC→JPEG, keepExif로 회전 유지).
  // 1440/q85는 보통 1MB 미만이라 대부분 첫 시도에서 통과.
  for (final quality in [85, 75, 65]) {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      keepExif: true,
    );
    if (result == null) break;
    if (result.length <= maxSizeBytes) return _toFile(file, result);
  }

  // 그래도 3MB를 넘으면 해상도를 더 줄임
  final fallbackDim = (maxDimension * 0.85).round();
  final result = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: fallbackDim,
    minHeight: fallbackDim,
    quality: 60,
    keepExif: true,
  );
  return result != null ? _toFile(file, result) : file;
}

/// 이미지 파일의 가로:세로 비율을 반환합니다 (0.8 ~ 1.91 사이로 클램프).
/// 인스타그램과 동일한 최솟값(4:5) / 최댓값(1.91:1) 적용.
Future<double> getAspectRatioForUpload(File file) async {
  final bytes = await file.readAsBytes();
  final info = await decodeImageFromList(bytes);
  final ratio = info.width / info.height;
  return ratio.clamp(0.8, 1.91);
}

Future<File> _toFile(File original, Uint8List bytes) async {
  final path = '${original.parent.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
  return File(path).writeAsBytes(bytes);
}
