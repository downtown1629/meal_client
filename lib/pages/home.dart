import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model.dart';
import '../meal.dart';
import '../data.dart';
import '../i18n.dart';
import '../api_v2.dart';
import '../string.dart' as string;
import 'home_drawer.dart';

class _MealOfDaySwitchButton extends StatelessWidget {
  const _MealOfDaySwitchButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  final void Function()? onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      label: SizedBox(
        width: 64,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
      icon: Icon(icon),
      style: TextButton.styleFrom(
        iconColor: colorScheme.onPrimaryContainer,
        backgroundColor: colorScheme.primaryContainer,
        overlayColor: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _DayOfWeekTabBar extends StatelessWidget implements PreferredSizeWidget {
  _DayOfWeekTabBar({
    super.key,
    required this.tabController,
    required this.language,
  });

  final TabController tabController;
  final Language language;

  final _preferredSize = Size.fromHeight(46.0);

  @override
  Size get preferredSize => _preferredSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final unselectedLabelColor = HSLColor.fromColor(colorScheme.onSurface)
        .withSaturation(0)
        .withLightness(theme.brightness == Brightness.light ? 0.6 : 0.4)
        .toColor();

    return PreferredSize(
      preferredSize: _preferredSize,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(128.0),
        ),
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        padding: EdgeInsets.all(4.0),
        child: TabBar(
          tabs: [
            Tab(text: string.mon.getLocalizedString(language), height: 36),
            Tab(text: string.tue.getLocalizedString(language), height: 36),
            Tab(text: string.wed.getLocalizedString(language), height: 36),
            Tab(text: string.thu.getLocalizedString(language), height: 36),
            Tab(text: string.fri.getLocalizedString(language), height: 36),
            Tab(text: string.sat.getLocalizedString(language), height: 36),
            Tab(text: string.sun.getLocalizedString(language), height: 36),
          ],
          labelColor: colorScheme.onPrimaryContainer,
          unselectedLabelColor: unselectedLabelColor,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(128),
          ),
          labelStyle: theme.textTheme.titleSmall!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          labelPadding: EdgeInsets.zero,
          // resolveWith 대신 all을 사용하여 매 빌드마다
          // 새 클로저를 생성하지 않도록 한다.
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          dividerHeight: 0,
          controller: tabController,
        ),
      ),
    );
  }
}

class _NestedPageScrollController extends PageController {
  final int pageCount;
  final List<bool> _reverseList;

  _NestedPageScrollController({
    super.initialPage,
    super.keepPage,
    super.viewportFraction,
    super.onAttach,
    super.onDetach,
    required this.pageCount,
  }) : _reverseList = List.generate(
         pageCount,
         (page) => page < initialPage ? true : false,
       );

  bool pageReversed(int page) => _reverseList[page];

  void outerScrollStart(int pageIndex) {
    _reverseList.fillRange(0, pageIndex, true);
    if (pageIndex + 1 < pageCount) {
      // fillRange의 end는 exclusive이므로 pageCount를 사용해야
      // 마지막 페이지까지 올바르게 채워진다.
      _reverseList.fillRange(pageIndex + 1, pageCount, false);
    }
    notifyListeners();
  }

  @override
  Future<void> animateToPage(
    int page, {
    required Duration duration,
    required Curve curve,
  }) {
    final currentPage = this.page!.round();
    _reverseList.fillRange(0, currentPage, false);
    if (currentPage + 1 < pageCount) {
      // fillRange의 end는 exclusive이므로 pageCount를 사용해야
      // 마지막 페이지까지 올바르게 채워진다.
      _reverseList.fillRange(currentPage + 1, pageCount, false);
    }
    notifyListeners();
    return super.animateToPage(page, duration: duration, curve: curve);
  }

  /// [outerScrollStart]로 reverse를 설정한 뒤 페이지를 전환한다.
  /// 스크롤 방향에 따라 이전 페이지의 하단/상단이 자연스럽게 보인다.
  Future<void> animateToPageFromScroll(
    int page, {
    required Duration duration,
    required Curve curve,
  }) {
    outerScrollStart(this.page!.round());
    return super.animateToPage(page, duration: duration, curve: curve);
  }
}

enum _CurrentlyScrolling { inner, outer }

class _NestedPageScrollView extends StatefulWidget {
  const _NestedPageScrollView({
    super.key,
    required this.controller,
    required this.onPageChanged,
    required this.builder,
  });

  final _NestedPageScrollController controller;
  final void Function(int page) onPageChanged;
  final Widget Function(BuildContext context, int pageIndex) builder;

  @override
  State<_NestedPageScrollView> createState() => _NestedPageScrollViewState();
}

class _NestedPageScrollViewState extends State<_NestedPageScrollView> {
  late final List<ScrollController> scrollControllers;
  Drag? drag;
  int? currentPageIndex;
  double prevPage = 0;
  _CurrentlyScrolling? currentlyScrolling;
  bool _isAnimatingPage = false;

  @override
  void initState() {
    scrollControllers = List.generate(
      widget.controller.pageCount,
      (pageIndex) => ScrollController(),
      growable: false,
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handlePointerScroll(event);
        }
      },
      child: GestureDetector(
      onVerticalDragStart: (details) {
        final mediaQuery = MediaQuery.of(context);
        if (details.globalPosition.dy >=
            mediaQuery.size.height - mediaQuery.padding.bottom) {
          return;
        }

        currentPageIndex = widget.controller.page!.round();

        final scrollController = scrollControllers[currentPageIndex!];
        final ScrollController currentController;
        if (scrollController.position.atEdge) {
          currentlyScrolling = _CurrentlyScrolling.outer;
          currentController = widget.controller;

          widget.controller.outerScrollStart(currentPageIndex!);
          for (var c in scrollControllers) {
            if (c != scrollController && c.hasClients) {
              c.jumpTo(0);
            }
          }
        } else {
          currentlyScrolling = _CurrentlyScrolling.inner;
          currentController = scrollController;
        }

        drag = currentController.position.drag(details, () {});
        prevPage = widget.controller.page!;
      },
      onVerticalDragUpdate: (details) {
        if (drag == null) {
          return;
        }

        final scrollController = scrollControllers[currentPageIndex!];

        final double startScrollExtent;
        final double endScrollExtent;
        if (widget.controller.pageReversed(currentPageIndex!)) {
          startScrollExtent = scrollController.position.maxScrollExtent;
          endScrollExtent = scrollController.position.minScrollExtent;
        } else {
          startScrollExtent = scrollController.position.minScrollExtent;
          endScrollExtent = scrollController.position.maxScrollExtent;
        }

        final currentPage = widget.controller.page!;
        final middlePage = ((currentPage + prevPage) / 2).round();

        if (currentlyScrolling == _CurrentlyScrolling.outer &&
            startScrollExtent != endScrollExtent &&
            ((scrollController.position.pixels == startScrollExtent &&
                    details.delta.direction < 0) ||
                (scrollController.position.pixels == endScrollExtent &&
                    details.delta.direction > 0)) &&
            ((prevPage <= middlePage && middlePage <= currentPage) ||
                (currentPage <= middlePage && middlePage <= prevPage))) {
          drag?.cancel();

          currentlyScrolling = _CurrentlyScrolling.inner;
          drag = scrollController.position.drag(
            DragStartDetails(
              globalPosition: details.globalPosition,
              localPosition: details.localPosition,
            ),
            () {},
          );
        }

        drag?.update(details);
        prevPage = currentPage;
      },
      onVerticalDragEnd: (details) {
        drag?.end(details);
        drag = null;
        currentPageIndex = null;
        currentlyScrolling = null;
      },
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: widget.controller.pageCount,
        controller: widget.controller,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: widget.onPageChanged,
        itemBuilder: (BuildContext context, int pageIndex) {
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.vertical,
              controller: scrollControllers[pageIndex],
              reverse: widget.controller.pageReversed(pageIndex),
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: widget.builder(context, pageIndex),
                ),
              ),
            ),
          );
        },
      ),
    ),
    );
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    final dy = event.scrollDelta.dy;
    if (dy == 0 || _isAnimatingPage) return;

    final pageIndex = widget.controller.page!.round();
    final sc = scrollControllers[pageIndex];
    final reversed = widget.controller.pageReversed(pageIndex);

    final double scrollableRemaining;
    if (dy > 0) {
      // 아래로 스크롤
      scrollableRemaining = reversed
          ? sc.position.pixels - sc.position.minScrollExtent
          : sc.position.maxScrollExtent - sc.position.pixels;
    } else {
      // 위로 스크롤
      scrollableRemaining = reversed
          ? sc.position.maxScrollExtent - sc.position.pixels
          : sc.position.pixels - sc.position.minScrollExtent;
    }

    if (scrollableRemaining > 0) {
      // 내부 스크롤 여유 있음
      final clampedDy = dy.clamp(-scrollableRemaining, scrollableRemaining);
      sc.jumpTo(sc.offset + (reversed ? -clampedDy : clampedDy));
    } else {
      // 내부 끝 → 페이지(끼니) 전환
      final int targetPage;
      if (dy > 0 && pageIndex < widget.controller.pageCount - 1) {
        targetPage = pageIndex + 1;
      } else if (dy < 0 && pageIndex > 0) {
        targetPage = pageIndex - 1;
      } else {
        return;
      }
      // 터치 드래그와 동일하게 다른 페이지의 내부 스크롤을 리셋
      for (var c in scrollControllers) {
        if (c != sc && c.hasClients) {
          c.jumpTo(0);
        }
      }
      _isAnimatingPage = true;
      widget.controller
          .animateToPageFromScroll(
            targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) => _isAnimatingPage = false);
    }
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({super.key, required this.title, required this.meal});

  final String title;
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // primaryContainer의 HSL 변환을 한 번만 수행하여 중복 계산 방지
    final primaryHsl = HSLColor.fromColor(theme.colorScheme.primaryContainer);
    final isLight = theme.brightness == Brightness.light;

    return Card.filled(
      color: theme.colorScheme.surfaceContainer,
      margin: EdgeInsetsGeometry.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Flex(
        direction: Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ColoredBox(
            color: primaryHsl
                .withSaturation(0.5)
                .withLightness(isLight ? 0.94 : 0.06)
                .toColor(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Center(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall!.copyWith(
                    color: primaryHsl
                        .withSaturation(0.8)
                        .withLightness(isLight ? 0.3 : 0.7)
                        .toColor(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(meal.menu.length * 2 - 1, (index) {
            if (index.isEven) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  meal.menu[index ~/ 2],
                  style: theme.textTheme.bodyMedium!.copyWith(height: 1.1),
                ),
              );
            } else {
              return Text(
                "",
                style: theme.textTheme.bodyMedium!.copyWith(height: 0.6),
              );
            }
          }, growable: false),
          const SizedBox(height: 8),
          Flexible(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: meal.kcal == null
                    ? const SizedBox()
                    : Text(
                        "${meal.kcal} kcal",
                        style: theme.textTheme.labelMedium!.copyWith(
                            fontSize: 11.5, letterSpacing: 0.1),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NestedPageScrollControllerGroup extends ChangeNotifier {
  late final List<_NestedPageScrollController> _controllers;
  int _page;

  _NestedPageScrollControllerGroup({
    required int count,
    required int pageCount,
    int initialPage = 0,
  }) : _page = initialPage {
    _controllers = List.generate(count, (index) {
      final controller = _NestedPageScrollController(
        initialPage: initialPage,
        onAttach: (position) {
          _controllers[index].jumpToPage(_page);
        },
        pageCount: pageCount,
      );

      // 매 스크롤 픽셀마다 호출되지만, 실제로 rounded 값이
      // 바뀔 때만 대입하여 불필요한 연산을 줄인다.
      controller.addListener(() {
        final rounded = controller.page!.round();
        if (_page != rounded) {
          _page = rounded;
        }
      });

      return controller;
    }, growable: false);
  }

  _NestedPageScrollController getController(int index) => _controllers[index];

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> animateToPage(
    int page, {
    required Duration duration,
    required Cubic curve,
    // 현재 화면에 보이는 탭의 인덱스.
    // 이 탭의 컨트롤러만 애니메이션으로 이동하고,
    // 나머지 비활성 탭은 jumpToPage로 즉시 동기화하여
    // 불필요한 애니메이션 ticker 생성을 방지한다.
    int? activeIndex,
  }) async {
    final futures = <Future<void>>[];

    for (int i = 0; i < _controllers.length; i++) {
      final controller = _controllers[i];
      if (!controller.hasClients) continue;

      if (activeIndex == null || i == activeIndex) {
        // 현재 보이는 탭의 애니메이션 완료 시점을 기다린다.
        futures.add(
          controller.animateToPage(page, duration: duration, curve: curve),
        );
      } else {
        // 비활성 탭: 화면에 보이지 않으므로 즉시 이동 (ticker 낭비 없음)
        controller.jumpToPage(page);
      }
    }

    if (futures.isEmpty) {
      return;
    }

    await Future.wait(futures);
  }
}

const _cardMinWidth = 160;
const _cardMaxWidth = 196;

class _WeekMealTabBarView extends StatelessWidget {
  const _WeekMealTabBarView({
    super.key,
    required this.weekMeal,
    required this.tabController,
    required this.pageControllerGroup,
    required this.pageCount,
    required this.onPageChanged,
    required this.language,
  });

  final WeekMeal weekMeal;
  final TabController tabController;
  final _NestedPageScrollControllerGroup pageControllerGroup;
  final int pageCount;
  final void Function(int) onPageChanged;
  final Language language;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: List.generate(
        tabController.length,
        (tabIndex) => _NestedPageScrollView(
          controller: pageControllerGroup.getController(tabIndex),
          onPageChanged: onPageChanged,
          builder: (context, pageIndex) {
            final nowMeal = weekMeal
                .fromDayOfWeek(DayOfWeek.values[tabIndex])
                .fromMealOfDay(MealOfDay.values[pageIndex]);
            return SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [nowMeal.dormitory, nowMeal.student, nowMeal.faculty]
                      .map<Iterable<Widget>>(
                        (meals) => meals.map((meal) {
                          var title = "";

                          if (meals == nowMeal.dormitory) {
                            title = string.dormitoryCafeteria
                                .getLocalizedString(language);

                            // 한식, 할랄 표기는 기숙사 식당에 한정하여 표기한다.
                            switch (meal) {
                              case KoreanMeal _:
                                title +=
                                " ${string.menuKorean.getLocalizedString(language)}";
                              case HalalMeal _:
                                title +=
                                " ${string.menuHalal.getLocalizedString(language)}";
                            }
                          } else if (meals == nowMeal.student) {
                            title = string.studentCafeteria.getLocalizedString(
                              language,
                            );
                          } else if (meals == nowMeal.faculty) {
                            title = string.diningHall.getLocalizedString(
                              language,
                            );
                          }



                          return GestureDetector(
                            onLongPress: () {
                              SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      "[$title]\n${meal.menu.map((aMenu) => "- $aMenu").join("\n")}${meal.kcal == null ? "" : "\n\n${meal.kcal} kcal"}",
                                ),
                              );
                            },
                            child: _MealCard(title: title, meal: meal),
                          );
                        }),
                      )
                      .expand((e) => e)
                      .toList(growable: true);

                  if (cards.isEmpty) {
                    return Center(
                      child: Text(
                        string.noMeal.getLocalizedString(language),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }

                  final double cardWidth;
                  final int columns;
                  final int leftFill;
                  {
                    var divided = (constraints.maxWidth / _cardMaxWidth)
                        .toInt();
                    if (divided < 2) {
                      final halfCardWidth = constraints.maxWidth / 2;
                      if (halfCardWidth > _cardMinWidth) {
                        divided = 2;
                        cardWidth = halfCardWidth;
                      } else {
                        cardWidth = _cardMaxWidth.toDouble();
                      }
                    } else {
                      cardWidth = _cardMaxWidth.toDouble();
                    }

                    if (cards.length <= divided) {
                      columns = cards.length;
                      leftFill = 0;
                    } else {
                      columns = divided;
                      leftFill = (columns - (cards.length / columns).toInt());
                    }
                  }
                  for (var i = 0; i < leftFill; i++) {
                    cards.add(const SizedBox());
                  }

                  final rows = (cards.length / columns).toInt();
                  final row = <TableRow>[];
                  for (var i = 0; i < rows; i++) {
                    final end = (i + 1) * columns;
                    row.add(
                      TableRow(
                        children: [
                          TableCell(child: SizedBox()),
                          ...cards
                              .sublist(
                                i * columns,
                                end < cards.length ? end : cards.length,
                              )
                              .map((card) => TableCell(child: card)),
                          TableCell(child: SizedBox()),
                        ],
                      ),
                    );
                  }
                  final remain = cards
                      .sublist(columns * rows)
                      .map((card) => TableCell(child: card))
                      .toList();
                  if (remain.isNotEmpty) {
                    remain.insert(0, TableCell(child: SizedBox()));
                    remain.add(TableCell(child: SizedBox()));
                    row.add(TableRow(children: remain));
                  }

                  return Table(
                    border: const TableBorder(),
                    defaultColumnWidth: FixedColumnWidth(cardWidth),
                    columnWidths: {
                      0: FlexColumnWidth(),
                      columns + 1: FlexColumnWidth(),
                    },
                    defaultVerticalAlignment:
                        TableCellVerticalAlignment.intrinsicHeight,
                    children: row,
                  );
                },
              ),
            );
          },
        ),
        growable: false,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final HomePageModel _model;
  late final DateTime _mondayOfWeek;
  late final TabController _tabController;
  late final _NestedPageScrollControllerGroup _mealOfDayPageControllerGroup;

  late final Future<WeekMeal> cachedMeal;
  late final Future<WeekMeal> downloadedMeal;

  // 버튼으로 시작한 식사 전환 동안에는 상단 버튼 상태를 유지하고,
  // 중간 onPageChanged가 버튼 상태를 다시 덮어쓰지 않게 한다.
  bool _isMealOfDayButtonTransition = false;

  @override
  void initState() {
    final DateTime now;
    {
      final localNow = DateTime.now();
      now = localNow.toUtc().add(Duration(hours: 9));
    }

    final MealOfDay mealOfDay;
    if (now.hour < 9 || (now.hour == 9 && now.minute <= 20)) {
      mealOfDay = MealOfDay.breakfast;
    } else if (now.hour < 13 || (now.hour == 13 && now.minute <= 30)) {
      mealOfDay = MealOfDay.lunch;
    } else {
      mealOfDay = MealOfDay.dinner;
    }

    _model = HomePageModel(
      mealOfDay: mealOfDay,
      dayOfWeek: DayOfWeek.values[now.weekday - 1],
    );

    _mondayOfWeek = now.subtract(Duration(days: now.weekday - 1));

    _tabController = TabController(
      length: DayOfWeek.values.length,
      vsync: this,
    );
    _tabController.index = _model.dayOfWeek.index;
    _tabController.addListener(
      () {
        final nextDayOfWeek = DayOfWeek.values[_tabController.index];
        if (_model.dayOfWeek == nextDayOfWeek) {
          return;
        }

        setState(() {
          _model.dayOfWeek = nextDayOfWeek;
        });
      },
    );

    _mealOfDayPageControllerGroup = _NestedPageScrollControllerGroup(
      count: DayOfWeek.values.length,
      pageCount: MealOfDay.values.length,
      initialPage: _model.mealOfDay.index,
    );

    cachedMeal = getCachedMealData();
    downloadedMeal = cachedMeal.then(
      (cache) => fetchAndCacheMealData(),
      onError: (e) => fetchAndCacheMealData(),
    );

    fetchRawAnnouncement().then((rawAnnouncement) async {
      const key = "announceTime";
      try {
        final announcement = parseRawAnnouncement(rawAnnouncement);
        final sharedPreferences = await SharedPreferences.getInstance();
        final prevAnnouncement = sharedPreferences.getString(key);
        if (announcement != prevAnnouncement) {
          sharedPreferences.setString(key, announcement);
          SchedulerBinding.instance.addPostFrameCallback((duration) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return Consumer<BapUModel>(
                  builder: (context, bapu, child) => HomeAnnouncementDialog(
                    close: string.close.getLocalizedString(bapu.language),
                    title: string.announcement.getLocalizedString(
                      bapu.language,
                    ),
                    content: announcement,
                  ),
                );
              },
            );
          });
        }
      } catch (_) {
        // ignore
      }
    });

    rootBundle
        .loadString("assets/fonts/Pretendard-License.txt")
        .then(
          (fontLicense) => LicenseRegistry.addLicense(
            () => Stream<LicenseEntry>.value(
              LicenseEntryWithLineBreaks(["Pretendard"], fontLicense),
            ),
          ),
        );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BapUModel>(
      builder: (context, bapu, child) {
        final String dayOfMealLabel;
        final IconData dayOfMealIcon;
        switch (_model.mealOfDay) {
          case MealOfDay.breakfast:
            dayOfMealLabel = string.breakfast.getLocalizedString(bapu.language);
            dayOfMealIcon = Icons.sunny;
          case MealOfDay.lunch:
            dayOfMealLabel = string.lunch.getLocalizedString(bapu.language);
            dayOfMealIcon = Icons.restaurant;
          case MealOfDay.dinner:
            dayOfMealLabel = string.dinner.getLocalizedString(bapu.language);
            dayOfMealIcon = Icons.nightlight;
        }

        final theDay = _mondayOfWeek.add(
          Duration(days: _model.dayOfWeek.index),
        );

        final dayOfWeekTabBar = _DayOfWeekTabBar(
          tabController: _tabController,
          language: bapu.language,
        );
        final PreferredSizeWidget? bottom;
        final Widget? flexibleSpace;
        if (MediaQuery.of(context).size.width >= 840) {
          flexibleSpace = SafeArea(
            child: Center(child: SizedBox(width: 420, child: dayOfWeekTabBar)),
          );
          bottom = null;
        } else {
          bottom = dayOfWeekTabBar;
          flexibleSpace = null;
        }

        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          drawer: const HomePageDrawer(),
          appBar: AppBar(
            titleSpacing: 0,
            centerTitle: false,
            title: Text(
              string.getLocalizedDate(theDay.month, theDay.day, bapu.language),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              _MealOfDaySwitchButton(
                onPressed: () async {
                  final nextMeal = nextMealOfDay(_model.mealOfDay);

                  setState(() {
                    // 버튼은 누르자마자 다음 식사 상태로 바꿔 즉각적인 반응을 준다.
                    _model.mealOfDay = nextMeal;
                    _isMealOfDayButtonTransition = true;
                  });

                  try {
                    await _mealOfDayPageControllerGroup.animateToPage(
                      nextMeal.index,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.ease,
                      // 현재 선택된 요일 탭만 애니메이션 처리
                      activeIndex: _model.dayOfWeek.index,
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        // 애니메이션이 끝나면 중간 페이지 무시 상태만 해제한다.
                        _isMealOfDayButtonTransition = false;
                      });
                    } else {
                      _isMealOfDayButtonTransition = false;
                    }
                  }
                },
                label: dayOfMealLabel,
                icon: dayOfMealIcon,
              ),
            ],
            actionsPadding: EdgeInsets.only(right: 8),
            backgroundColor: colorScheme.surface,
            scrolledUnderElevation: 0,
            bottom: bottom,
            flexibleSpace: flexibleSpace,
          ),
          body: child,
        );
      },
      child: FutureBuilder(
        future: cachedMeal,
        builder: (context, cacheSnapshot) {
          final theme = Theme.of(context);

          if (cacheSnapshot.hasData || cacheSnapshot.hasError) {
            return FutureBuilder(
              future: downloadedMeal,
              builder: (context, downloadSnapshot) {
                if (downloadSnapshot.hasData || cacheSnapshot.hasData) {
                  return Consumer<BapUModel>(
                    builder: (context, bapu, child) => _WeekMealTabBarView(
                      pageCount: MealOfDay.values.length,
                      weekMeal: downloadSnapshot.hasData
                          ? downloadSnapshot.data!
                          : cacheSnapshot.data!,
                      tabController: _tabController,
                      pageControllerGroup: _mealOfDayPageControllerGroup,
                      onPageChanged: (page) {
                        if (_isMealOfDayButtonTransition) {
                          // 버튼으로 시작한 전환 중에는 중간 페이지(예: 점심)를
                          // 상단 버튼 상태에 반영하지 않는다.
                          return;
                        }

                        final nextMealOfDay = MealOfDay.values[page];
                        if (_model.mealOfDay == nextMealOfDay) {
                          return;
                        }

                        // 수동 스와이프 전환은 기존처럼 즉시 버튼 상태에 반영한다.
                        setState(() {
                          _model.mealOfDay = nextMealOfDay;
                        });
                      },
                      language: bapu.language,
                    ),
                  );
                } else if (!cacheSnapshot.hasError ||
                    !downloadSnapshot.hasError) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primaryContainer,
                    ),
                  );
                } else {
                  return Center(
                    child: Consumer<BapUModel>(
                      builder: (context, bapu, child) => Text(
                        string.cannotLoadMeal.getLocalizedString(bapu.language),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  );
                }
              },
            );
          } else {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            );
          }
        },
      ),
    );
  }
}
