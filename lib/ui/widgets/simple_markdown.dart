import 'package:flutter/material.dart';

/// Minimal Markdown renderer: headings, bullets, bold, inline and fenced code.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.text, {super.key});
  final String text;

  List<InlineSpan> _inline(String s, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start), style: base));
      final t = m.group(0)!;
      if (t.startsWith('**')) {
        spans.add(TextSpan(text: t.substring(2, t.length - 2), style: base.copyWith(fontWeight: FontWeight.w700)));
      } else {
        spans.add(TextSpan(text: t.substring(1, t.length - 1), style: base.copyWith(fontFamily: 'Consolas', backgroundColor: const Color(0x1A64748B))));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last), style: base));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.5);
    final out = <Widget>[];
    var inCode = false;
    final code = StringBuffer();
    for (final line in text.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          out.add(Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
              child: SelectableText(code.toString().trimRight(), style: const TextStyle(fontFamily: 'Consolas', color: Color(0xFFE2E8F0)))));
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.writeln(line);
      } else if (line.startsWith('### ')) {
        out.add(Padding(padding: const EdgeInsets.only(top: 8), child: Text(line.substring(4), style: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700))));
      } else if (line.startsWith('## ')) {
        out.add(Padding(padding: const EdgeInsets.only(top: 10), child: Text(line.substring(3), style: base.copyWith(fontSize: 19, fontWeight: FontWeight.w700))));
      } else if (line.startsWith('# ')) {
        out.add(Padding(padding: const EdgeInsets.only(top: 12), child: Text(line.substring(2), style: base.copyWith(fontSize: 24, fontWeight: FontWeight.w700))));
      } else if (line.trimLeft().startsWith('- ') || line.trimLeft().startsWith('* ')) {
        out.add(Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  '),
              Expanded(child: Text.rich(TextSpan(children: _inline(line.trimLeft().substring(2), base)))),
            ])));
      } else if (line.trim().isEmpty) {
        out.add(const SizedBox(height: 8));
      } else {
        out.add(Text.rich(TextSpan(children: _inline(line, base))));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }
}
