import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/l10n.dart';

abstract interface class ImageStorage {
  Future<String?> choose(BuildContext context, String folder);
}

class DemoImageStorage implements ImageStorage {
  static const apartments = [
    'assets/images/demo-garden.png',
    'assets/images/demo-olive.png'
  ];
  static const profiles = ['assets/images/demo-avatar.png'];
  @override
  Future<String?> choose(BuildContext context, String folder) =>
      showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(context.tr('Choose a temporary demo image'),
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(context.tr(
                      'Demo assets are bundled with the app. Personal photo uploads are unavailable in this mode.')),
                  const SizedBox(height: 16),
                  Wrap(
                      spacing: 12,
                      children: (folder.startsWith('profiles/')
                              ? profiles
                              : apartments)
                          .map((asset) => InkWell(
                              onTap: () => Navigator.pop(context, asset),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(asset,
                                      width: 140,
                                      height: 120,
                                      fit: BoxFit.cover))))
                          .toList()),
                ]))),
      );
}

class FirebaseImageStorage implements ImageStorage {
  @override
  Future<String?> choose(BuildContext context, String folder) async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    if (bytes.length >= 8 * 1024 * 1024) {
      throw StateError('Image must be smaller than 8 MB');
    }
    final lower = image.name.toLowerCase();
    final extension = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
            ? 'webp'
            : 'jpg';
    final target = FirebaseStorage.instance
        .ref('$folder/${DateTime.now().microsecondsSinceEpoch}.$extension');
    await target.putData(
        bytes,
        SettableMetadata(
            contentType:
                extension == 'jpg' ? 'image/jpeg' : 'image/$extension'));
    return target.getDownloadURL();
  }
}

ImageProvider<Object> housingImage(String path) =>
    path.startsWith('assets/') ? AssetImage(path) : NetworkImage(path);
