import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptAttachmentResult {
  final String downloadUrl;
  final String storagePath;

  const ReceiptAttachmentResult({
    required this.downloadUrl,
    required this.storagePath,
  });
}

class ReceiptService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  ReceiptService({
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  /// Picks an image file from camera or gallery.
  Future<XFile?> pickReceiptImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      return file;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Uploads a receipt image to Firebase Storage under the specific workspace.
  Future<ReceiptAttachmentResult> uploadReceipt({
    required String workspaceId,
    required XFile file,
    String? customFileName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = file.name.split('.').last;
    final safeFileName = customFileName ?? 'receipt_$timestamp.$extension';
    final path = 'workspaces/$workspaceId/receipts/$safeFileName';

    final ref = _storage.ref().child(path);
    final Uint8List bytes = await file.readAsBytes();

    final metadata = SettableMetadata(
      contentType: 'image/$extension',
      customMetadata: {
        'workspaceId': workspaceId,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final uploadTask = await ref.putData(bytes, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    return ReceiptAttachmentResult(
      downloadUrl: downloadUrl,
      storagePath: path,
    );
  }

  /// Deletes a receipt image from Firebase Storage.
  Future<void> deleteReceipt(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      final ref = _storage.ref().child(storagePath);
      await ref.delete();
    } catch (e) {
      debugPrint('Failed to delete receipt from storage: $e');
    }
  }
}
