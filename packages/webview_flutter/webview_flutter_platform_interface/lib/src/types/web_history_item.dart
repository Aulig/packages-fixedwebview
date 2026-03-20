// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

@immutable
class WebHistoryItem {
  const WebHistoryItem(
    this.title,
    this.url, {
    this.originalUrl,
    this.index,
    this.offset,
  });

  /// Original URL of this history item.
  final Uri? originalUrl;

  /// Document title of this history item.
  final String title;

  /// URL of this history item.
  final Uri url;

  /// 0-based position index in the back-forward history list.
  final int? index;

  /// Position offset relative to the current index in the back-forward list.
  final int? offset;
}
