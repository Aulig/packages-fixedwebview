Issues fixed:    
- iOS alert/prompt/confirm: based on https://github.com/fluttercommunity/flutter_webview_plugin/pull/522/commits/052d46018fdf45ce300e45f71657faf2d349479c
  WE'RE COMMENTING OUT THE WIP OFFICIAL IMPLEMENTATION UNTIL IT'S READY (see runJavaScriptTextInputPanelWithPrompt, runJavaScriptConfirmPanelWithMessage, runJavaScriptAlertPanelWithMessage in FWFUIDelegateHostAPI.m)
- Android webView.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE) to match behaviour of Chrome (passive mixed content like images is allowed, active mixed content like scripts is not). Mixed content is when resources are loaded via HTTP on a HTTPS page.
- getCopyBackForwardList (to get the webview history). The implementation is not the best (we pass the data as a Map<String, dynamic) since I couldn't get the class to work)

Old fixes that we removed since they were fixed upstream:
- webview Fullscreen:
  - Fixed on Android based on https://github.com/flutter/plugins/pull/3722 and https://github.com/lycstar/plugins who had updated it to a more recent webview_flutter version.
  - Seems to work out of the box on iOS these days, previously we needed to set something like [[self preferencesForIdentifier:identifier] setValue:@YES forKey:@"fullScreenEnabled"] or WKPreferences* preferences = [[_webView configuration] preferences]; [preferences setValue:@YES forKey:@"fullScreenEnabled"];
  Currently it'd mean setting [preferences setValue:@YES forKey:@"fullScreenEnabled"]; in FWFPreferencesHostApi.preferencesForIdentifier for example (not a clean way of doing it but oh well).


How to pull in upstream changes if it doesn't work through Githubs web interface:
- Open Github desktop
- Branch > Compare to Branch
- Use the search to select upstream/main
- Create Merge Commit
- Keep readme from this repository (main, not upstream)
