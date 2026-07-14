## 0.1.0

* Initial release: switch Android launcher icons via `activity-alias` and iOS
  home-screen icons via `CFBundleAlternateIcons`.
* Public API: `supportsAlternateIcons`, `setIcon`, `currentIcon`,
  `getAvailableIcons`, picker helpers, and `applyActiveIconIfNeeded`.
* HTTP API brand config models (`RemoteBrandConfig` / `RemoteAppIconConfig` /
  `RemoteSplashConfig`) — control layer is your backend via **Dio**, not Firebase.
* Example: Dio `BrandConfigApi`, auto-apply `active_icon`, cached splash sync,
  and seasonal demo icons (`Ramadan`, `EidAdha`).
* Example **Admin (API)** simulator: change `active_icon` anytime without a
  rebuild (icons must already be shipped in the binary).
