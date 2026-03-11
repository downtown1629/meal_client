# 밥먹어U

UNIST의 기숙사식당, 학생식당, 교직원식당 메뉴를 확인할 수 있는 애플리케이션입니다.

## 주요 기능

- 월요일부터 일요일까지 탭으로 주간 식단 조회
- 아침, 점심, 저녁 기준 끼니 전환
- 기숙사, 학생, 교직원 식당별 메뉴 구분
- 식단표 캐시 우선 로딩
- 식단 카드 길게 눌러서 메뉴 공유
- 다크 모드 자동 적용
- 영어 지원 (WIP)
- 웹 버전 (WIP)

## 프로젝트 구조

```text
meal_client/
├── lib/
│   ├── pages/
│   │   ├── home.dart
│   │   └── home_drawer.dart
│   ├── api_v2.dart
│   ├── data.dart
│   ├── i18n.dart
│   ├── main.dart
│   ├── meal.dart
│   ├── model.dart
│   ├── platform_http_client*.dart
│   └── storage*.dart
├── assets/
│   ├── fonts/
│   └── imgs/
├── android/
├── ios/
├── web/
├── test/
├── pubspec.yaml
└── LICENSE
```

## 프로젝트 인덱스

### 앱 진입점과 UI

- `lib/main.dart` - 애플리케이션 진입점, 전역 provider 설정, 앱 테마 생성, `MaterialApp` 구성.
- `lib/pages/home.dart` - 메인 화면, 날짜 탭, 끼니 전환, 중첩 스크롤 동작, 데이터 로딩, 공지 확인, 메뉴 렌더링.
- `lib/pages/home_drawer.dart` - 드로어(사이드바), 공지 다이얼로그, 운영 시간 섹션, 문의 링크, 라이선스 진입점.

### 상태와 도메인 모델

- `lib/model.dart` - 공용 언어/테마 상태를 위한 `BapUModel`과 화면 로컬 선택 상태를 위한 `HomePageModel`.
- `lib/meal.dart` - `Meal`, `CafeteriaMeal`, `DayMeal`, `WeekMeal` 및 관련 enum 등 핵심 도메인 타입.
- `lib/i18n.dart` - 문자열 리소스에서 사용하는 최소한의 언어 추상화.
- `lib/string.dart` - 현지화된 표시 문자열과 날짜 포맷 헬퍼.

### 데이터, 캐싱, 플랫폼 분기

- `lib/api_v2.dart` - 식단 및 공지사항 원격 API 호출과 JSON → 모델 파싱.
- `lib/data.dart` - 현재 주차 기준 캐시 정책, 캐시 읽기 경로, fetch-and-cache 흐름.
- `lib/storage.dart` - 네이티브 또는 웹 저장 동작을 선택하는 조건부 export.
- `lib/storage_io.dart` - 네이티브 플랫폼용 파일 기반 캐시 구현.
- `lib/storage_web.dart` - 파일 캐시 대신 항상 새로 fetch 하도록 만드는 웹용 저장 stub.
- `lib/platform_http_client.dart` - 플랫폼별 HTTP 클라이언트 생성을 위한 조건부 export.
- `lib/platform_http_client_io.dart` - iOS의 Cupertino, Android의 Cronet HTTP 클라이언트 구현.
- `lib/platform_http_client_web.dart` - 웹용 HTTP 클라이언트 구현.

### 에셋과 테스트

- `assets/imgs/bapu_logo.svg` - 사이드바에 들어간 로고 이미지.
- `assets/fonts/` - Pretendard 폰트 파일과 번들된 라이선스 텍스트.
- `test/widget_test.dart` - 테스트(테스트로써 기능은 거의 없음)
