library targeted_popups;

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:animated_widgets/animated_widgets.dart';
import 'package:mdi/mdi.dart';

/// Location of the popup relative to its target
enum PopupLocation { AboveLeft, AboveRight, BelowLeft, BelowRight }

/// Creates an OverlayEntry near the target widget when the notifier changes
/// values from false to true.
///
/// By default he OverlayEntry will display the
/// content Widget, will have a background color of the theme accentColor, and
/// will wiggle with a period of 1000 milliseconds. Optionally, a checkmark icon
/// can be shown, the wiggle can be disabled, and the period of the wiggle can
/// be customized.
///
/// Uses the Card Widget to display content and tapping anywhere
/// on the Card will remove the OverlayEntry.
///
/// Uses MediaQuery, target size, and, target location to determine the best
/// location and size for the OverlayEntry.
///
/// Intended to work with the TargetedPopupManager (see below)
class TargetedPopup extends StatefulWidget {
  final String content;
  final bool wiggle;
  final bool arrow;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Duration period;
  final ValueNotifier<bool> notifier;
  final Widget target;

  const TargetedPopup({
    Key? key,
    required this.content,
    this.wiggle = true,
    this.arrow = true,
    this.backgroundColor,
    this.foregroundColor,
    this.period = const Duration(milliseconds: 1000),
    required this.notifier,
    required this.target,
  }) : super(key: key);

  @override
  TargetedPopupState createState() => TargetedPopupState();
}

class TargetedPopupState extends State<TargetedPopup>
    with SingleTickerProviderStateMixin {
  final List<OverlayEntry> _overlayHolder = [];
  final LayerLink _layerLink = LayerLink();
  late final AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: kThemeAnimationDuration,
      value: 0, // initially not visible
    );
    if (widget.notifier.value) {
      _showOverlay();
    }
    widget.notifier.addListener(() {
      _showOverlay();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: widget.target,
    );
  }

  @override
  dispose() {
    if (_overlayHolder.isNotEmpty) {
      _removeDisposeEntries();
    }
    _controller.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (widget.notifier.value) {
      SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
        _controller.forward();
        _overlayHolder.add(_createOverlayEntry());
        Overlay.of(context)!.insert(_overlayHolder.first);
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    var media = MediaQuery.of(context);
    Size screenSize = media.size;
    EdgeInsets edgeInsets = media.padding;
    double sw = screenSize.width - (edgeInsets.right + edgeInsets.left);
    double sh = screenSize.height - (edgeInsets.bottom + edgeInsets.top);
    Offset offset = _layerLink.leader!.offset;
    _Orientation _orientation = _Orientation(
      spaceToLeft: offset.dx,
      spaceToRight: sw - (offset.dx + (_layerLink.leaderSize!.width)),
      spaceAbove: offset.dy - kToolbarHeight,
      spaceBelow: sh - (offset.dy + (_layerLink.leaderSize!.height)),
      leaderSize: _layerLink.leaderSize!,
    );
    final ThemeData theme = Theme.of(context);
    Color background = widget.backgroundColor == null
        ? theme.accentColor
        : widget.backgroundColor!;
    final FloatingActionButtonThemeData floatingActionButtonTheme =
        theme.floatingActionButtonTheme;
    final Color foregroundColor = widget.foregroundColor ??
        floatingActionButtonTheme.foregroundColor ??
        theme.colorScheme.onSecondary;
    final TextStyle textStyle = theme.textTheme.button!.copyWith(
      color: foregroundColor,
      letterSpacing: 1.2,
    );
    return OverlayEntry(builder: (context) {
      return Positioned(
        top: 0.0,
        left: 0.0,
        child: CompositedTransformFollower(
          targetAnchor: _orientation.targetAnchor,
          followerAnchor: _orientation.followerAnchor,
          link: _layerLink,
          child: FadeScaleAnimatedWidget(
            controller: _controller,
            child: Container(
              constraints: BoxConstraints.loose(_orientation.size),
              child: ShakeAnimatedWidget(
                enabled: widget.wiggle,
                duration: widget.period,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: _orientation.borderRadius,
                  ),
                  elevation: 12.0,
                  color: background,
                  child: InkWell(
                    onTap: _overlayHolder.isNotEmpty ? _onSeen : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.arrow
                            ? _orientation.childOrder(
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    widget.content,
                                    style: textStyle,
                                  ),
                                ),
                                Icon(
                                  _orientation.iconData,
                                  color: foregroundColor,
                                ))
                            : [
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    widget.content,
                                    style: textStyle,
                                  ),
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  void _onSeen() {
    _controller.reverse().then((ticker) {
      setState(() {
        _removeDisposeEntries();
        widget.notifier.value = false;
      });
    }).catchError((e) {
      setState(() {
        _removeDisposeEntries();
        widget.notifier.value = false;
      });
    });
  }

  void _removeDisposeEntries() {
    _overlayHolder.forEach((entry) {
      if (entry.mounted) {
        entry.remove();
      }
    });
    _overlayHolder.clear();
  }
}

class FadeScaleAnimatedWidget extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const FadeScaleAnimatedWidget({
    Key? key,
    required this.controller,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: controller,
      child: ScaleTransition(
        scale: controller,
        child: child,
      ),
    );
  }
}

class _Orientation {
  final double _kPadding = 24.0;
  final Radius _kRadius = Radius.circular(16.0);

  late final PopupLocation _location;
  late final double _maxWidth;
  late final double _maxHeight;
  late final IconData _iconData;
  late final Alignment _targetAnchor;
  late final Alignment _followerAnchor;
  late final BorderRadius _borderRadius;
  late final Size _size;

  IconData get iconData => _iconData;

  _Orientation({
    required double spaceToLeft,
    required double spaceToRight,
    required double spaceAbove,
    required double spaceBelow,
    required Size leaderSize,
  }) {
    double halfLeaderWidth = leaderSize.width / 2.0;
    if (spaceToLeft >= spaceToRight) {
      _maxWidth = _width(spaceToLeft, halfLeaderWidth);
      if (spaceAbove >= spaceBelow) {
        _assignFromLocation(PopupLocation.AboveLeft, spaceAbove, spaceBelow);
      } else {
        _assignFromLocation(PopupLocation.BelowLeft, spaceAbove, spaceBelow);
      }
    } else {
      _maxWidth = _width(spaceToRight, halfLeaderWidth);
      if (spaceAbove >= spaceBelow) {
        _assignFromLocation(PopupLocation.AboveRight, spaceAbove, spaceBelow);
      } else {
        _assignFromLocation(PopupLocation.BelowRight, spaceAbove, spaceBelow);
      }
    }
    _size = Size(_maxWidth, _maxHeight);
  }

  double _width(double space, double halfLeaderWidth) =>
      space + halfLeaderWidth - _kPadding;

  void _assignFromLocation(PopupLocation loc, double above, double below) {
    _location = loc;
    switch (loc) {
      case PopupLocation.AboveLeft:
        _maxHeight = above - _kPadding;
        _iconData = Mdi.arrowBottomRight;
        _targetAnchor = Alignment.topCenter;
        _followerAnchor = Alignment.bottomRight;
        _borderRadius = BorderRadius.only(
          topLeft: _kRadius,
          topRight: _kRadius,
          bottomLeft: _kRadius,
        );
        break;
      case PopupLocation.AboveRight:
        _maxHeight = above - _kPadding;
        _iconData = Mdi.arrowBottomLeft;
        _targetAnchor = Alignment.topCenter;
        _followerAnchor = Alignment.bottomLeft;
        _borderRadius = BorderRadius.only(
          topLeft: _kRadius,
          topRight: _kRadius,
          bottomRight: _kRadius,
        );
        break;
      case PopupLocation.BelowLeft:
        _maxHeight = below - _kPadding;
        _iconData = Mdi.arrowTopRight;
        _targetAnchor = Alignment.bottomCenter;
        _followerAnchor = Alignment.topRight;
        _borderRadius = BorderRadius.only(
          topLeft: _kRadius,
          bottomRight: _kRadius,
          bottomLeft: _kRadius,
        );
        break;
      case PopupLocation.BelowRight:
        _maxHeight = below - _kPadding;
        _iconData = Mdi.arrowTopLeft;
        _targetAnchor = Alignment.bottomCenter;
        _followerAnchor = Alignment.topLeft;
        _borderRadius = BorderRadius.only(
          bottomRight: _kRadius,
          topRight: _kRadius,
          bottomLeft: _kRadius,
        );
        break;
    }
  }

  List<Widget> childOrder(Widget content, Widget arrow) {
    switch (_location) {
      case PopupLocation.AboveLeft:
      case PopupLocation.BelowLeft:
        return [
          content,
          Padding(
            padding: EdgeInsets.only(left: 16.0),
          ),
          arrow
        ];
      case PopupLocation.AboveRight:
      case PopupLocation.BelowRight:
        return [
          arrow,
          Padding(
            padding: EdgeInsets.only(left: 16.0),
          ),
          content
        ];
    }
  }

  PopupLocation get location => _location;

  Alignment get targetAnchor => _targetAnchor;

  Alignment get followerAnchor => _followerAnchor;

  BorderRadius get borderRadius => _borderRadius;

  Size get size => _size;
}

final String _kAllSeen = 'NO_KEY';

/// Manages the triggering of TargetedPopups by providing ValueNotifiers based
/// on keys such that each TargetedPopup is triggered, one by one, as the user
/// dismisses them. Optionally, a set of keys of already seen TargetedPopups
/// can be provided and the manager will skip triggering popups for these. The
/// ValueChanged callback notifies when a TargetedPopup has been dismissed and
/// provides its key.
///
/// Use getNotifier for the notifier parameter of TargetedPopup.
///
/// Must call dispose when finished.
///
/// Intended to be used with SharedPreferences or some similar tool.
class TargetedPopupManager {
  Map<String, _Page> _pageMap = {};
  Set<String> _seen = Set();
  ValueChanged<String>? onSeen;

  TargetedPopupManager({List<String>? seen, this.onSeen}) {
    if (seen != null) {
      _seen.addAll(seen);
    }
  }

  ValueNotifier<bool> notifier(String page, String id) {
    if (!_pageMap.containsKey(page)) {
      throw 'There is no page $page';
    }
    if (!_pageMap[page]!.popupMap.containsKey(id)) {
      throw 'There is no popup id $id';
    }
    return _pageMap[page]!.popupMap[id]!;
  }

  TargetedPopupManager addPage(String page, List<String> pageIds) {
    _pageMap[page] = _Page(ids: pageIds, seen: _seen.contains, onSeen: _onSeen);
    return this;
  }

  void _onSeen(String id) {
    _seen.add(id);
    if (onSeen != null) {
      onSeen!(id);
    }
  }

  void discover(String page) {
    if (_pageMap.containsKey(page)) {
      _pageMap[page]!.nextUnseen();
    }
  }

  void dispose() {
    _pageMap.values.forEach((page) => page.dispose());
  }
}

class _Page {
  final LinkedHashMap<String, ValueNotifier<bool>> _popupMap = LinkedHashMap();
  late final bool Function(String) _seen;

  _Page({
    required List<String> ids,
    required bool Function(String) seen,
    required ValueChanged<String> onSeen,
  }) {
    _seen = seen;
    String firstUnseen =
        ids.firstWhere((id) => !seen(id), orElse: () => _kAllSeen);
    if (firstUnseen != _kAllSeen) {
      ids.forEach((id) {
        _popupMap[id] = ValueNotifier<bool>(id == firstUnseen);
        _popupMap[id]!.addListener(() {
          if (!_popupMap[id]!.value) {
            onSeen(id);
            nextUnseen();
          }
        });
      });
    }
  }

  LinkedHashMap<String, ValueNotifier<bool>> get popupMap => _popupMap;

  void nextUnseen() {
    String firstUnseen =
        _popupMap.keys.firstWhere((id) => !_seen(id), orElse: () => _kAllSeen);
    if (firstUnseen != _kAllSeen) {
      _popupMap[firstUnseen]!.value = true;
    }
  }

  void dispose() {
    _popupMap.values.forEach((notifier) {
      notifier.dispose();
    });
    _popupMap.clear();
  }
}
