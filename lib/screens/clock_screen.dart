import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_provider.dart';
import '../widgets/analog_clock.dart';
import '../widgets/digital_clock.dart';
import 'settings_screen.dart';

class ClockScreen extends StatefulWidget {
  final bool active;

  const ClockScreen({super.key, this.active = true});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> with WindowListener {
  late DateTime _now;
  late Timer _timer;
  bool _showControls = true;
  bool _fittingWindow = false;
  double? _lastFitWidth;
  ClockView? _lastFitView;
  ClockSizeOption? _lastFitSize;
  bool? _lastFitControls;
  bool? _lastFitNav;
  double? _lastFitChrome;

  // Space PlinthPage takes around the body (padding + header + gap).
  // Measured every layout — the header's height follows the type scale,
  // so it can't be a constant the way AppBar's toolbarHeight was.
  Size _pageChrome = const Size(0, _pageChromeFallback);

  static const _widthFill = 0.98;
  static const _pageChromeFallback = 48.0; // until first layout
  static const _pagePadding = EdgeInsets.fromLTRB(12, 8, 12, 0);
  static const _navHandleHeight = 26.0;
  static const _navBarHeight = 80.0;
  static const _digitalExtraHeight = 22.0; // date line + spacing
  static const _bothGap = 8.0;
  static const _bothHeightFactor =
      0.68 * (1 + 1 / 3.2); // analog + digital stack

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _timer.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ClockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitWindowHeight());
    }
  }

  @override
  void onWindowResize() {
    if (widget.active) _fitWindowHeight();
  }

  // ── Sizing ────────────────────────────────────────────────
  // Width drives clock size; clamp to available height to avoid overflow.

  double _reserveForControls() => _showControls ? 52.0 : 22.0;

  double _sizeFactor(ClockSizeOption opt) => switch (opt) {
        ClockSizeOption.small => 0.72,
        ClockSizeOption.medium => 0.88,
        ClockSizeOption.large => 1.00,
      };

  double _maxBaseSizeForHeight(double available, ClockView view) {
    if (available <= 0) return 60.0;
    return switch (view) {
      ClockView.analog => available,
      ClockView.digital =>
        ((available - _digitalExtraHeight).clamp(20.0, 4000.0)) * 3.2,
      ClockView.both =>
        ((available - _bothGap).clamp(20.0, 4000.0)) / _bothHeightFactor,
    };
  }

  double _baseClockSize(BoxConstraints c, AppProvider p) {
    final factor = _sizeFactor(p.clockSize);
    final byWidth = c.maxWidth * _widthFill * factor;
    final available = c.maxHeight.isFinite ? c.maxHeight : double.infinity;
    final maxByHeight = _maxBaseSizeForHeight(available, p.clockView);
    return min(byWidth, maxByHeight).clamp(60.0, 4000.0);
  }

  double _analogSize(BoxConstraints c, AppProvider p) => _baseClockSize(c, p);

  double _fontSize(BoxConstraints c, AppProvider p) =>
      (_baseClockSize(c, p) / 3.2).clamp(20.0, 4000.0);

  double _clockContentHeight(double width, AppProvider p) {
    final c = BoxConstraints(
        maxWidth: (width - _pageChrome.width).clamp(0.0, 4000.0) * _widthFill);
    return switch (p.clockView) {
      ClockView.analog => _analogSize(c, p),
      ClockView.digital => _fontSize(c, p) + _digitalExtraHeight,
      ClockView.both =>
        _analogSize(c, p) * 0.68 + _bothGap + _fontSize(c, p) * 0.68,
    };
  }

  double _controlsHeight() => _reserveForControls();

  double _targetWindowHeight(double width, AppProvider p) {
    final content = _clockContentHeight(width, p);
    final nav = p.showNav ? _navHandleHeight + _navBarHeight : _navHandleHeight;
    return (_pageChrome.height + content + _controlsHeight() + nav + 8)
        .clamp(240.0, 2000.0);
  }

  Future<void> _fitWindowHeight([double? width]) async {
    if (!widget.active || _fittingWindow || !mounted) return;

    final p = context.read<AppProvider>();
    final current = await windowManager.getSize();
    final w = width ?? current.width;
    final targetH = _targetWindowHeight(w, p);

    if ((current.height - targetH).abs() <= 1) return;

    _fittingWindow = true;
    try {
      await windowManager.setSize(Size(w, targetH));
    } finally {
      _fittingWindow = false;
    }
  }

  void _scheduleFit(double width, AppProvider p) {
    if (!widget.active) return;
    if (_lastFitWidth == width &&
        _lastFitView == p.clockView &&
        _lastFitSize == p.clockSize &&
        _lastFitControls == _showControls &&
        _lastFitNav == p.showNav &&
        _lastFitChrome == _pageChrome.height) {
      return;
    }
    _lastFitWidth = width;
    _lastFitView = p.clockView;
    _lastFitSize = p.clockSize;
    _lastFitControls = _showControls;
    _lastFitNav = p.showNav;
    _lastFitChrome = _pageChrome.height;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _fitWindowHeight(width));
  }

  // ── Clock widget ──────────────────────────────────────────

  Widget _buildClock(AppProvider p, BoxConstraints c) {
    switch (p.clockView) {
      case ClockView.analog:
        return AnalogClock(
          key: const ValueKey('a'),
          time: _now,
          size: _analogSize(c, p),
        );
      case ClockView.digital:
        return DigitalClock(
          key: const ValueKey('d'),
          time: _now,
          fontSize: _fontSize(c, p),
        );
      case ClockView.both:
        final base = _baseClockSize(c, p);
        final aSize = base * 0.68;
        final fSize = (base / 3.2) * 0.68;
        const gap = SizedBox(height: _bothGap);
        final analog = AnalogClock(time: _now, size: aSize);
        final digital =
            DigitalClock(time: _now, fontSize: fSize, compact: true);
        return Column(
          key: const ValueKey('b'),
          mainAxisSize: MainAxisSize.min,
          children: p.digitalPosition == DigitalPosition.above
              ? [digital, gap, analog]
              : [analog, gap, digital],
        );
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final theme = context.plinth;
    final l = AppLocalizations.of(context);

    // Outer LayoutBuilder = the whole tab area, window width. The inner
    // one (body) is what's left after PlinthPage's padding and header;
    // the difference is _pageChrome.
    return LayoutBuilder(builder: (context, page) {
      return PlinthPage(
        title: 'bClock',
        titleOrder: 4,
        background: Theme.of(context).scaffoldBackgroundColor,
        padding: _pagePadding,
        actions: [
          PlinthTooltip(
            message: l.toggleTheme,
            child: PlinthActionIcon(
              semanticLabel: l.toggleTheme,
              variant: PlinthVariant.subtle,
              color: 'gray',
              onPressed: p.toggleTheme,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  p.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  key: ValueKey(p.isDark),
                ),
              ),
            ),
          ),
          PlinthTooltip(
            message: l.settings,
            child: PlinthIndicator(
              visible: p.alwaysOnTop,
              color: theme.primaryColor,
              size: PlinthSize.xs,
              offset: 6,
              child: PlinthActionIcon(
                semanticLabel: l.settings,
                variant: PlinthVariant.subtle,
                color: 'gray',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
          ),
        ],
        body: LayoutBuilder(
          builder: (context, constraints) {
            _pageChrome = Size(page.maxWidth - constraints.maxWidth,
                page.maxHeight - constraints.maxHeight);
            _scheduleFit(page.maxWidth, p);

            final clockConstraints = BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: (constraints.maxHeight - _reserveForControls())
                  .clamp(0.0, double.infinity),
            );

            return Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showControls
                        ? null
                        : () => setState(() {
                              _showControls = true;
                              _fitWindowHeight(page.maxWidth);
                            }),
                    behavior: HitTestBehavior.opaque,
                    // The sizing math aims for a clock that fits, but the
                    // window can be shorter than planned (the user dragged
                    // its edge, or the controls are mid-animation): shrink
                    // the clock then rather than overflow. No-op when it fits.
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.hardEdge,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.94, end: 1.0).animate(
                                CurvedAnimation(
                                    parent: anim, curve: Curves.easeOut),
                              ),
                              child: child,
                            ),
                          ),
                          child: _buildClock(p, clockConstraints),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  child: _showControls
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Flexible so longer translations ("Analogique")
                              // shrink the toggle instead of pushing the
                              // chevron off-window.
                              Flexible(
                                child: ClockViewToggle(
                                  view: p.clockView,
                                  onChanged: (v) {
                                    p.setClockView(v);
                                    _fitWindowHeight(page.maxWidth);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              _ChevronBtn(
                                icon: Icons.keyboard_arrow_down,
                                tooltip: l.hideControls,
                                onTap: () => setState(() {
                                  _showControls = false;
                                  _fitWindowHeight(page.maxWidth);
                                }),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  child: !_showControls
                      ? GestureDetector(
                          onTap: () => setState(() {
                            _showControls = true;
                            _fitWindowHeight(page.maxWidth);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Icon(Icons.keyboard_arrow_up,
                                size: 18, color: theme.textDisabled),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}

// ── Widgets ───────────────────────────────────────────────────

class _ChevronBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ChevronBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PlinthTooltip(
      message: tooltip,
      child: PlinthActionIcon(
        semanticLabel: tooltip,
        icon: Icon(icon),
        onPressed: onTap,
        variant: PlinthVariant.outline,
        color: 'gray',
        size: PlinthSize.sm,
        circle: true,
      ),
    );
  }
}

class ClockViewToggle extends StatelessWidget {
  final ClockView view;
  final ValueChanged<ClockView> onChanged;

  const ClockViewToggle(
      {super.key, required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Scale down (never up) when a translation outgrows a compact window.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: PlinthSegmentedControl<ClockView>(
        size: PlinthSize.sm,
        items: [
          PlinthSegmentedControlItem(ClockView.digital, l.viewDigital),
          PlinthSegmentedControlItem(ClockView.both, l.viewBoth),
          PlinthSegmentedControlItem(ClockView.analog, l.viewAnalog),
        ],
        value: view,
        onChanged: onChanged,
      ),
    );
  }
}
