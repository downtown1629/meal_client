import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../i18n.dart';
import '../../meal.dart';
import '../../string.dart' as string;
import 'meal_card.dart';
import 'nested_page_scroll.dart';

const _cardMinWidth = 160;
const _cardMaxWidth = 196;

/// 실험용 physics: TabBarView Scrollable이 pointer scroll 입력을 받지 않게 한다.
///
/// 주의: shouldAcceptUserOffset를 false로 고정하면 드래그 기반 수평 스와이프도
/// 제한될 수 있으므로, 이번 변경은 원인 확인 목적의 계측 실험이다.
class _PointerScrollBlockingPhysics extends ClampingScrollPhysics {
  const _PointerScrollBlockingPhysics({super.parent});

  @override
  _PointerScrollBlockingPhysics applyTo(ScrollPhysics? ancestor) {
    return _PointerScrollBlockingPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => false;
}

class WeekMealTabBarView extends StatefulWidget {
  const WeekMealTabBarView({
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
  final NestedPageScrollControllerGroup pageControllerGroup;
  final int pageCount;
  final void Function(int) onPageChanged;
  final Language language;

  @override
  State<WeekMealTabBarView> createState() => _WeekMealTabBarViewState();
}

class _WeekMealTabBarViewState extends State<WeekMealTabBarView> {
  double _accumulatedDx = 0;
  Timer? _resetTimer;
  bool _isAnimatingTab = false;
  Timer? _animationGuardTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _animationGuardTimer?.cancel();
    super.dispose();
  }

  /// 가로 [PointerScrollEvent]를 누적하여 임계값 초과 시 탭을 전환한다.
  ///
  /// [GestureBinding.instance.pointerSignalResolver]에 먼저 등록하여
  /// [TabBarView] 내부 [Scrollable]의 PageScrollPhysics snap-back을 방지한다.
  void _handleHorizontalScroll(PointerScrollEvent event) {
    if (kDebugMode) {
      debugPrint(
        '[PTR-H/HANDLE] t=${DateTime.now().toIso8601String()} '
        'dx=${event.scrollDelta.dx.toStringAsFixed(2)} '
        'dy=${event.scrollDelta.dy.toStringAsFixed(2)} '
        'acc=${_accumulatedDx.toStringAsFixed(2)} '
        'idx=${widget.tabController.index} '
        'changing=${widget.tabController.indexIsChanging} '
        'guard=$_isAnimatingTab',
      );
    }
    if (_isAnimatingTab) return;

    _accumulatedDx += event.scrollDelta.dx;

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 200), () {
      _accumulatedDx = 0;
    });

    const threshold = 40.0;
    if (_accumulatedDx.abs() >= threshold) {
      final direction = _accumulatedDx > 0 ? 1 : -1;
      final nextIndex = widget.tabController.index + direction;

      if (kDebugMode) {
        debugPrint(
          '[PTR-H/THRESHOLD] t=${DateTime.now().toIso8601String()} '
          'acc=${_accumulatedDx.toStringAsFixed(2)} '
          'threshold=$threshold dir=$direction current=${widget.tabController.index} '
          'next=$nextIndex',
        );
      }

      if (nextIndex >= 0 && nextIndex < widget.tabController.length) {
        if (kDebugMode) {
          debugPrint(
            '[PTR-H/ANIMATE-PRE] t=${DateTime.now().toIso8601String()} '
            'index=${widget.tabController.index} '
            'prev=${widget.tabController.previousIndex} '
            'changing=${widget.tabController.indexIsChanging} '
            'anim=${widget.tabController.animation?.value.toStringAsFixed(3)} '
            'target=$nextIndex',
          );
        }
        widget.tabController.animateTo(nextIndex);
        _isAnimatingTab = true;
        if (kDebugMode) {
          debugPrint(
            '[PTR-H/ANIMATE-POST] t=${DateTime.now().toIso8601String()} '
            'index=${widget.tabController.index} '
            'prev=${widget.tabController.previousIndex} '
            'changing=${widget.tabController.indexIsChanging} '
            'anim=${widget.tabController.animation?.value.toStringAsFixed(3)} '
            'target=$nextIndex',
          );
        }
        if (kDebugMode) {
          debugPrint(
            '[PTR-H/ANIMATE] t=${DateTime.now().toIso8601String()} '
            'from=${widget.tabController.previousIndex} to=${widget.tabController.index} '
            'changing=${widget.tabController.indexIsChanging}',
          );
        }
        _animationGuardTimer?.cancel();
        _animationGuardTimer = Timer(const Duration(milliseconds: 350), () {
          _isAnimatingTab = false;

          if (kDebugMode) {
            debugPrint(
              '[PTR-H/GUARD-END] t=${DateTime.now().toIso8601String()} '
              'idx=${widget.tabController.index} '
              'changing=${widget.tabController.indexIsChanging}',
            );
          }
        });
      }

      _accumulatedDx = 0;
      _resetTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (kDebugMode) {
          final metrics = notification.metrics;
          final page = metrics is PageMetrics
              ? metrics.page?.toStringAsFixed(3) ?? 'null'
              : 'na';
          debugPrint(
            '[TAB/SCROLL] t=${DateTime.now().toIso8601String()} '
            'type=${notification.runtimeType} '
            'depth=${notification.depth} '
            'axis=${metrics.axisDirection} '
            'pixels=${metrics.pixels.toStringAsFixed(3)} '
            'page=$page '
            'idx=${widget.tabController.index} '
            'prev=${widget.tabController.previousIndex} '
            'changing=${widget.tabController.indexIsChanging} '
            'anim=${widget.tabController.animation?.value.toStringAsFixed(3)}',
          );
        }
        return false;
      },
      child: TabBarView(
        controller: widget.tabController,
        physics: const _PointerScrollBlockingPhysics(),
        children: List.generate(
        widget.tabController.length,
        (tabIndex) => Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && event.scrollDelta.dx != 0) {
              if (kDebugMode) {
                debugPrint(
                  '[PTR-H/RAW] t=${DateTime.now().toIso8601String()} '
                  'tab=$tabIndex '
                  'dx=${event.scrollDelta.dx.toStringAsFixed(2)} '
                  'dy=${event.scrollDelta.dy.toStringAsFixed(2)} '
                  'idx=${widget.tabController.index} '
                  'changing=${widget.tabController.indexIsChanging}',
                );
              }
              GestureBinding.instance.pointerSignalResolver.register(
                event,
                (event) =>
                    _handleHorizontalScroll(event as PointerScrollEvent),
              );
            }
          },
          child: NestedPageScrollView(
            controller: widget.pageControllerGroup.getController(tabIndex),
            onPageChanged: widget.onPageChanged,
            builder: (context, pageIndex) {
              final nowMeal = widget.weekMeal
                  .fromDayOfWeek(DayOfWeek.values[tabIndex])
                  .fromMealOfDay(MealOfDay.values[pageIndex]);
              return SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                          nowMeal.dormitory,
                          nowMeal.student,
                          nowMeal.faculty,
                        ]
                        .map<Iterable<Widget>>(
                          (meals) => meals.map((meal) {
                            var title = "";

                            if (meals == nowMeal.dormitory) {
                              title = string.dormitoryCafeteria
                                  .getLocalizedString(widget.language);

                              // 한식, 할랄 표기는 기숙사 식당에 한정하여 표기한다.
                              switch (meal) {
                                case KoreanMeal _:
                                  title +=
                                      " ${string.menuKorean.getLocalizedString(widget.language)}";
                                case HalalMeal _:
                                  title +=
                                      " ${string.menuHalal.getLocalizedString(widget.language)}";
                              }
                            } else if (meals == nowMeal.student) {
                              title = string.studentCafeteria
                                  .getLocalizedString(widget.language);
                            } else if (meals == nowMeal.faculty) {
                              title = string.facultyCafeteria
                                  .getLocalizedString(widget.language);
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
                              child: MealCard(title: title, meal: meal),
                            );
                          }),
                        )
                        .expand((e) => e)
                        .toList(growable: true);

                    if (cards.isEmpty) {
                      return Center(
                        child: Text(
                          string.noMeal
                              .getLocalizedString(widget.language),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      );
                    }

                    final double cardWidth;
                    final int columns;
                    final int leftFill;
                    {
                      var divided =
                          (constraints.maxWidth / _cardMaxWidth).toInt();
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
                        leftFill =
                            (columns - (cards.length / columns).toInt());
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
        ),
        growable: false,
        ),
      ),
    );
  }
}
