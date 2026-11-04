import 'package:flutter/material.dart';

import '../../../core/theme/norve_admin_tokens.dart';

/// Crisp modern search field designed for administrative filtering
/// with smooth micro-interaction hover and focus transitions.
class AdminSearchField extends StatefulWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.width,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final double? width;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  bool _isHovered = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;

    final borderColor = isFocused
        ? AdminColors.charcoal
        : _isHovered
            ? AdminColors.neutralGrey
            : AdminColors.line;

    final field = ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: AdminMotion.duration(context, AdminMotion.hover),
            curve: AdminMotion.curveFast,
            height: 40,
            decoration: BoxDecoration(
              color: AdminColors.white,
              borderRadius: AdminRadii.radiusSm,
              border: Border.all(
                color: borderColor,
                width: isFocused ? 1.5 : 1.0,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: AdminTypography.body,
              cursorColor: AdminColors.charcoal,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AdminSpacing.md,
                  vertical: 10,
                ),
                hintText: widget.hintText,
                hintStyle: AdminTypography.caption.copyWith(
                  color: AdminColors.neutralGrey,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AdminColors.muted,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: AdminColors.muted,
                        splashRadius: 16,
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged?.call('');
                          widget.onClear?.call();
                        },
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: field);
    }
    return field;
  }
}

/// Refined select / filter dropdown component with micro-interaction hover states.
class AdminFilterDropdown<T> extends StatefulWidget {
  const AdminFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
    this.isExpanded = true,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double? width;
  final bool isExpanded;

  @override
  State<AdminFilterDropdown<T>> createState() => _AdminFilterDropdownState<T>();
}

class _AdminFilterDropdownState<T> extends State<AdminFilterDropdown<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final dropdown = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AdminMotion.duration(context, AdminMotion.hover),
        curve: AdminMotion.curveFast,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
        decoration: BoxDecoration(
          color: _isHovered ? AdminColors.surfaceSubtle : AdminColors.white,
          border: Border.all(
            color: _isHovered ? AdminColors.charcoal : AdminColors.line,
            width: 1.0,
          ),
          borderRadius: AdminRadii.radiusSm,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: widget.value,
            items: widget.items,
            onChanged: widget.onChanged,
            isDense: true,
            isExpanded: widget.isExpanded,
            style: AdminTypography.body,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AdminColors.muted,
            ),
            dropdownColor: AdminColors.white,
            borderRadius: AdminRadii.radiusSm,
          ),
        ),
      ),
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: dropdown);
    }
    return dropdown;
  }
}
