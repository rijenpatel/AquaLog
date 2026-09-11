import 'package:flutter/material.dart';

/// A modern, beautifully animated, Material 3 dropdown form field designed
/// for AquaLog's outdoor and operational farm workflows.
class AquaDropdownFormField<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final FormFieldValidator<T>? validator;
  final bool isExpanded;
  final double menuMaxHeight;
  final Color? dropdownColor;
  final EdgeInsetsGeometry? contentPadding;

  const AquaDropdownFormField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.isExpanded = true,
    this.menuMaxHeight = 320.0,
    this.dropdownColor,
    this.contentPadding,
  });

  @override
  State<AquaDropdownFormField<T>> createState() => _AquaDropdownFormFieldState<T>();
}

class _AquaDropdownFormFieldState<T> extends State<AquaDropdownFormField<T>> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveDropdownColor = widget.dropdownColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerLowest);

    final borderColor = _isFocused
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withOpacity(0.6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: DropdownButtonFormField<T>(
        value: widget.value,
        focusNode: _focusNode,
        isExpanded: widget.isExpanded,
        menuMaxHeight: widget.menuMaxHeight,
        elevation: 6,
        dropdownColor: effectiveDropdownColor,
        borderRadius: BorderRadius.circular(18),
        icon: AnimatedRotation(
          turns: _isFocused ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _isFocused
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            size: 22,
          ),
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon,
          filled: true,
          fillColor: isDark
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.surfaceContainerLowest,
          contentPadding: widget.contentPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderColor, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8),
          ),
        ),
        items: widget.items,
        onChanged: widget.onChanged,
        validator: widget.validator,
      ),
    );
  }
}
