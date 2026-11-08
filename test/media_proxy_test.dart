import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/player/media_proxy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  testWidgets('媒体代理转发 GET/HEAD/Range 与音频响应头', (tester) async {
    await tester.runAsync(() async {
      final remote = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => remote.close(force: true));
      remote.listen((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        final data = utf8.encode('AUDIO-DATA');
        final response = request.response;
        response.headers.set(HttpHeaders.contentTypeHeader, 'audio/mpeg');
        response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        if (range != null) {
          response.statusCode = HttpStatus.partialContent;
          response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-1/${data.length}');
          response.headers.set(HttpHeaders.contentLengthHeader, '2');
          if (request.method != 'HEAD') response.add([data[0], data[1]]);
        } else {
          response.statusCode = HttpStatus.ok;
          response.headers.set(HttpHeaders.contentLengthHeader, '${data.length}');
          if (request.method != 'HEAD') response.add(data);
        }
        await response.close();
      });

      await MediaProxy.instance.ensureStarted();
      final proxy = MediaProxy.instance.register(
        'http://127.0.0.1:${remote.port}/track.mp3',
        const {'Referer': 'https://example.com/'},
      );
      addTearDown(() => MediaProxy.instance.dispose());

      final client = HttpClient();
      final ranged = await client.getUrl(Uri.parse(proxy));
      ranged.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
      final rangedResponse = await ranged.close();
      expect(rangedResponse.statusCode, HttpStatus.partialContent);
      expect(rangedResponse.headers.contentType?.mimeType, 'audio/mpeg');
      expect(rangedResponse.headers.value(HttpHeaders.contentRangeHeader), isNotNull);
      await rangedResponse.drain<void>();

      final head = await client.headUrl(Uri.parse(proxy));
      final headResponse = await head.close();
      expect(headResponse.statusCode, HttpStatus.ok);
      expect(headResponse.headers.contentType?.mimeType, 'audio/mpeg');
      await headResponse.drain<void>();
      client.close(force: true);
    });
  });
}