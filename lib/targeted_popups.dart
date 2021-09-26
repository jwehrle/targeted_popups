library targeted_popups;

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:animated_widgets/animated_widgets.dart';

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
  final Widget content;
  final bool wiggle;
  final bool check;
  final Color? backgroundColor;
  final Duration period;
  final ValueNotifier<bool> notifier;
  final Widget target;

  const TargetedPopup({
    Key? key,
    required this.content,
    this.wiggle = true,
    this.check = false,
    this.backgroundColor,
    this.period = const Duration(milliseconds: 1000),
    required this.notifier,
    required this.target,
  }) : super(key: key);

  @override
  TargetedPopupState createState() => TargetedPopupState();
}

class TargetedPopupState extends State<TargetedPopup> {
  List<OverlayEntry> _overlayHolder = [];
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    if (widget.notifier.value) {
      _showOverlay();
    }
    widget.notifier.addListener(_showOverlay);
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
    super.dispose();
  }

  void _showOverlay() {
    if (widget.notifier.value) {
      SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
        _overlayHolder.add(_createOverlayEntry());
        Overlay.of(context)!.insert(_overlayHolder.first);
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    Size screenSize = MediaQuery.of(context).size;
    EdgeInsets edgeInsets = MediaQuery.of(context).padding;
    double width = screenSize.width - (edgeInsets.right + edgeInsets.left);
    double height = screenSize.height - (edgeInsets.bottom + edgeInsets.top);
    var offset = _layerLink.leader!.offset;
    double xLoc = offset.dx;
    double yLoc = offset.dy;
    double spaceToLeft = xLoc;
    double spaceToRight = width - (xLoc + (_layerLink.leaderSize!.width));
    double spaceAbove = yLoc - kToolbarHeight;
    double spaceBelow = height - (yLoc + (_layerLink.leaderSize!.height));
    late PopupLocation location;
    late double maxWidth;
    late double maxHeight;
    if (spaceToLeft >= spaceToRight) {
      if (spaceAbove >= spaceBelow) {
        location = PopupLocation.AboveLeft;
        maxWidth = spaceToLeft + (_layerLink.leaderSize!.width / 2);
        maxHeight = spaceAbove;
      } else {
        location = PopupLocation.BelowLeft;
        maxWidth = spaceToLeft + (_layerLink.leaderSize!.width / 2);
        maxHeight = spaceBelow;
      }
    } else {
      if (spaceAbove >= spaceBelow) {
        location = PopupLocation.AboveRight;
        maxWidth = spaceToRight + (_layerLink.leaderSize!.width / 2);
        maxHeight = spaceAbove;
      } else {
        location = PopupLocation.BelowRight;
        maxWidth = spaceToRight + (_layerLink.leaderSize!.width / 2);
        maxHeight = spaceBelow;
      }
    }
    maxWidth -= 24.0;
    maxHeight -= 24.0;
    Color background = widget.backgroundColor == null
        ? Theme.of(context).accentColor
        : widget.backgroundColor!;
    return OverlayEntry(builder: (context) {
      return Positioned(
        top: 0.0,
        left: 0.0,
        child: CompositedTransformFollower(
          targetAnchor: _targetAnchor(location),
          followerAnchor: _followerAnchor(location),
          link: _layerLink,
          child: Container(
            constraints: BoxConstraints.loose(Size(maxWidth, maxHeight)),
            child: ShakeAnimatedWidget(
              enabled: widget.wiggle,
              duration: widget.period,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: _borderRadius(location),
                ),
                elevation: 12.0,
                color: background,
                child: InkWell(
                  onTap: _overlayHolder.isNotEmpty ? _onSeen : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: widget.content,
                        ),
                        if (widget.check) Icon(Icons.check),
                      ],
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

  Alignment _targetAnchor(PopupLocation location) {
    switch (location) {
      case PopupLocation.AboveLeft:
      case PopupLocation.AboveRight:
        return Alignment.topCenter;
      case PopupLocation.BelowLeft:
      case PopupLocation.BelowRight:
        return Alignment.bottomCenter;
    }
  }

  Alignment _followerAnchor(PopupLocation location) {
    switch (location) {
      case PopupLocation.AboveLeft:
        return Alignment.bottomRight;
      case PopupLocation.AboveRight:
        return Alignment.bottomLeft;
      case PopupLocation.BelowLeft:
        return Alignment.topRight;
      case PopupLocation.BelowRight:
        return Alignment.topLeft;
    }
  }

  BorderRadius _borderRadius(PopupLocation location) {
    switch (location) {
      case PopupLocation.AboveLeft:
        return BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
          bottomLeft: Radius.circular(16.0),
        );
      case PopupLocation.AboveRight:
        return BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        );
      case PopupLocation.BelowLeft:
        return BorderRadius.only(
          topLeft: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
          bottomLeft: Radius.circular(16.0),
        );
      case PopupLocation.BelowRight:
        return BorderRadius.only(
          bottomRight: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
          bottomLeft: Radius.circular(16.0),
        );
    }
  }

  void _onSeen() {
    setState(() {
      _removeDisposeEntries();
      widget.notifier.value = false;
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

  Size textSize(BuildContext context, String message) {
    return (TextPainter(
            text: TextSpan(
                text: message, style: Theme.of(context).textTheme.bodyText2),
            maxLines: 1,
            textScaleFactor: MediaQuery.of(context).textScaleFactor,
            textDirection: TextDirection.ltr)
          ..layout())
        .size;
  }
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
    String firstUnseen = ids.firstWhere((id) => !seen(id));
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

  LinkedHashMap<String, ValueNotifier<bool>> get popupMap => _popupMap;

  void nextUnseen() {
    String firstUnseen = _popupMap.keys.firstWhere((id) => !_seen(id));
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
