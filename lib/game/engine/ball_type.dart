/// Sport ball kinds that can appear in bottles.
///
/// Each type has a single-character [code] used by the compact level format.
enum BallType {
  basketball('B', 'Basketbol'),
  football('F', 'Futbol'),
  baseball('S', 'Beyzbol'),
  tennis('T', 'Tenis'),
  volleyball('V', 'Voleybol');

  const BallType(this.code, this.displayName);

  final String code;
  final String displayName;

  static BallType fromCode(String code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    throw ArgumentError.value(code, 'code', 'Unknown ball code');
  }
}
