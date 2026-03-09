import 'package:http/browser_client.dart';
import 'package:http/http.dart';

// 웹에서는 브라우저 네이티브 fetch/XHR 계층을 타는 BrowserClient를 사용한다.
Client createPlatformHttpClient() => BrowserClient();

