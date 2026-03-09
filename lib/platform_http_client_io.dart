import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

Client _createDefaultIoClient() => IOClient(HttpClient());

// 조건부 import만으로는 iOS/Android를 직접 구분할 수 없어서,
// IO 환경에 들어온 뒤에 런타임 플랫폼 분기로 한 번 더 나눈다.
Client createPlatformHttpClient() {
  if (Platform.isIOS) {
    return CupertinoClient.defaultSessionConfiguration();
  }

  if (Platform.isAndroid) {
    try {
      final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
      );
      return CronetClient.fromCronetEngine(engine, closeEngine: true);
    } catch (_) {
      // Google Play 서비스가 없거나 Cronet 엔진 초기화에 실패하면
      // 기존 dart:io 기반 클라이언트로 안전하게 폴백한다.
      return _createDefaultIoClient();
    }
  }

  return _createDefaultIoClient();
}
