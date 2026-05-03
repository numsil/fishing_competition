import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

Future<void> downloadImageToGallery(String imageUrl) async {
  final hasAccess = await Gal.hasAccess(toAlbum: false);
  if (!hasAccess) {
    final granted = await Gal.requestAccess(toAlbum: false);
    if (!granted) throw Exception('갤러리 접근 권한이 필요합니다');
  }

  final tempFile = File(
    '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  try {
    await Dio().download(imageUrl, tempFile.path);
    await Gal.putImage(tempFile.path);
  } finally {
    if (await tempFile.exists()) await tempFile.delete();
  }
}
