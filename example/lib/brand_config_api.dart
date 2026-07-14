import 'package:dio/dio.dart';
import 'package:dynamic_app_icon_switcher/dynamic_app_icon_switcher.dart';

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
/// The example app uses a demo [Dio] interceptor so no live server is required.
class BrandConfigApi {
  BrandConfigApi({Dio? dio}) : _dio = dio ?? createDemoDio();

  final Dio _dio;

  /// Demo Dio client that resolves `GET /branding` from an in-memory payload.
  static Dio createDemoDio() {
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
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          // Simulate network latency like a real backend.
          await Future<void>.delayed(const Duration(milliseconds: 400));

          if (options.path == '/branding' || options.path.endsWith('/branding')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: _demoPayload,
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

  /// Demo JSON the interceptor returns for `GET /branding`.
  static const Map<String, dynamic> _demoPayload = <String, dynamic>{
    'app_icon': <String, dynamic>{
      'enabled': true,
      'active_icon': 'Ramadan',
      'icon_version': '3',
      'available_icons': <String>[
        'Ramadan',
        'EidAdha',
        'Red',
        'Blue',
        'Green',
        'WorldCup',
      ],
      'icon_schedule': <Map<String, String>>[
        <String, String>{
          'icon': 'Ramadan',
          'from': '2026-02-01',
          'to': '2026-03-31',
        },
        <String, String>{
          'icon': 'EidAdha',
          'from': '2026-05-01',
          'to': '2026-06-30',
        },
        <String, String>{
          'icon': 'WorldCup',
          'from': '2026-06-01',
          'to': '2026-07-31',
        },
        <String, String>{
          'icon': 'Green',
          'from': '2026-07-01',
          'to': '2026-07-20',
        },
        <String, String>{
          'icon': 'Red',
          'from': '2026-01-01',
          'to': '2026-06-30',
        },
        <String, String>{
          'icon': 'Blue',
          'from': '2026-08-01',
          'to': '2026-12-31',
        },
      ],
    },
    'splash': <String, dynamic>{
      'use_default_splash': true,
      'image_url': '',
      'image_version': '1',
    },
  };
}
