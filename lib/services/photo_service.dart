import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/photo_attachment.dart';

/// UC-11: lets the person pick a picture and uploads it to Cloudinary (free
/// plan, unsigned preset). When Cloudinary is not configured it returns a
/// demo attachment (name and size only) so the flow still works.
class PhotoService {
  const PhotoService({
    this.cloud = AppConfig.cloudinaryCloud,
    this.preset = AppConfig.cloudinaryPreset,
  });

  final String cloud;
  final String preset;

  bool get enabled => cloud.isNotEmpty && preset.isNotEmpty;

  /// Opens the picker. Returns null when the person cancels.
  Future<PhotoAttachment?> pick(int numberAlreadyAdded) async {
    if (!enabled) {
      return PhotoAttachment(
        name: 'photo_${numberAlreadyAdded + 1}.jpg',
        sizeBytes: 1200000,
      );
    }
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    final int size = await file.length();
    if (size > AppConstants.maxPhotoBytes) {
      throw const AppException('Each photo must be 5 MB or smaller.');
    }
    final String name = file.name.isEmpty ? 'photo.jpg' : file.name;
    final String url = await upload(await file.readAsBytes(), name);
    return PhotoAttachment(name: name, sizeBytes: size, url: url);
  }

  /// Uploads bytes and returns the public https address.
  Future<String> upload(List<int> bytes, String name) async {
    final Uri uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    try {
      final http.StreamedResponse streamed =
          await request.send().timeout(const Duration(seconds: 40));
      final String body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw const AppException(
          'Photo upload failed. Check the Cloudinary cloud name and preset.',
        );
      }
      final Object? json = jsonDecode(body);
      final Object? url = json is Map<String, dynamic> ? json['secure_url'] : null;
      if (url is! String) {
        throw const AppException('Photo upload failed. Try again.');
      }
      return url;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'Cannot upload the photo. Check your internet connection.',
      );
    }
  }
}
