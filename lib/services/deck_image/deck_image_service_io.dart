import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'deck_image_result.dart';

class DeckImageService {
  static const int avatarWidth = 200;
  static const int avatarHeight = 280;

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 90,
    );
  }

  Future<DeckImageResult?> saveFullAndAvatar(XFile? xFile) async {
    if (xFile == null) return null;
    final bytes = await xFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    img.Image? cropped = _cropToAvatarAspect(image);
    if (cropped == null) return null;
    cropped = img.copyResize(cropped, width: avatarWidth, height: avatarHeight);
    final avatarBytes = img.encodeJpg(cropped, quality: 88);

    return DeckImageResult(
      fullBytes: Uint8List.fromList(bytes),
      avatarBytes: Uint8List.fromList(avatarBytes),
    );
  }

  img.Image? _cropToAvatarAspect(img.Image src) {
    final w = src.width;
    final h = src.height;
    final targetRatio = avatarWidth / avatarHeight;
    final currentRatio = w / h;

    int cropW;
    int cropH;
    int x0;
    int y0;

    if (currentRatio > targetRatio) {
      cropH = h;
      cropW = (h * targetRatio).round();
      x0 = (w - cropW) ~/ 2;
      y0 = 0;
    } else {
      cropW = w;
      cropH = (w / targetRatio).round();
      x0 = 0;
      y0 = (h - cropH) ~/ 2;
    }

    if (cropW <= 0 || cropH <= 0) return null;
    return img.copyCrop(src, x: x0, y: y0, width: cropW, height: cropH);
  }
}
