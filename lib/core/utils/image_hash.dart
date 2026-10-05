import 'dart:io';

import 'package:crypto/crypto.dart';

/// 사진 파일의 지문(SHA-256 hex 64자).
///
/// 조과 중복 등록 차단에 사용한다. **압축 전 원본 바이트** 기준인데,
/// 압축 결과는 기기·라이브러리 버전에 따라 달라져 같은 사진인데 해시가
/// 어긋나는 오탐이 생기기 때문이다.
///
/// 파일을 스트림 청크로 읽어 메모리에 전체를 올리지 않는다.
Future<String> computeImageHash(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
