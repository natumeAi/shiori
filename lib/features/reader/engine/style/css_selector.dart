/// CSS selector subset: compilation from `package:csslib` and matching
/// against a [SourceDocument]. Pure Dart.
///
/// Supported: type, universal, class, id, attribute presence and
/// `=`/`~=`/`|=`/`^=`/`$=`/`*=`, `:not(<simple>)`, `:first-child`,
/// `:last-child`, `:only-child`, `:first-of-type`, `:last-of-type`,
/// `:only-of-type`, `:root`, `:empty`, `:link`/`:any-link`; descendant,
/// child, adjacent-sibling and general-sibling combinators. Dynamic
/// pseudo-classes (`:hover`, `:visited`, ...) are valid and never match.
/// Everything else (pseudo-elements, `:nth-*`, namespaces) is reported and
/// the selector is dropped.
library;

import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';

const _xhtmlNamespace = 'http://www.w3.org/1999/xhtml';

/// Element relationships of one document, precomputed for selector matching.
final class StyleTree {
  StyleTree(this.document) {
    final nodes = document.nodes;
    final count = nodes.length;
    _siblingPos = List.filled(count, 0);
    _siblingCount = List.filled(count, 1);
    _typePos = List.filled(count, 0);
    _typeCount = List.filled(count, 1);
    _prev = List.filled(count, null);
    for (final node in nodes) {
      if (node.kind != SourceNodeKind.element) continue;
      final elements = [
        for (final child in node.children)
          if (nodes[child].kind == SourceNodeKind.element) child,
      ];
      final perType = <String, List<int>>{};
      for (var i = 0; i < elements.length; i++) {
        final index = elements[i];
        _siblingPos[index] = i;
        _siblingCount[index] = elements.length;
        _prev[index] = i == 0 ? null : elements[i - 1];
        perType.putIfAbsent(nameOf(index) ?? '', () => []).add(index);
      }
      for (final group in perType.values) {
        for (var i = 0; i < group.length; i++) {
          _typePos[group[i]] = i;
          _typeCount[group[i]] = group.length;
        }
      }
    }
    // The document element has no parent element: treat it as a sole child.
    final root = document.documentElementIndex;
    _siblingCount[root] = 1;
    _typeCount[root] = 1;
  }

  final SourceDocument document;
  late final List<int> _siblingPos;
  late final List<int> _siblingCount;
  late final List<int> _typePos;
  late final List<int> _typeCount;
  late final List<int?> _prev;
  final Map<int, Set<String>> _classes = {};

  SourceNode node(int index) => document.nodes[index];

  bool isElement(int index) => node(index).kind == SourceNodeKind.element;

  /// Lowercase local name for HTML-ish elements, exact otherwise.
  String? nameOf(int index) {
    final n = node(index);
    final name = n.localName;
    if (name == null) return null;
    final ns = n.namespaceUri;
    return ns == null || ns == _xhtmlNamespace ? name.toLowerCase() : name;
  }

  int? parentElement(int index) {
    final parent = node(index).parentIndex;
    return parent != null && isElement(parent) ? parent : null;
  }

  int? prevElement(int index) => _prev[index];
  int siblingPos(int index) => _siblingPos[index];
  int siblingCount(int index) => _siblingCount[index];
  int typePos(int index) => _typePos[index];
  int typeCount(int index) => _typeCount[index];

  Set<String> classesOf(int index) => _classes.putIfAbsent(index, () {
    final value = node(index).attribute('class');
    if (value == null) return const <String>{};
    return value
        .split(RegExp(r'[ \t\r\n\f]+'))
        .where((c) => c.isNotEmpty)
        .toSet();
  });

  String? attribute(int index, String name) {
    for (final attribute in node(index).attributes) {
      if (attribute.qualifiedName == name ||
          attribute.qualifiedName.toLowerCase() == name) {
        return attribute.value;
      }
    }
    return null;
  }

  bool isEmptyElement(int index) {
    for (final child in node(index).children) {
      final c = node(child);
      if (c.kind == SourceNodeKind.element) return false;
      if (c.isCharacterData && (c.text ?? '').isNotEmpty) return false;
    }
    return true;
  }
}

sealed class _Simple {
  const _Simple();
  bool matches(StyleTree tree, int element);
}

final class _Universal extends _Simple {
  const _Universal();
  @override
  bool matches(StyleTree tree, int element) => true;
}

final class _Type extends _Simple {
  const _Type(this.name);
  final String name;
  @override
  bool matches(StyleTree tree, int element) => tree.nameOf(element) == name;
}

final class _Class extends _Simple {
  const _Class(this.name);
  final String name;
  @override
  bool matches(StyleTree tree, int element) =>
      tree.classesOf(element).contains(name);
}

final class _Id extends _Simple {
  const _Id(this.name);
  final String name;
  @override
  bool matches(StyleTree tree, int element) => tree.node(element).id == name;
}

final class _Attribute extends _Simple {
  const _Attribute(this.name, this.operator, this.value);
  final String name;

  /// null for presence; otherwise one of `=`, `~=`, `|=`, `^=`, `$=`, `*=`.
  final String? operator;
  final String value;

  @override
  bool matches(StyleTree tree, int element) {
    final actual = tree.attribute(element, name);
    if (actual == null) return false;
    return switch (operator) {
      null => true,
      '=' => actual == value,
      '~=' =>
        value.isNotEmpty &&
            !value.contains(RegExp(r'\s')) &&
            actual.split(RegExp(r'\s+')).contains(value),
      '|=' => actual == value || actual.startsWith('$value-'),
      '^=' => value.isNotEmpty && actual.startsWith(value),
      r'$=' => value.isNotEmpty && actual.endsWith(value),
      '*=' => value.isNotEmpty && actual.contains(value),
      _ => false,
    };
  }
}

enum _Pseudo {
  firstChild,
  lastChild,
  onlyChild,
  firstOfType,
  lastOfType,
  onlyOfType,
  root,
  empty,
  link,
  never,
}

final class _PseudoClass extends _Simple {
  const _PseudoClass(this.kind);
  final _Pseudo kind;

  @override
  bool matches(StyleTree tree, int element) => switch (kind) {
    _Pseudo.firstChild => tree.siblingPos(element) == 0,
    _Pseudo.lastChild =>
      tree.siblingPos(element) == tree.siblingCount(element) - 1,
    _Pseudo.onlyChild => tree.siblingCount(element) == 1,
    _Pseudo.firstOfType => tree.typePos(element) == 0,
    _Pseudo.lastOfType => tree.typePos(element) == tree.typeCount(element) - 1,
    _Pseudo.onlyOfType => tree.typeCount(element) == 1,
    _Pseudo.root => element == tree.document.documentElementIndex,
    _Pseudo.empty => tree.isEmptyElement(element),
    _Pseudo.link =>
      (tree.nameOf(element) == 'a' || tree.nameOf(element) == 'area') &&
          tree.attribute(element, 'href') != null,
    _Pseudo.never => false,
  };
}

final class _Not extends _Simple {
  const _Not(this.inner);
  final _Simple inner;
  @override
  bool matches(StyleTree tree, int element) => !inner.matches(tree, element);
}

enum CssCombinator { descendant, child, adjacent, sibling }

/// One compound selector (`p.accent[lang]`).
final class _Compound {
  const _Compound(this.parts);
  final List<_Simple> parts;

  bool matches(StyleTree tree, int element) {
    for (final part in parts) {
      if (!part.matches(tree, element)) return false;
    }
    return true;
  }
}

/// A compiled complex selector with its specificity.
final class CssSelector {
  CssSelector._(
    this._compounds,
    this._combinators,
    this.specificity,
    this.bucketKind,
    this.bucketKey,
  );

  final List<_Compound> _compounds;

  /// `_combinators[i]` joins compound i-1 and i (index 0 unused).
  final List<CssCombinator?> _combinators;

  /// `(ids << 16) | (classes/attributes/pseudo-classes << 8) | types`.
  final int specificity;

  /// Rightmost-compound bucket for rule lookup: `'#'` id, `'.'` class, `'t'`
  /// type, `'*'` anything else.
  final String bucketKind;
  final String bucketKey;

  bool matches(StyleTree tree, int element) =>
      _from(tree, _compounds.length - 1, element);

  bool _from(StyleTree tree, int i, int element) {
    if (!_compounds[i].matches(tree, element)) return false;
    if (i == 0) return true;
    switch (_combinators[i]!) {
      case CssCombinator.child:
        final parent = tree.parentElement(element);
        return parent != null && _from(tree, i - 1, parent);
      case CssCombinator.descendant:
        for (
          var parent = tree.parentElement(element);
          parent != null;
          parent = tree.parentElement(parent)
        ) {
          if (_from(tree, i - 1, parent)) return true;
        }
        return false;
      case CssCombinator.adjacent:
        final prev = tree.prevElement(element);
        return prev != null && _from(tree, i - 1, prev);
      case CssCombinator.sibling:
        for (
          var prev = tree.prevElement(element);
          prev != null;
          prev = tree.prevElement(prev)
        ) {
          if (_from(tree, i - 1, prev)) return true;
        }
        return false;
    }
  }

  /// Compiles one csslib selector, or returns null (after reporting to
  /// [sink]) when it uses an unsupported construct.
  static CssSelector? compile(Selector selector, StyleDiagnosticSink? sink) {
    final compounds = <List<_Simple>>[];
    final combinators = <CssCombinator?>[];
    var ids = 0;
    var classes = 0;
    var types = 0;
    String? unsupported;

    _Simple? convert(SimpleSelector simple, {required bool allowNot}) {
      switch (simple) {
        case ElementSelector():
          if (simple.isWildcard) return const _Universal();
          types++;
          return _Type(simple.name.toLowerCase());
        case NamespaceSelector():
          unsupported = 'namespace';
          return null;
        case ClassSelector():
          classes++;
          return _Class(simple.name);
        case IdSelector():
          ids++;
          return _Id(simple.name);
        case AttributeSelector():
          classes++;
          final op = simple.matchOperator();
          final Object? raw = simple.value;
          final value = raw == null
              ? ''
              : raw is Identifier
              ? raw.name
              : _unquote(raw.toString());
          return _Attribute(
            simple.name.toLowerCase(),
            op == null || op.isEmpty ? null : op,
            value,
          );
        case NegationSelector():
          final arg = simple.negationArg;
          if (arg == null || !allowNot) {
            unsupported = ':not';
            return null;
          }
          final inner = convert(arg, allowNot: false);
          return inner == null ? null : _Not(inner);
        case PseudoElementSelector():
          unsupported = '::${simple.name}';
          return null;
        case PseudoClassFunctionSelector():
          unsupported = ':${simple.name}()';
          return null;
        case PseudoClassSelector():
          classes++;
          final kind = _pseudoClass(simple.name.toLowerCase());
          if (kind == null) {
            unsupported = ':${simple.name}';
            return null;
          }
          return _PseudoClass(kind);
        default:
          unsupported = simple.runtimeType.toString();
          return null;
      }
    }

    for (final sequence in selector.simpleSelectorSequences) {
      final converted = convert(sequence.simpleSelector, allowNot: true);
      if (converted == null) {
        sink?.add(StyleDiagnosticKind.unsupportedSelector, unsupported ?? '?');
        return null;
      }
      if (compounds.isEmpty || !sequence.isCombinatorNone) {
        final CssCombinator? combinator = compounds.isEmpty
            ? null
            : sequence.isCombinatorGreater
            ? CssCombinator.child
            : sequence.isCombinatorPlus
            ? CssCombinator.adjacent
            : sequence.isCombinatorTilde
            ? CssCombinator.sibling
            : CssCombinator.descendant;
        compounds.add([converted]);
        combinators.add(combinator);
      } else {
        compounds.last.add(converted);
      }
    }
    if (compounds.isEmpty) return null;

    var bucketKind = '*';
    var bucketKey = '';
    for (final part in compounds.last) {
      if (part is _Id) {
        bucketKind = '#';
        bucketKey = part.name;
        break;
      }
      if (part is _Class) {
        bucketKind = '.';
        bucketKey = part.name;
      } else if (part is _Type && bucketKind == '*') {
        bucketKind = 't';
        bucketKey = part.name;
      }
    }
    int clamp(int value) => value > 255 ? 255 : value;
    return CssSelector._(
      [for (final parts in compounds) _Compound(parts)],
      combinators,
      (clamp(ids) << 16) | (clamp(classes) << 8) | clamp(types),
      bucketKind,
      bucketKey,
    );
  }
}

String _unquote(String text) {
  if (text.length >= 2) {
    final first = text[0];
    if ((first == '"' || first == "'") && text.endsWith(first)) {
      return text.substring(1, text.length - 1);
    }
  }
  return text;
}

_Pseudo? _pseudoClass(String name) => switch (name) {
  'first-child' => _Pseudo.firstChild,
  'last-child' => _Pseudo.lastChild,
  'only-child' => _Pseudo.onlyChild,
  'first-of-type' => _Pseudo.firstOfType,
  'last-of-type' => _Pseudo.lastOfType,
  'only-of-type' => _Pseudo.onlyOfType,
  'root' => _Pseudo.root,
  'empty' => _Pseudo.empty,
  'link' || 'any-link' => _Pseudo.link,
  'hover' ||
  'active' ||
  'focus' ||
  'focus-within' ||
  'focus-visible' ||
  'visited' ||
  'target' ||
  'checked' ||
  'disabled' ||
  'enabled' => _Pseudo.never,
  _ => null,
};

/// Compiles every alternative of a selector list; dropped alternatives are
/// reported to [sink].
List<CssSelector> compileSelectorGroup(
  SelectorGroup? group,
  StyleDiagnosticSink? sink,
) {
  if (group == null) return const [];
  return [
    for (final selector in group.selectors)
      ?CssSelector.compile(selector, sink),
  ];
}

/// Parses selector text such as `p.a > b`. Null if csslib rejects it.
List<CssSelector>? parseSelectorText(String text, [StyleDiagnosticSink? sink]) {
  final errors = <css.Message>[];
  final sheet = css.parse('$text{}', errors: errors);
  if (errors.isNotEmpty) return null;
  for (final top in sheet.topLevels) {
    if (top is RuleSet) return compileSelectorGroup(top.selectorGroup, sink);
  }
  return null;
}
