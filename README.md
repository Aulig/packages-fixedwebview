Issues fixed:
- webview Fullscreen:
  - Fixed on Android based on https://github.com/flutter/plugins/pull/3722 and https://github.com/lycstar/plugins who had updated it to a more recent webview_flutter version.
  - Seems to work out of the box on iOS these days, previously we needed to set something like [[self preferencesForIdentifier:identifier] setValue:@YES forKey:@"fullScreenEnabled"] or WKPreferences* preferences = [[_webView configuration] preferences]; [preferences setValue:@YES forKey:@"fullScreenEnabled"];
    
- iOS alert/prompt/confirm: based on https://github.com/fluttercommunity/flutter_webview_plugin/pull/522/commits/052d46018fdf45ce300e45f71657faf2d349479c
