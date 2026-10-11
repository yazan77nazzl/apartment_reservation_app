import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:apartment_reservation_app/services/supabase_image_storage.dart';

void main() {
  const base = 'https://testproject.supabase.co';
  final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]);
  SupabaseImageUploader uploader(http.Client client) => SupabaseImageUploader(
      projectUrl: base, publicKey: 'sb_publishable_test', client: client);

  test(
      'uploads with Firebase bearer token to owned path and returns public URL',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.host, 'testproject.supabase.co');
      expect(
          request.url.path,
          startsWith(
              '/storage/v1/object/housing-images/apartments/ownerUid/apartment1/'));
      expect(request.headers['Authorization'], 'Bearer firebase-id-token');
      expect(request.headers['apikey'], 'sb_publishable_test');
      expect(request.headers['x-upsert'], 'false');
      expect(request.headers['Content-Type'], 'image/png');
      expect(request.bodyBytes, png);
      return http.Response('{"Key":"uploaded"}', 200);
    });
    final url = await uploader(client).upload(
        bytes: png,
        folder: 'apartments/apartment1',
        uid: 'ownerUid',
        token: 'firebase-id-token');
    expect(
        url,
        startsWith(
            '$base/storage/v1/object/public/housing-images/apartments/ownerUid/apartment1/'));
    expect(url, endsWith('.png'));
    client.close();
  });

  test('rejects secrets and untrusted hosts before sending credentials', () {
    for (final key in [
      'sb_secret_private',
      'not-a-public-key',
      'x.${base64Url.encode(utf8.encode('{"role":"service_role"}'))}.x'
    ]) {
      expect(
          () => SupabaseImageUploader(projectUrl: base, publicKey: key)
              .validateConfiguration(),
          throwsStateError);
    }
    for (final url in [
      'http://testproject.supabase.co',
      'https://testproject.supabase.co.attacker.test',
      '$base/path',
      '$base?key=value'
    ]) {
      expect(
          () => SupabaseImageUploader(
                  projectUrl: url, publicKey: 'sb_publishable_test')
              .validateConfiguration(),
          throwsStateError);
    }
  });

  test(
      'rejects foreign profile paths, bad files, missing tokens and oversized photos',
      () async {
    final client =
        MockClient((_) async => fail('Invalid input must not send an upload'));
    final storage = uploader(client);
    await expectLater(
        storage.upload(
            bytes: png,
            folder: 'profiles/otherUid',
            uid: 'myUid',
            token: 'token'),
        throwsStateError);
    await expectLater(
        storage.upload(
            bytes: png,
            folder: 'apartments/../bad',
            uid: 'myUid',
            token: 'token'),
        throwsStateError);
    await expectLater(
        storage.upload(
            bytes: png, folder: 'profiles/myUid', uid: 'myUid', token: ''),
        throwsStateError);
    await expectLater(
        storage.upload(
            bytes: Uint8List.fromList(utf8.encode('<svg>')),
            folder: 'profiles/myUid',
            uid: 'myUid',
            token: 'token'),
        throwsStateError);
    await expectLater(
        storage.upload(
            bytes: Uint8List(SupabaseImageUploader.maxBytes + 1),
            folder: 'profiles/myUid',
            uid: 'myUid',
            token: 'token'),
        throwsStateError);
    client.close();
  });

  test(
      'upload permission errors do not expose server response or return a photo URL',
      () async {
    final client = MockClient(
        (_) async => http.Response('private server diagnostic', 403));
    await expectLater(
        uploader(client).upload(
            bytes: png, folder: 'profiles/myUid', uid: 'myUid', token: 'token'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('permission was denied'))));
    client.close();
  });
}
