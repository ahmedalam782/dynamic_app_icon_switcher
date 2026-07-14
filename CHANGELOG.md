## 0.1.0

* Initial release: switch Android launcher icons via `activity-alias` and iOS
  home-screen icons via `CFBundleAlternateIcons`.
* Public API: `supportsAlternateIcons`, `setIcon`, `currentIcon`,
  `getAvailableIcons`, picker helpers, and `applyActiveIconIfNeeded`.
* HTTP API brand config models (`RemoteBrandConfig` / `RemoteAppIconConfig` /
  `RemoteSplashConfig`) — control layer is your backend, not Firebase.
* Example: auto-apply `active_icon` + cached splash sync via API.
