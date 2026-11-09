// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';

/// A JavaScript operation was cancelled because its document was replaced.
///
/// The script may already have executed. Do not automatically retry side effects.
class JavaScriptDocumentChangedException extends PlatformException {
  /// Creates a document-change cancellation error.
  JavaScriptDocumentChangedException()
    : super(
        code: 'javascript_document_changed',
        message: 'The document changed during JavaScript execution.',
      );
}
