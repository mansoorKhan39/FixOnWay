/// A problem photo (UC-11).
///
/// [url] is set when the picture was really uploaded (see PhotoService);
/// without an upload service only the name and size are kept (demo mode).
class PhotoAttachment {
  const PhotoAttachment({
    required this.name,
    required this.sizeBytes,
    this.url,
  });

  final String name;
  final int sizeBytes;
  final String? url;
}
