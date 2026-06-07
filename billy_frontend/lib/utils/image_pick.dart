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
  final bytes = await file.readAsBytes();
  final media = file.name.toLowerCase().endsWith('.png') ? 'image/png' : (file.mimeType ?? 'image/jpeg');
  return (data: base64Encode(bytes), media: media);
}
