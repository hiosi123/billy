import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 카메라/갤러리에서 이미지를 골라 base64 + mediaType 으로 반환. 취소 시 null.
/// 모바일은 촬영/갤러리 선택지를 보여주고, 웹은 파일 선택.
Future<({String data, String media})?> pickImageBase64(BuildContext context, {double maxWidth = 1600}) async {
  ImageSource source = ImageSource.gallery;
  if (!kIsWeb) {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return null;
    source = picked;
  }

  final file = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: maxWidth);
  if (file == null) return null;
  return _encode(file);
}

/// 갤러리에서 여러 장을 한 번에 골라 base64 리스트로 반환(취소 시 빈 리스트).
/// 고지서 여러 장(수도+전기)을 한 번에 올릴 때 사용.
Future<List<({String data, String media})>> pickImagesBase64({double maxWidth = 2400}) async {
  final files = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: maxWidth);
  final out = <({String data, String media})>[];
  for (final f in files) {
    out.add(await _encode(f));
  }
  return out;
}

Future<({String data, String media})> _encode(XFile file) async {
  final bytes = await file.readAsBytes();
  final media = file.name.toLowerCase().endsWith('.png') ? 'image/png' : (file.mimeType ?? 'image/jpeg');
  return (data: base64Encode(bytes), media: media);
}
