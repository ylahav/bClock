import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../l10n/app_localizations.dart';
import '../models/world_city.dart';
import '../providers/app_provider.dart';
import '../widgets/analog_clock.dart';
import '../widgets/digital_clock.dart';
import 'clock_screen.dart' show ClockViewToggle;

String _utcLabel(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final h = abs.inHours;
  final m = abs.inMinutes.remainder(60);
  return m == 0 ? 'UTC$sign$h' : 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
}

class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key});

  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  static const _gridBottomPad = 12.0;
  // Room for a card's header + footer and a legible clock.
  static const _minCardHeight = 110.0;

  late DateTime _utcNow;
  late Timer _timer;

  final List<WorldCity> _active = List.from(WorldCity.defaults);

  @override
  void initState() {
    super.initState();
    _utcNow = DateTime.now().toUtc();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _utcNow = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  tz.TZDateTime _cityTime(WorldCity city) =>
      tz.TZDateTime.from(_utcNow, tz.getLocation(city.tz));

  void _removeCity(WorldCity city) {
    setState(() => _active.remove(city));
  }

  Future<void> _showAddDialog() async {
    final available =
        WorldCity.pool.where((c) => !_active.contains(c)).toList();
    if (available.isEmpty) return;

    final modal = PlinthDisclosureController(initiallyOpen: true);
    await PlinthModal(
      controller: modal,
      title: AppLocalizations.of(context).addCityTitle,
      size: PlinthSize.xs,
      child: _AddCityPanel(
        available: available,
        onAdd: (city) => setState(() => _active.add(city)),
      ),
    ).show(context);
    modal.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final l = AppLocalizations.of(context);

    return PlinthPage(
      title: l.worldTitle,
      titleOrder: 4,
      background: Theme.of(context).scaffoldBackgroundColor,
      actions: [
        PlinthTooltip(
          message: l.addCity,
          child: PlinthActionIcon(
            semanticLabel: l.addCity,
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            variant: PlinthVariant.subtle,
            color: 'gray',
          ),
        ),
      ],
      // ── Clock style toggle ─────────────────────────────
      below: Center(
        child: ClockViewToggle(
          view: p.clockView,
          onChanged: p.setClockView,
        ),
      ),
      body: Column(
        children: [
          // ── Grid ──────────────────────────────────────────
          Expanded(
            child: _active.isEmpty
                ? Center(
                    child: PlinthEmptyState(
                      icon: const Icon(Icons.language),
                      title: l.noCities,
                      action: PlinthButton(
                        variant: PlinthVariant.light,
                        leadingIcon: const Icon(Icons.add),
                        onPressed: _showAddDialog,
                        child: Text(l.addACity),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount =
                          (constraints.maxWidth / 200).floor().clamp(2, 5);
                      final cellW =
                          (constraints.maxWidth - 10 * (crossAxisCount - 1)) /
                              crossAxisCount;
                      // Height the chosen clock style wants for this width…
                      final idealH = cellW /
                          switch (p.clockView) {
                            ClockView.digital => 1.10,
                            ClockView.analog => 0.95,
                            ClockView.both => 0.72,
                          };
                      // …capped to the window, since the window height is
                      // set by the Clock tab. The card's clock scales down
                      // to fit; below _minCardHeight the grid scrolls.
                      final fitH = constraints.maxHeight - _gridBottomPad;
                      final cellH = min(idealH, max(fitH, _minCardHeight));
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: _gridBottomPad),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: cellH,
                        ),
                        itemCount: _active.length,
                        itemBuilder: (context, i) {
                          final city = _active[i];
                          return _WorldCard(
                            city: city,
                            cityTime: _cityTime(city),
                            view: p.clockView,
                            cellWidth: cellW,
                            onDelete: () => _removeCity(city),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── City card ──────────────────────────────────────────────────

class _WorldCard extends StatelessWidget {
  final WorldCity city;
  final tz.TZDateTime cityTime;
  final ClockView view;
  final double cellWidth;
  final VoidCallback onDelete;

  const _WorldCard({
    required this.city,
    required this.cityTime,
    required this.view,
    required this.cellWidth,
    required this.onDelete,
  });

  bool get _isDay => cityTime.hour >= 6 && cityTime.hour < 20;

  Widget _clockWidget() {
    final analogSize = (cellWidth * 0.62).clamp(52.0, 130.0);
    final fontSize = (cellWidth * 0.18).clamp(16.0, 36.0);

    switch (view) {
      case ClockView.digital:
        return DigitalClock(
          time: cityTime,
          fontSize: fontSize,
          compact: true,
        );
      case ClockView.analog:
        return AnalogClock(time: cityTime, size: analogSize);
      case ClockView.both:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnalogClock(time: cityTime, size: analogSize * 0.80),
            const SizedBox(height: 6),
            DigitalClock(
              time: cityTime,
              fontSize: fontSize * 0.82,
              compact: true,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;

    return PlinthPaper(
      p: PlinthSize.xs,
      radius: PlinthSize.lg,
      bg: theme.surface,
      withBorder: true,
      child: Stack(
        children: [
          // ── Main content ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header: day/night icon + city name
                Row(
                  children: [
                    Icon(
                      _isDay
                          ? Icons.wb_sunny_outlined
                          : Icons.nights_stay_outlined,
                      size: 14,
                      color: _isDay
                          ? theme.readableOn(theme.primaryColor, theme.surface)
                          : theme.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: PlinthText(
                        city.city,
                        size: PlinthSize.sm,
                        weight: theme.weight(PlinthWeight.semibold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Leave room for the close button.
                    const SizedBox(width: 18),
                  ],
                ),

                // Clock display — takes what the header and footer
                // leave, shrinking when the card is height-capped.
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _clockWidget(),
                    ),
                  ),
                ),

                // Footer: timezone + date
                Column(
                  children: [
                    PlinthText(
                      '${city.country}  ·  ${cityTime.timeZoneName}',
                      size: PlinthSize.xs,
                      color: 'gray',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    PlinthText(
                      DateFormat.MMMEd(
                              Localizations.localeOf(context).toLanguageTag())
                          .format(cityTime),
                      size: PlinthSize.xs,
                      color: 'gray',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Delete button (top-right) ─────────────────────
          PositionedDirectional(
            top: 0,
            end: 0,
            child: PlinthCloseButton(
              size: PlinthSize.xs,
              semanticLabel: AppLocalizations.of(context).removeCity(city.city),
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add city panel (modal body) ────────────────────────────────

class _AddCityPanel extends StatefulWidget {
  final List<WorldCity> available;
  final ValueChanged<WorldCity> onAdd;

  const _AddCityPanel({required this.available, required this.onAdd});

  @override
  State<_AddCityPanel> createState() => _AddCityPanelState();
}

class _AddCityPanelState extends State<_AddCityPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final filtered = widget.available
        .where((c) =>
            c.city.toLowerCase().contains(q) ||
            c.country.toLowerCase().contains(q))
        .toList();

    return PlinthStack(
      children: [
        // TODO(plinth): PlinthTextInput has no autofocus.
        PlinthTextInput(
          placeholder: AppLocalizations.of(context).searchCities,
          leadingIcon: const Icon(Icons.search),
          onChanged: (v) => setState(() => _query = v),
        ),
        SizedBox(
          height: 360,
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final city = filtered[i];
              final now = tz.TZDateTime.now(tz.getLocation(city.tz));
              final utcLabel = _utcLabel(now.timeZoneOffset);
              return PlinthNavLink(
                label: '${city.city}, ${city.country}',
                trailing: PlinthText(
                  '${now.timeZoneName}  ·  $utcLabel',
                  size: PlinthSize.xs,
                  color: 'gray',
                ),
                onTap: () {
                  widget.onAdd(city);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
