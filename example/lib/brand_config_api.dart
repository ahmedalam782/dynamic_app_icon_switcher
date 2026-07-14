import 'package:dio/dio.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';

import 'demo_brand_store.dart';

/// Fetches icon + splash brand config from **your backend API** via [Dio].
///
/// Production:
/// ```dart
/// final api = BrandConfigApi(
///   dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
/// );
/// final brand = await api.fetchBrandConfig();
/// ```
///
/// The example app uses a demo [Dio] interceptor backed by [DemoBrandStore]
/// so no live server is required. Call [setActiveIconAsAdmin] to simulate an
/// admin changing the launcher icon anytime (must already be bundled).
class BrandConfigApi {
  BrandConfigApi({Dio? dio, DemoBrandStore? store})
      : _dio = dio ?? createDemoDio(store: store),
        _store = store ?? DemoBrandStore.instance;

  final Dio _dio;
  final DemoBrandStore _store;

  /// Demo Dio client that resolves `GET /branding` from [DemoBrandStore].
  static Dio createDemoDio({DemoBrandStore? store}) {
    final brandStore = store ?? DemoBrandStore.instance;
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.example.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
          // Simulate network latency like a real backend.
          await Future<void>.delayed(const Duration(milliseconds: 400));

          if (options.path == '/branding' ||
              options.path.endsWith('/branding')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: Map<String, dynamic>.from(brandStore.payload),
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              message: 'Unhandled demo path: ${options.path}',
            ),
          );
        },
      ),
    );

    return dio;
  }

  /// GET `/branding` → [RemoteBrandConfig].
  ///
  /// To enable a CDN splash (ImageKit / S3 / etc.), set in the API response:
  ///   `"use_default_splash": false`,
  ///   `"image_url": "https://ik.imagekit.io/.../splash.webp"`,
  ///   `"image_version": "4"`
  Future<RemoteBrandConfig> fetchBrandConfig({
    String path = '/branding',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(path);
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Brand config API returned an empty body',
        type: DioExceptionType.badResponse,
        response: response,
      );
    }
    return RemoteBrandConfig.parse(data);
  }

  /// Demo-only: pretend an admin updated `active_icon` on the server.
  ///
  /// In production, your admin panel writes the same fields to your DB / CMS,
  /// then mobile clients call [fetchBrandConfig] and `applyFromConfig`.
  void setActiveIconAsAdmin(String iconName, {bool enabled = true}) {
    _store.setActiveIcon(iconName, enabled: enabled);
  }
}
