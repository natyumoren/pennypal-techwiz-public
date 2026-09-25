import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Receipt photos (optional SRS feature). On mobile the image is copied to
/// the app's private documents folder; on the Web it is stored as a
/// compressed data URI so it survives page reloads.
class ReceiptService {
  ReceiptService._();
  static final _picker = ImagePicker();

  static Future<String?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
        source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
    if (file == null) return null;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
    final dir = await getApplicationDocumentsDirectory();
    final receipts = Directory(p.join(dir.path, 'receipts'));
    if (!await receipts.exists()) await receipts.create(recursive: true);
    final target = p.join(receipts.path,
        'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}');
    await File(file.path).copy(target);
    return target;
  }
}
