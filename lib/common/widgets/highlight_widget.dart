import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/app/app_focus_node.dart';

typedef FocusOnKeyDownCallback = KeyEventResult Function();

class HighlightWidget extends StatefulWidget {
  final AppFocusNode focusNode;
  final Widget child;
  final FocusOnKeyDownCallback? onUpKey;
  final FocusOnKeyDownCallback? onDownKey;
  final FocusOnKeyDownCallback? onLeftKey;
  final FocusOnKeyDownCallback? onRightKey;
  final Function(bool)? onFocusChange;
  final Function()? onTap;
  final Function()? onLongTap;
  final Color foucsedColor;
  final Color color;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final double order;
  final bool selected;
  final bool useOtherController;
  final bool useFocus;
  const HighlightWidget({
    required this.focusNode,
    required this.child,
    this.onUpKey,
    this.onDownKey,
    this.onLeftKey,
    this.onRightKey,
    this.onFocusChange,
    this.onTap,
    this.onLongTap,
    this.useOtherController = false,
    this.autofocus = false,
    this.selected = false,
    this.borderRadius,
    this.order = 0.0,
    this.color = Colors.transparent,
    this.foucsedColor = Colors.white,
    this.useFocus = true,
    super.key,
  });

  @override
  State<HighlightWidget> createState() => _HighlightWidgetState();
}

class _HighlightWidgetState extends State<HighlightWidget> {
  late final SettingsService _settings;
  late Color _themeColor;
  int _currentTimeStamp = 0;
  int _eventDirection = 0;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsService>();
    _themeColor = HexColor(_settings.themeColorSwitch.value);
    _settings.themeColorSwitch.listen((value) {
      if (mounted) {
        setState(() {
          _themeColor = HexColor(value);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.useFocus
        ? FocusTraversalOrder(
            order: NumericFocusOrder(widget.order),
            child: Focus(
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              onFocusChange: widget.onFocusChange,
              onKeyEvent: _handleKeyEvent,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Obx(
                  () => AnimatedScale(
                    scale: widget.focusNode.isFoucsed.value ? 1.00 : 0.98,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius,
                        boxShadow: widget.focusNode.isFoucsed.value
                            ? [BoxShadow(blurRadius: 3.w, spreadRadius: 1.w, color: _themeColor)]
                            : null,
                        color: (widget.focusNode.isFoucsed.value || widget.selected)
                            ? widget.foucsedColor
                            : widget.color,
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          )
        : GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: widget.selected ? 1.00 : 0.98,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  boxShadow: widget.selected
                      ? [BoxShadow(blurRadius: 3.w, spreadRadius: 1.w, color: _themeColor)]
                      : null,
                  color: widget.selected ? widget.foucsedColor : widget.color,
                ),
                child: widget.child,
              ),
            ),
          );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) {
      if (_eventDirection == 0) return KeyEventResult.ignored;
      log('message: ${e.toString()} ${DateTime.now().millisecondsSinceEpoch - _currentTimeStamp}');
      if (e.logicalKey == LogicalKeyboardKey.enter ||
          e.logicalKey == LogicalKeyboardKey.select ||
          e.logicalKey == LogicalKeyboardKey.space ||
          e.logicalKey == LogicalKeyboardKey.controlRight ||
          e.logicalKey == LogicalKeyboardKey.controlLeft) {
        _eventDirection = 0;
        var now = DateTime.now().millisecondsSinceEpoch;
        if (now - _currentTimeStamp > 500 && _currentTimeStamp != 0) {
          _currentTimeStamp = 0;
          return widget.onLongTap?.call() ?? KeyEventResult.ignored;
        }
        widget.onTap?.call();
        return KeyEventResult.ignored;
      }
    }
    if (e is KeyDownEvent) {
      if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        return widget.onRightKey?.call() ?? KeyEventResult.ignored;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        return widget.onLeftKey?.call() ?? KeyEventResult.ignored;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
        return widget.onUpKey?.call() ?? KeyEventResult.ignored;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
        return widget.onDownKey?.call() ?? KeyEventResult.ignored;
      }
      if (e.logicalKey == LogicalKeyboardKey.enter ||
          e.logicalKey == LogicalKeyboardKey.select ||
          e.logicalKey == LogicalKeyboardKey.space ||
          e.logicalKey == LogicalKeyboardKey.controlRight ||
          e.logicalKey == LogicalKeyboardKey.controlLeft) {
        _currentTimeStamp = DateTime.now().millisecondsSinceEpoch;
        _eventDirection = 1;
      }
    }
    return KeyEventResult.ignored;
  }
}
