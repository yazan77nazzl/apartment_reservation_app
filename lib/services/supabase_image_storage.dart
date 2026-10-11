import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/config/app_config.dart';
import 'image_storage.dart';

/// Public photos, authenticated uploads. Firebase remains the identity provider.
class SupabaseImageStorage implements ImageStorage {
  @override
  Future<String?> choose(BuildContext context, String folder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before uploading a photo.');
    final uploader = SupabaseImageUploader(
        projectUrl: AppConfig.supabaseUrl, publicKey: AppConfig.supabaseKey);
    uploader.validateConfiguration();
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
    if (picked == null) return null;
    final token = await user.getIdToken();
    if (token == null || FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('Sign in again before uploading a photo.');
    }
    return uploader.upload(
        bytes: await picked.readAsBytes(),
        folder: folder,
        uid: user.uid,
        token: token);
  }
}

class SupabaseImageUploader {
  static const bucket = 'housing-images';
  static const maxBytes = 8 * 1024 * 1024;
  final String projectUrl;
  final String publicKey;
  final http.Client? client;
  SupabaseImageUploader(
      {required this.projectUrl, required this.publicKey, this.client});

  void validateConfiguration() {
    final uri = Uri.tryParse(projectUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        !RegExp(r'^[a-z0-9]+\.supabase\.co$').hasMatch(uri.host) ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        publicKey.isEmpty) {
      throw StateError('Photo upload is not configured yet.');
    }
    if (publicKey.startsWith('sb_secret_')) {
      throw StateError('Photo uploads require a public project key.');
    }
    // Legacy JWT keys are accepted only when they carry the anon role.
    if (!publicKey.startsWith('sb_publishable_')) {
      try {
        final parts = publicKey.split('.');
        final claims = jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
        if (parts.length != 3 || claims['role'] != 'anon') {
          throw const FormatException();
        }
      } catch (_) {
        throw StateError('Photo uploads require a public project key.');
      }
    }
  }

  Future<String> upload(
      {required Uint8List bytes,
      required String folder,
      required String uid,
      required String token}) async {
    validateConfiguration();
    if (uid.isEmpty || uid.contains('/') || token.isEmpty) {
      throw StateError('Sign in before uploading a photo.');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw StateError('Choose a photo smaller than 8 MB.');
    }
    final (extension, mime) = _format(bytes);
    final segments = folder.split('/');
    final List<String> objectSegments;
    if (segments.length == 2 &&
        segments[0] == 'profiles' &&
        segments[1] == uid) {
      objectSegments = ['profiles', uid];
    } else if (segments.length == 2 &&
        segments[0] == 'apartments' &&
        RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(segments[1])) {
      objectSegments = ['apartments', uid, segments[1]];
    } else {
      throw StateError('Invalid photo destination.');
    }
    final random = Random.secure();
    final suffix = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    objectSegments
        .add('${DateTime.now().microsecondsSinceEpoch}-$suffix.$extension');
    final base = Uri.parse(projectUrl);
    final uploadUri = base.replace(
        pathSegments: ['storage', 'v1', 'object', bucket, ...objectSegments]);
    final transport = client ?? http.Client();
    try {
      final response = await transport
          .post(uploadUri,
              headers: {
                'apikey': publicKey,
                'Authorization': 'Bearer $token',
                'Content-Type': mime,
                'x-upsert': 'false',
                'Cache-Control': '3600',
              },
              body: bytes)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if ([401, 403].contains(response.statusCode)) {
          throw StateError(
              'Photo upload permission was denied. Contact the app owner.');
        }
        if (response.statusCode == 413) {
          throw StateError('Choose a photo smaller than 8 MB.');
        }
        throw StateError('Photo upload failed. Please try again.');
      }
      return base.replace(pathSegments: [
        'storage',
        'v1',
        'object',
        'public',
        bucket,
        ...objectSegments
      ]).toString();
    } on TimeoutException {
      throw StateError('Photo upload timed out. Please try again.');
    } on http.ClientException {
      throw StateError('Check your internet connection and try again.');
    } finally {
      if (client == null) transport.close();
    }
  }

  (String, String) _format(Uint8List bytes) {
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i]).join(',') ==
            '137,80,78,71,13,10,26,10') {
      return ('png', 'image/png');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return ('jpg', 'image/jpeg');
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return ('webp', 'image/webp');
    }
    throw StateError('Choose a JPG, PNG, or WebP photo.');
  }
}
