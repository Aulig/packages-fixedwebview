// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.webviewflutter;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.webkit.WebView;
import androidx.annotation.NonNull;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;
import java.util.WeakHashMap;
import kotlin.Result;
import kotlin.Unit;
import kotlin.jvm.functions.Function1;

/** Tracks JavaScript evaluations until Android acknowledges them or their document is replaced. */
final class JavaScriptEvaluator {
  private static final long DOCUMENT_CHANGE_GRACE_PERIOD_MILLIS = 50;
  private final Handler handler = new Handler(Looper.getMainLooper());

  // All methods and Android evaluation callbacks run on the Android UI thread.
  private static final class EvaluationState {
    final Set<PendingEvaluation> pending = new HashSet<>();
    boolean disposed = false;

    EvaluationState() {}
  }

  private static final class PendingEvaluation {
    final Function1<? super Result<String>, Unit> callback;

    PendingEvaluation(Function1<? super Result<String>, Unit> callback) {
      this.callback = callback;
    }
  }

  // Neither the state nor the callback below retains the WebView. An otherwise unused view can be
  // collected even when Chromium has abandoned an evaluation callback.
  private final WeakHashMap<WebView, EvaluationState> states = new WeakHashMap<>();
  private boolean disposed = false;

  void evaluate(
      @NonNull WebView webView,
      @NonNull String javascript,
      @NonNull Function1<? super Result<String>, Unit> callback) {
    final EvaluationState state = states.computeIfAbsent(webView, unused -> new EvaluationState());
    if (disposed || state.disposed) {
      ResultCompat.failure(disposedError(), callback);
      return;
    }
    final PendingEvaluation evaluation = new PendingEvaluation(callback);
    state.pending.add(evaluation);
    webView.evaluateJavascript(
        javascript,
        result -> {
          // Removing this exact request makes cancellation and a late callback mutually exclusive.
          // A late callback must never complete a subsequent request or reply twice to Pigeon.
          if (state.pending.remove(evaluation)) {
            ResultCompat.success(result, evaluation.callback);
          }
        });
  }

  Runnable documentChanged(@NonNull WebView webView) {
    final EvaluationState state = states.get(webView);
    if (state == null) {
      return () -> {};
    }
    final ArrayList<PendingEvaluation> previousDocument = new ArrayList<>(state.pending);
    final long cancelAt = SystemClock.uptimeMillis() + DOCUMENT_CHANGE_GRACE_PERIOD_MILLIS;
    final Runnable cancelPending =
        () -> {
          for (PendingEvaluation evaluation : previousDocument) {
            if (state.pending.remove(evaluation)) {
              // This is cancellation, not evidence that the script did not execute. Never retry it.
              ResultCompat.failure(
                  new AndroidWebKitError(
                      "javascript_document_changed",
                      "The document changed before JavaScript execution was acknowledged.",
                      null),
                  evaluation.callback);
            }
          }
        };
    // A valid callback can arrive shortly after the page-start event. Keep its real result if it
    // arrives during this grace period. Only requests captured at the document change are eligible
    // for cancellation; evaluations started by the new document remain untouched.
    // The caller invokes this after Dart acknowledges the page-start event, preserving that ordering
    // even if the acknowledgement takes longer than the grace period.
    return () ->
        handler.postDelayed(cancelPending, Math.max(0, cancelAt - SystemClock.uptimeMillis()));
  }

  void dispose(@NonNull WebView webView) {
    final EvaluationState state = states.computeIfAbsent(webView, unused -> new EvaluationState());
    state.disposed = true;
    cancelDisposed(state);
  }

  void dispose() {
    disposed = true;
    handler.removeCallbacksAndMessages(null);
    for (EvaluationState state : states.values()) {
      cancelDisposed(state);
    }
    states.clear();
  }

  private static void cancelDisposed(EvaluationState state) {
    final ArrayList<PendingEvaluation> pending = new ArrayList<>(state.pending);
    state.pending.clear();
    for (PendingEvaluation evaluation : pending) {
      ResultCompat.failure(disposedError(), evaluation.callback);
    }
  }

  private static AndroidWebKitError disposedError() {
    return new AndroidWebKitError(
        "javascript_execution_disposed", "The WebView or Flutter engine was disposed.", null);
  }
}
