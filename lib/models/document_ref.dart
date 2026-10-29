/// A verification document in `MechanicApplication.documents`.
///
/// An uploaded one is stored as `Label::fileId` (for example
/// `CNIC front::665f...`). A plain `Label` is a document without a file
/// (demo mode or old data).
class DocumentRef {
  const DocumentRef(this.label, this.fileId);

  factory DocumentRef.parse(String value) {
    final int at = value.indexOf(separator);
    if (at < 0) return DocumentRef(value, null);
    final String id = value.substring(at + separator.length);
    return DocumentRef(value.substring(0, at), id.isEmpty ? null : id);
  }

  static const String separator = '::';

  final String label;
  final String? fileId;

  bool get hasFile => fileId != null;

  String encode() => fileId == null ? label : '$label$separator$fileId';
}
