import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: widget.maxLines > 1 ? 10 : 2),
      child: Row(
        crossAxisAlignment: widget.maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Padding(
              padding: EdgeInsets.only(top: widget.maxLines > 1 ? 12 : 0),
              child: Icon(widget.icon, size: 20, color: c.secondaryLabel),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              maxLength: widget.maxLength,
              maxLines: widget.obscure ? 1 : widget.maxLines,
              minLines: widget.minLines,
              autofocus: widget.autofocus,
              inputFormatters: widget.inputFormatters,
              textCapitalization: widget.textCapitalization,
              autocorrect: !widget.obscure && widget.keyboardType != TextInputType.emailAddress,
              enableSuggestions: !widget.obscure,
              style: AppText.body.c(c.label),
              cursorColor: c.brand,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: AppText.body.c(c.tertiaryLabel),
                border: InputBorder.none,
                isDense: false,
                counterStyle: AppText.caption.c(c.tertiaryLabel),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (widget.obscure)
            GestureDetector(
              onTap: () => setState(() => _hidden = !_hidden),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(_hidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash, size: 20, color: c.secondaryLabel),
              ),
            ),
        ],
      ),
    );
  }
}
