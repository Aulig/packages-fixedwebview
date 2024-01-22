import 'web_history_item.dart';
import 'package:meta/meta.dart';

@immutable
class WebHistory {
  ///List of all [WebHistoryItem]s.
  final List<WebHistoryItem>? list;

  ///Index of the current [WebHistoryItem].
  final int? currentIndex;

  WebHistory({this.list, this.currentIndex});
}