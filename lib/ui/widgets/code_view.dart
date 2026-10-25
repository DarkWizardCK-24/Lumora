import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/colors/app_colors.dart';
import '../../core/utils/code_tokens.dart';
import '../utils/app_snack.dart';

/// Read-only, selectable code block with syntax colours and a copy button.
class CodeView extends StatelessWidget {
  const CodeView(this.code, {super.key, this.language = '', this.maxLines});
  final String code, language;
  final int? maxLines;

  static const _bg = Color(0xFF0F172A);

  static Color colorOf(CodeTokenKind k) => switch (k) {
        CodeTokenKind.keyword => const Color(0xFFC4B5FD),
        CodeTokenKind.string => const Color(0xFF86EFAC),
        CodeTokenKind.comment => const Color(0xFF64748B),
        CodeTokenKind.number => const Color(0xFFFDBA74),
        CodeTokenKind.type => const Color(0xFF7DD3FC),
        CodeTokenKind.plain => const Color(0xFFE2E8F0),
      };

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontFamily: 'Consolas', fontFamilyFallback: ['Menlo', 'monospace'], fontSize: 13, height: 1.45);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
          child: Row(children: [
            Text(language.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              tooltip: 'Copy code',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white54),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) toast(context, 'Code copied');
              },
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: SelectableText.rich(
            TextSpan(style: base, children: [
              for (final t in tokenizeCode(code))
                TextSpan(
                  text: t.text,
                  style: TextStyle(
                      color: colorOf(t.kind),
                      fontStyle: t.kind == CodeTokenKind.comment ? FontStyle.italic : null,
                      fontWeight: t.kind == CodeTokenKind.keyword ? FontWeight.w600 : null),
                ),
            ]),
            maxLines: maxLines,
          ),
        ),
      ]),
    );
  }
}
