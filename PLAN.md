# i18n/l10n 현황 분석 및 마이그레이션 계획

## 1. 현재 상태 분석

### 1-1. 아키텍처

현재 앱은 **자체 구현한 수동 로컬라이제이션 시스템**을 사용한다.

```
lib/i18n.dart       → Language enum + MultiLanguageString 클래스 정의
lib/string.dart     → 모든 UI 문자열을 MultiLanguageString const로 선언 (~35개)
lib/model.dart      → BapUModel.language로 현재 언어 상태 관리 (Provider)
```

**문자열 사용 패턴:**
```dart
// 호출부 (home.dart, home_drawer.dart 등)
final language = Provider.of<BapUModel>(context).language;
string.breakfast.getLocalizedString(language)   // → "아침" 또는 "Breakfast"
```

### 1-2. 지원 언어

`enum Language { eng, kor }` — 영어, 한국어 2개

### 1-3. 문자열 목록 (string.dart)

| 카테고리 | 키 | 영어 | 한국어 |
|---------|-----|------|--------|
| 앱 제목 | title | BapU | 밥먹어U |
| 공통 UI | close, announcement, operationhours, contactdeveloper, language | ✓ | ✓ |
| 요일 | mon~sun (7개) | Mon~Sun | 월~일 |
| 끼니 | breakfast, lunch, dinner | ✓ | ✓ |
| 식당 | dormitoryCafeteria, studentCafeteria, diningHall | ✓ | ✓ |
| 메뉴 종류 | menuKorean, menuHalal | ✓ | ✓ |
| 에러 | cannotLoadMeal, noMeal | ✓ | ✓ |
| 운영시간 | operationhourscontent | ✓ | ✓ |
| 날짜 | _jan~_dec (12개) + getLocalizedDate() | ✓ | ✓ |

총 약 **35개** 문자열 + 1개 날짜 포맷 함수

### 1-4. 발견된 문제점

1. **시스템 로캘 감지 비활성화**: `main.dart:21`에서 자동 감지 코드가 주석 처리되어 항상 한국어로 고정됨
   ```dart
   if ( /* platformDispatcher.locale.languageCode == "ko" */ true) {
   ```

2. **Flutter 로컬라이제이션 미통합**: `MaterialApp`에 `localizationsDelegates`, `supportedLocales` 미설정 → Material 위젯(DatePicker, TimePicker 등)이 항상 영어로 표시

3. **언어 선택 비저장**: 사용자 언어 변경 시 `SharedPreferences`에 저장하지 않아 앱 재시작 시 초기화

4. **확장성 부재**: 새 언어 추가 시 `MultiLanguageString` 클래스와 모든 문자열 상수를 수정해야 함

5. **날짜 포맷팅 수동 구현**: `string.dart:57~94`에서 월 이름을 switch-case로 직접 처리 (intl의 `DateFormat` 미사용)

6. **API 파싱에 한국어 하드코딩**: `api_v2.dart`에서 `"기숙사 식당"`, `"학생 식당"`, `"교직원 식당"` 문자열로 파싱 (이건 서버 응답 파싱이므로 로컬라이제이션 대상이 아님)

7. **복수형/성별 등 고급 ICU 기능 미지원**

---

## 2. 마이그레이션 방안 비교

### 방안 A: flutter_localizations + intl (Flutter 공식)

Flutter SDK에 내장된 공식 로컬라이제이션 시스템. `.arb` 파일에서 코드를 자동 생성한다.

**장점:**
- Flutter 공식 지원, Material/Cupertino 위젯 로컬라이제이션 자동 통합
- ICU MessageFormat 지원 (복수형, 성별, select 등)
- `intl` 패키지의 `DateFormat`, `NumberFormat` 활용 가능
- IDE 지원 우수 (자동 완성, 타입 안전)
- 빌드 타임 코드 생성으로 런타임 오류 방지

**단점:**
- 초기 설정이 다소 복잡 (l10n.yaml, .arb 파일, pubspec generate 설정)
- .arb 파일 포맷이 직관적이지 않을 수 있음

**필요 패키지:**
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any  # flutter_localizations가 버전 결정

flutter:
  generate: true
```

### 방안 B: easy_localization

커뮤니티 패키지. JSON/YAML/CSV 등 다양한 포맷의 번역 파일을 지원한다.

**장점:**
- 설정이 간단, JSON 파일 기반으로 직관적
- 핫 리로드 시 번역 즉시 반영
- `context.tr()` 확장 메서드로 간결한 호출
- 다양한 번역 파일 포맷 지원

**단점:**
- 서드파티 의존성 (유지보수 리스크)
- Material/Cupertino 위젯 로컬라이제이션은 별도로 flutter_localizations 추가 필요
- 타입 안전성이 공식 방식보다 낮음 (문자열 키 기반)
- 런타임에 번역 파일 로드 → 빌드 타임 검증 불가

### 추천: 방안 A (flutter_localizations + intl)

이유:
- 현재 앱의 문자열 수가 ~35개로 적어 .arb 파일 관리 부담이 낮음
- Material 위젯 로컬라이제이션이 자동으로 해결됨
- 날짜 포맷팅을 `intl`의 `DateFormat`으로 대체하여 `getLocalizedDate()` 수동 구현 제거 가능
- 장기적으로 Flutter 공식 지원의 안정성이 높음

---

## 3. 마이그레이션 계획 (방안 A: flutter_localizations + intl)

### Step 1: 프로젝트 설정

**pubspec.yaml 수정:**
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

**l10n.yaml 생성 (프로젝트 루트):**
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

### Step 2: ARB 파일 생성

**lib/l10n/app_en.arb:**
```json
{
  "@@locale": "en",
  "title": "BapU",
  "close": "Close",
  "announcement": "Announcement",
  "operationHours": "Operation Hours",
  "contactDeveloper": "Contact Developer",
  "language": "Language / 언어",
  "mon": "Mon",
  "tue": "Tue",
  "wed": "Wed",
  "thu": "Thu",
  "fri": "Fri",
  "sat": "Sat",
  "sun": "Sun",
  "breakfast": "Breakfast",
  "lunch": "Lunch",
  "dinner": "Dinner",
  "cannotLoadMeal": "Cannot load meal information.",
  "noMeal": "There's no meal information.",
  "dormitoryCafeteria": "Dormitory",
  "studentCafeteria": "Student",
  "diningHall": "Dining Hall",
  "menuKorean": "Korean",
  "menuHalal": "Halal",
  "operationHoursContent": "Dormitory\n Breakfast 08:00 ~ 09:20\n Lunch 11:30 ~ 13:30\n Dinner 17:30 ~ 19:00\n\nStudent\n Lunch 11:00 ~ 13:30\n Dinner 17:00 ~ 19:00\n\nFaculty\n Lunch 11:30 ~ 13:30\n Dinner 17:30 ~ 19:30",
  "localizedDate": "{month} {day}",
  "@localizedDate": {
    "placeholders": {
      "month": { "type": "String" },
      "day": { "type": "int" }
    }
  }
}
```

**lib/l10n/app_ko.arb:**
```json
{
  "@@locale": "ko",
  "title": "밥먹어U",
  "close": "닫기",
  "announcement": "공지사항",
  "operationHours": "운영 시간",
  "contactDeveloper": "개발자에게 문의하기",
  "language": "언어 / Language",
  "mon": "월",
  "tue": "화",
  "wed": "수",
  "thu": "목",
  "fri": "금",
  "sat": "토",
  "sun": "일",
  "breakfast": "아침",
  "lunch": "점심",
  "dinner": "저녁",
  "cannotLoadMeal": "식단 정보를 불러올 수 없어요.",
  "noMeal": "식단 정보가 없어요.",
  "dormitoryCafeteria": "기숙사 식당",
  "studentCafeteria": "학생 식당",
  "diningHall": "교직원 식당",
  "menuKorean": "한식",
  "menuHalal": "할랄",
  "operationHoursContent": "기숙사식당\n 아침 08:00 ~ 09:20\n 점심 11:30 ~ 13:30\n 저녁 17:30 ~ 19:00\n\n학생식당\n 점심 11:00 ~ 13:30\n 저녁 17:00 ~ 19:00\n\n교직원식당\n 점심 11:30 ~ 13:30\n 저녁 17:30 ~ 19:30",
  "localizedDate": "{month}월 {day}일",
  "@localizedDate": {
    "placeholders": {
      "month": { "type": "String" },
      "day": { "type": "int" }
    }
  }
}
```

### Step 3: MaterialApp 설정 변경

**lib/main.dart 수정:**
```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// ...

MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: bapu.locale,  // Locale 객체로 변경
  // ...
)
```

### Step 4: 모델 변경

**lib/model.dart:**
- `Language` enum 대신 `Locale` 객체 사용하도록 변경
- 또는 `Language` enum에 `Locale` 변환 getter 추가

```dart
class BapUModel extends ChangeNotifier {
  Locale _locale;

  Locale get locale => _locale;

  void changeLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}
```

### Step 5: UI 호출부 일괄 변경

**Before (현재):**
```dart
final language = Provider.of<BapUModel>(context).language;
Text(string.breakfast.getLocalizedString(language))
```

**After (마이그레이션 후):**
```dart
final l10n = AppLocalizations.of(context);
Text(l10n.breakfast)
```

변경 대상 파일:
- `lib/pages/home.dart` — ~20곳
- `lib/pages/home_drawer.dart` — ~10곳

### Step 6: 날짜 포맷팅 교체

**Before:**
```dart
// string.dart의 수동 switch-case (57~94줄)
string.getLocalizedDate(theDay.month, theDay.day, bapu.language)
```

**After:**
```dart
import 'package:intl/intl.dart';

// intl의 DateFormat 사용
DateFormat.MMMd(Localizations.localeOf(context).toString()).format(theDay)
// en → "Mar 9",  ko → "3월 9일"
```

### Step 7: 레거시 파일 정리

마이그레이션 완료 후 삭제할 파일:
- `lib/i18n.dart` — `Language` enum, `MultiLanguageString` 클래스
- `lib/string.dart` — 모든 수동 문자열 상수

`BapUModel`에서 `Language` 관련 코드를 `Locale` 기반으로 교체한다.

### Step 8: 시스템 로캘 자동 감지 활성화

`main.dart`의 주석 처리된 로캘 감지 코드를 제거하고,
`MaterialApp`의 `locale` 파라미터와 `supportedLocales`가 자동으로 처리하도록 한다.
사용자가 수동으로 언어를 변경한 경우 `SharedPreferences`에 저장한다.

---

## 4. 파일별 변경 요약

| 파일 | 작업 |
|------|------|
| `pubspec.yaml` | flutter_localizations, intl 의존성 추가, `generate: true` |
| `l10n.yaml` | 신규 생성 |
| `lib/l10n/app_en.arb` | 신규 생성 (영어 번역) |
| `lib/l10n/app_ko.arb` | 신규 생성 (한국어 번역) |
| `lib/main.dart` | MaterialApp에 delegates/supportedLocales/locale 추가, 로캘 감지 복원 |
| `lib/model.dart` | Language → Locale 전환, SharedPreferences 저장 추가 |
| `lib/pages/home.dart` | `string.xxx.getLocalizedString(language)` → `AppLocalizations.of(context).xxx` (~20곳) |
| `lib/pages/home_drawer.dart` | 동일 패턴 변경 (~10곳) |
| `lib/i18n.dart` | 삭제 |
| `lib/string.dart` | 삭제 |

---

## 5. 마이그레이션 순서 (안전한 점진적 전환)

위 단계를 한 번에 적용하면 대규모 변경이 되므로, 아래 순서로 점진적 전환을 권장한다:

1. **Phase 1** — 인프라 설정 (Step 1~2): 패키지 추가 + ARB 파일 생성 + 코드 생성 확인
2. **Phase 2** — MaterialApp 통합 (Step 3): delegates 추가, 기존 코드와 병존 가능
3. **Phase 3** — 모델 전환 (Step 4): Language → Locale 전환
4. **Phase 4** — UI 호출부 변경 (Step 5~6): 파일별로 하나씩 변경, 각 파일 변경 후 테스트
5. **Phase 5** — 정리 (Step 7~8): 레거시 파일 삭제, 로캘 자동 감지 활성화
