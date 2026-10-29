import 'package:image_picker/image_picker.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/document_ref.dart';
import '../models/photo_attachment.dart';
import '../repositories/api/api_client.dart';

/// Picks pictures and uploads them to the backend (stored in MongoDB).
///
/// Used for problem photos (UC-11) and mechanic documents (UC-23). Without a
/// backend (mock mode, [api] is null) it only makes demo entries.
class PhotoService {
  const PhotoService({this.api});

  final ApiClient? api;

  bool get enabled => api != null;

  /// Opens the picker. Returns null when the person cancels.
  Future<({String name, int size, List<int> bytes})?> _chooseImage() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 85,
    );
    if (file == null) return null;
    final int size = await file.length();
    if (size > AppConstants.maxPhotoBytes) {
      throw const AppException('Each file must be 5 MB or smaller.');
    }
    final String name = file.name.isEmpty ? 'picture.jpg' : file.name;
    return (name: name, size: size, bytes: await file.readAsBytes());
  }

  /// UC-11: one problem photo.
  Future<PhotoAttachment?> pick(int numberAlreadyAdded) async {
    final ApiClient? client = api;
    if (client == null) {
      return PhotoAttachment(
        name: 'photo_${numberAlreadyAdded + 1}.jpg',
        sizeBytes: 1200000,
      );
    }
    final ({String name, int size, List<int> bytes})? image = await _chooseImage();
    if (image == null) return null;
    final String id = await client.uploadFile(image.bytes, image.name, kind: 'photo');
    return PhotoAttachment(
      name: image.name,
      sizeBytes: image.size,
      url: client.fileUrl(id),
    );
  }

  /// UC-23: one verification document (only the owner and admins can open
  /// it). Returns the text to keep in the application (see [DocumentRef]),
  /// or null when the person cancels.
  Future<String?> pickDocument(String label) async {
    final ApiClient? client = api;
    if (client == null) return DocumentRef(label, null).encode();
    final ({String name, int size, List<int> bytes})? image = await _chooseImage();
    if (image == null) return null;
    final String id =
        await client.uploadFile(image.bytes, image.name, kind: 'document');
    return DocumentRef(label, id).encode();
  }

  /// Address to show a stored document (with the login token).
  String? documentUrl(String fileId) => api?.fileUrl(fileId, withToken: true);
}
