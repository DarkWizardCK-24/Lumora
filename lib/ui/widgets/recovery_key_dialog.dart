import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/colors/app_colors.dart';

/// Shows a recovery key once and makes the user confirm they saved it.
Future<void> showRecoveryKey(BuildContext context, String key, {bool reset = false}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => _RecoveryKeyDialog(recoveryKey: key, reset: reset),
  );
}

class _RecoveryKeyDialog extends StatefulWidget {
  const _RecoveryKeyDialog({required this.recoveryKey, required this.reset});
  final String recoveryKey;
  final bool reset;
  @override
  State<_RecoveryKeyDialog> createState() => _RecoveryKeyDialogState();
}

class _RecoveryKeyDialogState extends State<_RecoveryKeyDialog> {
  bool _saved = false, _copied = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reset ? 'Your new recovery key' : 'Save your recovery key'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'Your data is encrypted on this device. If you forget your password, this key is the only way to get back in. '
              'It is shown once and is not stored anywhere. Keep it somewhere safe, offline.'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Palette.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: Palette.border)),
            child: SelectableText(widget.recoveryKey,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.recoveryKey));
                if (mounted) setState(() => _copied = true);
              },
              icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
              label: Text(_copied ? 'Copied' : 'Copy'),
            ),
          ),
          CheckboxListTile(
            value: _saved,
            onChanged: (v) => setState(() => _saved = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('I have saved my recovery key'),
          ),
        ]),
      ),
      actions: [
        FilledButton(onPressed: _saved ? () => Navigator.pop(context) : null, child: const Text('Continue')),
      ],
    );
  }
}
