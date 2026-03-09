// 웹/네이티브 import를 먼저 분리해서,
// 각 플랫폼이 자기 전용 구현만 보도록 만든다.
// package:web 자체는 조건식에 쓸 수 없으므로,
// 기본은 IO 구현을 사용하고 웹일 때만 전용 구현으로 갈아낀다.
export 'platform_http_client_io.dart'
    if (dart.library.js_interop) 'platform_http_client_web.dart';
