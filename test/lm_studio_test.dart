import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freon/ai/lm_studio.dart';

import 'meal_estimate_test.dart' show validEstimate;

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

  test(
    'sends image and caption together and parses the structured estimate',
    () async {
      final photo = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      const caption =
          '24 cm plate; 1 cup rice, 120 g chicken and 1 tsp oil. Ate all.';
      server.listen((request) async {
        expect(request.uri.path, '/v1/chat/completions');
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['model'], 'vision-local');
        expect(body['stream'], false);
        expect(body['response_format']['type'], 'json_schema');
        final content = body['messages'][1]['content'] as List;
        expect(content[0]['text'], contains(caption));
        expect(
          content[1]['image_url']['url'],
          'data:image/png;base64,${base64Encode(photo)}',
        );
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'content': jsonEncode(validEstimate)},
              },
            ],
          }),
        );
        await request.response.close();
      });
      final estimate = await client.estimateMeal(
        base,
        'vision-local',
        photo,
        caption,
      );
      expect(estimate.calories, 520);
      expect(estimate.assumptions.single, contains('caption'));
    },
  );

  test('only schema rejection retries in compatibility mode', () async {
    var calls = 0;
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      calls++;
      if (calls == 1) {
        request.response.statusCode = 400;
        request.response.write('{"error":"json_schema is not supported"}');
      } else {
        expect(body.containsKey('response_format'), false);
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {
                  'content': '```json\n${jsonEncode(validEstimate)}\n```',
                },
              },
            ],
          }),
        );
      }
      await request.response.close();
    });
    await client.estimateMeal(
      base,
      'vision',
      Uint8List.fromList([1]),
      'A plate of lunch',
    );
    expect(calls, 2);
  });

  test('malformed or truncated estimates are not accepted', () async {
    server.listen((request) async {
      await request.drain<void>();
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'finish_reason': 'length',
              'message': {'content': jsonEncode(validEstimate)},
            },
          ],
        }),
      );
      await request.response.close();
    });
    await expectLater(
      client.estimateMeal(base, 'vision', Uint8List.fromList([1]), 'A plate'),
      throwsA(isA<ModelFailure>()),
    );
  });

  test('missing caption and vision model do not start requests', () async {
    await expectLater(
      client.estimateMeal(base, 'vision', Uint8List.fromList([1]), '  '),
      throwsA(isA<ModelFailure>()),
    );
    await expectLater(
      client.estimateMeal(base, '', Uint8List.fromList([1]), 'Lunch'),
      throwsA(isA<ModelFailure>()),
    );
  });
}
