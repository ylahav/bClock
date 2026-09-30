class WorldCity {
  final String city;
  final String country;

  /// IANA timezone identifier (e.g. "America/New_York"). DST-aware —
  /// resolve to a live `tz.Location` at render time; do not cache offsets.
  final String tz;

  const WorldCity({
    required this.city,
    required this.country,
    required this.tz,
  });

  @override
  bool operator ==(Object other) =>
      other is WorldCity && other.city == city && other.country == country;

  @override
  int get hashCode => Object.hash(city, country);

  // ── Full pool of selectable cities ────────────────────────

  static const List<WorldCity> pool = [
    // Americas
    WorldCity(city: 'Honolulu', country: 'US', tz: 'Pacific/Honolulu'),
    WorldCity(city: 'Anchorage', country: 'US', tz: 'America/Anchorage'),
    WorldCity(city: 'Los Angeles', country: 'US', tz: 'America/Los_Angeles'),
    WorldCity(city: 'Denver', country: 'US', tz: 'America/Denver'),
    WorldCity(city: 'Chicago', country: 'US', tz: 'America/Chicago'),
    WorldCity(city: 'New York', country: 'US', tz: 'America/New_York'),
    WorldCity(city: 'Toronto', country: 'CA', tz: 'America/Toronto'),
    WorldCity(city: 'São Paulo', country: 'BR', tz: 'America/Sao_Paulo'),
    WorldCity(
        city: 'Buenos Aires',
        country: 'AR',
        tz: 'America/Argentina/Buenos_Aires'),
    // Europe
    WorldCity(city: 'London', country: 'UK', tz: 'Europe/London'),
    WorldCity(city: 'Lisbon', country: 'PT', tz: 'Europe/Lisbon'),
    WorldCity(city: 'Paris', country: 'FR', tz: 'Europe/Paris'),
    WorldCity(city: 'Berlin', country: 'DE', tz: 'Europe/Berlin'),
    WorldCity(city: 'Rome', country: 'IT', tz: 'Europe/Rome'),
    WorldCity(city: 'Amsterdam', country: 'NL', tz: 'Europe/Amsterdam'),
    WorldCity(city: 'Madrid', country: 'ES', tz: 'Europe/Madrid'),
    WorldCity(city: 'Stockholm', country: 'SE', tz: 'Europe/Stockholm'),
    WorldCity(city: 'Tel Aviv', country: 'IL', tz: 'Asia/Jerusalem'),
    WorldCity(city: 'Cairo', country: 'EG', tz: 'Africa/Cairo'),
    WorldCity(city: 'Kyiv', country: 'UA', tz: 'Europe/Kyiv'),
    WorldCity(city: 'Moscow', country: 'RU', tz: 'Europe/Moscow'),
    WorldCity(city: 'Riyadh', country: 'SA', tz: 'Asia/Riyadh'),
    WorldCity(city: 'Istanbul', country: 'TR', tz: 'Europe/Istanbul'),
    // Middle East & Asia
    WorldCity(city: 'Dubai', country: 'AE', tz: 'Asia/Dubai'),
    WorldCity(city: 'Karachi', country: 'PK', tz: 'Asia/Karachi'),
    WorldCity(city: 'Mumbai', country: 'IN', tz: 'Asia/Kolkata'),
    WorldCity(city: 'Colombo', country: 'LK', tz: 'Asia/Colombo'),
    WorldCity(city: 'Dhaka', country: 'BD', tz: 'Asia/Dhaka'),
    WorldCity(city: 'Bangkok', country: 'TH', tz: 'Asia/Bangkok'),
    WorldCity(city: 'Jakarta', country: 'ID', tz: 'Asia/Jakarta'),
    WorldCity(city: 'Singapore', country: 'SG', tz: 'Asia/Singapore'),
    WorldCity(city: 'Hong Kong', country: 'HK', tz: 'Asia/Hong_Kong'),
    WorldCity(city: 'Beijing', country: 'CN', tz: 'Asia/Shanghai'),
    WorldCity(city: 'Taipei', country: 'TW', tz: 'Asia/Taipei'),
    WorldCity(city: 'Seoul', country: 'KR', tz: 'Asia/Seoul'),
    WorldCity(city: 'Tokyo', country: 'JP', tz: 'Asia/Tokyo'),
    // Pacific
    WorldCity(city: 'Sydney', country: 'AU', tz: 'Australia/Sydney'),
    WorldCity(city: 'Melbourne', country: 'AU', tz: 'Australia/Melbourne'),
    WorldCity(city: 'Auckland', country: 'NZ', tz: 'Pacific/Auckland'),
  ];

  // ── Default active cities ──────────────────────────────────

  static const List<WorldCity> defaults = [
    WorldCity(city: 'New York', country: 'US', tz: 'America/New_York'),
    WorldCity(city: 'London', country: 'UK', tz: 'Europe/London'),
    WorldCity(city: 'Tel Aviv', country: 'IL', tz: 'Asia/Jerusalem'),
    WorldCity(city: 'Dubai', country: 'AE', tz: 'Asia/Dubai'),
    WorldCity(city: 'Mumbai', country: 'IN', tz: 'Asia/Kolkata'),
    WorldCity(city: 'Singapore', country: 'SG', tz: 'Asia/Singapore'),
    WorldCity(city: 'Tokyo', country: 'JP', tz: 'Asia/Tokyo'),
    WorldCity(city: 'Sydney', country: 'AU', tz: 'Australia/Sydney'),
  ];
}
