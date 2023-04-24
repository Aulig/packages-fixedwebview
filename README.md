Issues fixed:
- webview Fullscreen:
  - Fixed on Android
  - Seems to work out of the box on iOS these days, previously we needed to set something like
    [[self preferencesForIdentifier:identifier] setValue:@YES forKey:@"fullScreenEnabled"]
    or
    WKPreferences* preferences = [[_webView configuration] preferences];
    [preferences setValue:@YES forKey:@"fullScreenEnabled"];
    
