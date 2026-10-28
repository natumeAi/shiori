/// Typed authored box/paint values shared by cascade and fixed scenes.
part of 'computed_style.dart';

enum AuthoredPosition { static, relative, absolute, fixed }

enum AuthoredVisibility { visible, hidden }

enum AuthoredBoxSizing { contentBox, borderBox }

enum AuthoredOverflow { visible, hidden, clip }

enum BackgroundRepeat { repeat, repeatX, repeatY, noRepeat }

final class AuthoredTransform {
  AuthoredTransform(this.name, List<Object> arguments)
    : arguments = List.unmodifiable(arguments);
  final String name;

  /// Resolved StyleLength for translations; doubles for matrix/scales/radians.
  final List<Object> arguments;
}

final class AuthoredStyle {
  const AuthoredStyle.empty() : values = const {};
  AuthoredStyle(Map<String, Object> values) : values = Map.unmodifiable(values);
  final Map<String, Object> values;
  T get<T>(String property, T fallback) => values[property] as T? ?? fallback;
  AuthoredPosition get position => get('position', AuthoredPosition.static);
  AuthoredVisibility get visibility =>
      get('visibility', AuthoredVisibility.visible);
  AuthoredBoxSizing get boxSizing =>
      get('box-sizing', AuthoredBoxSizing.contentBox);
  AuthoredOverflow get overflow => get('overflow', AuthoredOverflow.visible);
  double get opacity => get('opacity', 1.0);
  int? get zIndex => values['z-index'] as int?;
  double get wordSpacing =>
      get<StyleLength>('word-spacing', StyleLength.zero).value;
  StyleLength inset(String edge) => get(edge, const StyleLength.auto());
  StyleLength minimum(String axis) => get('min-$axis', StyleLength.zero);
  StyleLength borderWidth(String edge) =>
      get('border-$edge-width', StyleLength.zero);
  String borderStyle(String edge) => get('border-$edge-style', 'none');
  int borderColor(String edge, int color) => get('border-$edge-color', color);
  StyleLength radius(String corner) =>
      get('border-$corner-radius', StyleLength.zero);
  String? get backgroundImage => values['background-image'] as String?;
  BackgroundRepeat get backgroundRepeat =>
      get('background-repeat', BackgroundRepeat.repeat);
  List<StyleLength> get backgroundPosition => get('background-position', const [
    StyleLength.percent(0),
    StyleLength.percent(0),
  ]);
  Object get backgroundSize =>
      values['background-size'] ??
      const [StyleLength.auto(), StyleLength.auto()];
  List<AuthoredTransform> get transforms => get('transform', const []);
  List<StyleLength> get transformOrigin => get('transform-origin', const [
    StyleLength.percent(50),
    StyleLength.percent(50),
  ]);
}
