// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'web_history_item.dart';

@immutable
class WebHistory {
  const WebHistory(this.history, this.currentIndex);

  /// List of all [WebHistoryItem]s.
  final List<WebHistoryItem> history;

  /// Index of the current [WebHistoryItem].
  final int currentIndex;
}
