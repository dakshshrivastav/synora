import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freon/ai/lm_studio.dart';

void main() {
  late HttpServer server;
  late LmStudio client;
  late String base;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    client = LmStudio(timeout: const Duration(milliseconds: 500));
  });
  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('discovers models with optional /v1 URL suffix', () async {
    server.listen((request) async {
      expect(request.uri.path, '/v1/models');
      request.response.write(
        jsonEncode({
          'data': [
            {'id': 'text-local'},
            {'id': 'vision-local'},
          ],
        }),
      );
      await request.response.close();
    });
    expect(await client.models('$base/v1'), ['text-local', 'vision-local']);
  });

  test('decodes fragmented UTF8 SSE without exposing reasoning fields', () async {
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body['stream'], true);
      expect(body['model'], 'text-local');
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      final payload =
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'reasoning_content': 'private', 'content': 'A calmer café.'},
              },
            ],
          })}\n\ndata: [DONE]\n\n';
      for (final byte in utf8.encode(payload)) {
        request.response.add([byte]);
      }
      await request.response.close();
    });
    expect(
      await client.chat(base, 'text-local', [
        {'role': 'user', 'content': 'Hello'},
      ]).join(),
      'A calmer café.',
    );
  });

  test('truncated stream keeps partial text and reports failure', () async {
    server.listen((request) async {
      request.response.write(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'Partial'},
            },
          ],
        })}\n\n',
      );
      await request.response.close();
    });
    await expectLater(
      client.chat(base, 'test', []),
      emitsInOrder(['Partial', emitsError(isA<ModelFailure>())]),
    );
  });

  test('normalizes authorization failure', () async {
    server.listen((request) async {
      request.response.statusCode = 401;
      await request.response.close();
    });
    await expectLater(
      client.models(base),
      throwsA(
        isA<ModelFailure>().having(
          (e) => e.message,
          'message',
          contains('FREON_LM_TOKEN'),
        ),
      ),
    );
  });

  test('idle model request times out', () async {
    server.listen((request) async {
      await request.drain<void>();
    });
    await expectLater(
      client.chat(base, 'test', []).join(),
      throwsA(
        isA<ModelFailure>().having(
          (e) => e.message,
          'message',
          contains('stopped responding'),
        ),
      ),
    );
  });
}
