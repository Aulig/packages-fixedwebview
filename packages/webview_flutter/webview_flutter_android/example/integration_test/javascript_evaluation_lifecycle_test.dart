// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter_android/src/android_webkit.g.dart'
    as android_webkit;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final returnsResult in <bool>[false, true]) {
    testWidgets(
      "${returnsResult ? 'Result' : 'Void'} callbacks settle across document replacements",
      (WidgetTester tester) async {
        final HttpServer server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        server.listen((HttpRequest request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (request.uri.path.startsWith('/redirect/')) {
            request.response.statusCode = HttpStatus.found;
            request.response.headers.set(
              HttpHeaders.locationHeader,
              request.uri.path.replaceFirst('/redirect', ''),
            );
          } else {
            request.response.headers.contentType = ContentType.html;
            request.response.write(
              '<!doctype html><title>${request.uri.path}</title><body>Loaded</body>',
            );
          }
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));
        final controller = AndroidWebViewController(
          const PlatformWebViewControllerCreationParams(),
        );
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        final delegate = AndroidNavigationDelegate(
          const PlatformNavigationDelegateCreationParams(),
        );
        await controller.setPlatformNavigationDelegate(delegate);
        await _showWebView(tester, controller);
        Future<Object>? newDocumentResult;
        await delegate.setOnPageStarted((_) {
          // The old request cancellation is acknowledged asynchronously. A call started by this
          // event belongs to the replacement document and must not be included in that cancellation.
          newDocumentResult = controller.runJavaScriptReturningResult('314');
        });
        var cancelled = 0;
        for (var index = 0; index < 24; index++) {
          // Include redirects and reloads of exactly the same URL. URL comparison alone cannot
          // distinguish a replacement document from the existing document.
          final bool reload = index > 0 && index % 4 == 0;
          final path = reload ? '/document-${index - 1}' : '/document-$index';
          final destination = 'http://127.0.0.1:${server.port}$path';
          final finished = Completer<void>();
          await delegate.setOnPageFinished((String url) {
            if (url == destination && !finished.isCompleted) {
              finished.complete();
            }
          });
          if (reload) {
            await controller.reload();
          } else {
            await controller.loadRequest(
              LoadRequestParams(
                uri: Uri.parse(
                  index % 3 == 0
                      ? 'http://127.0.0.1:${server.port}/redirect$path'
                      : destination,
                ),
              ),
            );
          }
          final loading = Stopwatch()..start();
          while (!finished.isCompleted) {
            const javascript = '''
if (document.head !== null && document.getElementById("navigation-test-style") === null) {
  const style = document.createElement("style");
  style.id = "navigation-test-style";
  style.textContent = "body { background: white; }";
  document.head.appendChild(style);
}
''';
            try {
              if (returnsResult) {
                expect(
                  await controller
                      .runJavaScriptReturningResult('$javascript\n42;')
                      .timeout(const Duration(seconds: 3)),
                  42,
                );
              } else {
                await controller
                    .runJavaScript(javascript)
                    .timeout(const Duration(seconds: 3));
              }
            } on JavaScriptDocumentChangedException catch (error) {
              expect(error.code, 'javascript_document_changed');
              cancelled++;
            }
            if (loading.elapsed > const Duration(seconds: 10)) {
              fail(
                'The replacement document did not finish loading: $destination',
              );
            }
          }
          expect(
            await newDocumentResult!.timeout(const Duration(seconds: 3)),
            314,
          );
          await controller.runJavaScript('window.testOrder = $index;');
          expect(
            await controller.runJavaScriptReturningResult(
              'window.testOrder === $index',
            ),
            true,
          );
          expect(await controller.currentUrl(), destination);
        }
        // These exercise the existing controller result conversion, without substituting a
        // different JavaScript transport or evaluating the source inside a wrapper.
        for (final MapEntry<String, Object> entry in <String, Object>{
          'null': 'null',
          'undefined': 'null',
          'true': true,
          'false': false,
          '42': 42,
          '1.5': 1.5,
          '"hello"': '"hello"',
          '({key: "value"})': '{"key":"value"}',
          '[1, 2]': '[1,2]',
        }.entries) {
          expect(
            await controller.runJavaScriptReturningResult(entry.key),
            entry.value,
          );
        }
        // This count proves that an affected runtime actually exercised cancellation, rather than
        // merely completing normal callbacks throughout the test.
        // ignore: avoid_print
        print(
          "Cancelled $cancelled ${returnsResult ? 'result' : 'void'} callbacks in 24 document replacements.",
        );
      },
      skip: !Platform.isAndroid,
    );
  }

  testWidgets(
    'Slow execution and navigation without document replacement keep their results',
    (WidgetTester tester) async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      server.listen((HttpRequest request) async {
        if (request.uri.path == '/no-content') {
          request.response.statusCode = HttpStatus.noContent;
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<!doctype html><body><iframe id=child></iframe></body>',
          );
        }
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final controller = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      final delegate = AndroidNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      var pageStarts = 0;
      await delegate.setOnPageStarted((_) => pageStarts++);
      final loaded = Completer<void>();
      await delegate.setOnPageFinished((_) {
        if (!loaded.isCompleted) {
          loaded.complete();
        }
      });
      await delegate.setOnNavigationRequest(
        (NavigationRequest request) => request.url.contains('/blocked')
            ? NavigationDecision.prevent
            : NavigationDecision.navigate,
      );
      await controller.setPlatformNavigationDelegate(delegate);
      await _showWebView(tester, controller);
      final origin = 'http://127.0.0.1:${server.port}';
      await controller.loadRequest(
        LoadRequestParams(uri: Uri.parse('$origin/stable')),
      );
      await loaded.future.timeout(const Duration(seconds: 10));
      final initialPageStarts = pageStarts;
      // Each real renderer execution lasts longer than the rejected one-second timeout workaround.
      for (final operation in <String>[
        'history.pushState({}, "", "#state"); location.hash = "fragment";',
        'document.getElementById("child").src = "$origin/iframe";',
        'location.href = "$origin/blocked";',
        'location.href = "$origin/no-content";',
      ]) {
        expect(
          await controller
              .runJavaScriptReturningResult('''
(() => {
  $operation
  const deadline = performance.now() + 1500;
  while (performance.now() < deadline) {}
  return 7;
})()
''')
              .timeout(const Duration(seconds: 5)),
          7,
        );
        expect(await controller.runJavaScriptReturningResult('42'), 42);
        expect(pageStarts, initialPageStarts);
      }
      await controller.runJavaScript('let lifecycleTestLexical = 23;');
      expect(
        await controller.runJavaScriptReturningResult('lifecycleTestLexical'),
        23,
      );
    },
    skip: !Platform.isAndroid,
  );

  testWidgets(
    'Destroying a view settles concurrent evaluations and ignores late callbacks',
    (WidgetTester tester) async {
      final controller = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      final loaded = Completer<void>();
      final started = Completer<void>();
      await controller.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'ExecutionStarted',
          onMessageReceived: (_) => started.complete(),
        ),
      );
      final delegate = AndroidNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      await delegate.setOnPageFinished((_) {
        if (!loaded.isCompleted) {
          loaded.complete();
        }
      });
      await controller.setPlatformNavigationDelegate(delegate);
      await _showWebView(tester, controller);
      await controller.loadHtmlString(
        '<!doctype html><body>Execution test</body>',
      );
      await loaded.future.timeout(const Duration(seconds: 10));
      final Future<Object> pendingResult = controller
          .runJavaScriptReturningResult('''
(() => {
  ExecutionStarted.postMessage("started");
  const deadline = performance.now() + 1500;
  while (performance.now() < deadline) {}
  return 7;
})()
''');
      final Future<void> resultCancelled = expectLater(
        pendingResult,
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'javascript_execution_disposed',
          ),
        ),
      );
      await started.future.timeout(const Duration(seconds: 3));
      final Future<void> voidCancelled = expectLater(
        controller.runJavaScript('window.otherExecution = true'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'javascript_execution_disposed',
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final android_webkit.WebView nativeView = android_webkit
          .PigeonInstanceManager
          .instance
          .getInstanceWithWeakReference<android_webkit.WebView>(
            controller.webViewIdentifier,
          )!;
      await nativeView.destroy();
      await Future.wait(<Future<void>>[
        resultCancelled,
        voidCancelled,
      ]).timeout(const Duration(seconds: 3));
      await expectLater(
        controller.runJavaScriptReturningResult('42'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'javascript_execution_disposed',
          ),
        ),
      );

      final replacement = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      await replacement.setJavaScriptMode(JavaScriptMode.unrestricted);
      expect(
        await replacement
            .runJavaScriptReturningResult('42')
            .timeout(const Duration(seconds: 5)),
        42,
      );
      // Let the real old renderer callback arrive, if Chromium still delivers it after destruction.
      // A duplicate Pigeon reply would fail this test with an unhandled native exception.
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(await replacement.runJavaScriptReturningResult('43'), 43);
    },
    skip: !Platform.isAndroid,
  );
}

Future<void> _showWebView(
  WidgetTester tester,
  AndroidWebViewController controller,
) async {
  await tester.pumpWidget(
    Builder(
      builder: (BuildContext context) => PlatformWebViewWidget(
        PlatformWebViewWidgetCreationParams(controller: controller),
      ).build(context),
    ),
  );
}
