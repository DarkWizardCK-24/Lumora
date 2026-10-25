/// A tiny, dependency-free syntax tokenizer for the snippet vault. It is language
/// agnostic: one set of rules covers Python, Java, C++, JavaScript, Dart, Go, Rust and SQL.
enum CodeTokenKind { plain, keyword, string, comment, number, type }

class CodeToken {
  const CodeToken(this.text, this.kind);
  final String text;
  final CodeTokenKind kind;

  @override
  String toString() => '${kind.name}(${text.replaceAll('\n', r'\n')})';
}

const _keywords = {
  // control flow & declarations common to most languages
  'if', 'else', 'elif', 'for', 'while', 'do', 'switch', 'case', 'default', 'break', 'continue', 'return',
  'try', 'catch', 'except', 'finally', 'throw', 'raise', 'with', 'as', 'in', 'is', 'not', 'and', 'or',
  'def', 'class', 'struct', 'enum', 'interface', 'impl', 'trait', 'fn', 'func', 'function', 'lambda',
  'import', 'from', 'package', 'using', 'namespace', 'include', 'export', 'extends', 'implements',
  'public', 'private', 'protected', 'static', 'final', 'const', 'var', 'let', 'val', 'mut', 'void',
  'new', 'this', 'self', 'super', 'null', 'nil', 'None', 'true', 'false', 'True', 'False',
  'async', 'await', 'yield', 'pass', 'del', 'global', 'nonlocal', 'typedef', 'template', 'typename',
  'int', 'long', 'double', 'float', 'bool', 'boolean', 'char', 'string', 'str', 'byte',
  // SQL (matched case-insensitively below)
  'select', 'where', 'join', 'left', 'right', 'inner', 'outer', 'group', 'order', 'by', 'having',
  'insert', 'update', 'delete', 'create', 'table', 'into', 'values', 'limit', 'distinct', 'union', 'on',
};

final _sqlWords = {
  'select', 'where', 'join', 'left', 'right', 'inner', 'outer', 'group', 'order', 'by', 'having',
  'insert', 'update', 'delete', 'create', 'table', 'into', 'values', 'limit', 'distinct', 'union', 'on'
};

final _pattern = RegExp(
  r'(?<comment>//[^\n]*|/\*[\s\S]*?(?:\*/|$)|(?:^|(?<=\s))#[^\n]*|--\s[^\n]*)'
  r'|(?<string>"""[\s\S]*?(?:"""|$)|"(?:\\.|[^"\\\n])*"?|' "'" r'(?:\\.|[^' "'" r'\\\n])*' "'" r'?|`[^`]*`?)'
  r'|(?<number>\b\d[\d_]*(?:\.\d+)?\b)'
  r'|(?<word>[A-Za-z_][A-Za-z_0-9]*)',
  multiLine: true,
);

/// Splits [code] into highlighted tokens. Concatenating the token texts always reproduces [code].
List<CodeToken> tokenizeCode(String code) {
  final out = <CodeToken>[];
  var last = 0;
  void plain(int end) {
    if (end > last) out.add(CodeToken(code.substring(last, end), CodeTokenKind.plain));
  }

  for (final m in _pattern.allMatches(code)) {
    if (m.end == m.start) continue;
    final text = m.group(0)!;
    CodeTokenKind? kind;
    if (m.namedGroup('comment') != null) {
      kind = CodeTokenKind.comment;
    } else if (m.namedGroup('string') != null) {
      kind = CodeTokenKind.string;
    } else if (m.namedGroup('number') != null) {
      kind = CodeTokenKind.number;
    } else {
      if (_keywords.contains(text) || _sqlWords.contains(text.toLowerCase()) && text == text.toUpperCase()) {
        kind = CodeTokenKind.keyword;
      } else if (RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(text) && text.length > 1 && text != text.toUpperCase()) {
        kind = CodeTokenKind.type;
      }
    }
    if (kind == null) continue; // ordinary identifier: stays in the plain gap
    plain(m.start);
    out.add(CodeToken(text, kind));
    last = m.end;
  }
  plain(code.length);
  return out;
}
