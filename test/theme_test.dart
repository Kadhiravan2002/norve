import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norve/core/theme/norve_theme.dart';

void main() {
  final theme = NorveTheme.light;

  test('all Material accent roles resolve to NORVÉ neutrals', () {
    expect(theme.colorScheme.primary, NorveColors.charcoal);
    expect(theme.colorScheme.secondary, NorveColors.charcoal);
    expect(theme.colorScheme.tertiary, NorveColors.charcoal);
    expect(theme.colorScheme.surface, NorveColors.ivory);
    expect(theme.colorScheme.onPrimary, NorveColors.white);
  });

  test(
    'hover, keyboard focus and pressed overlays stay subtle and neutral',
    () {
      final overlay = theme.filledButtonTheme.style!.overlayColor!;

      expect(overlay.resolve({WidgetState.hovered}), NorveInteraction.hover);
      expect(overlay.resolve({WidgetState.focused}), NorveInteraction.focus);
      expect(overlay.resolve({WidgetState.pressed}), NorveInteraction.pressed);
      expect(overlay.resolve({WidgetState.disabled}), isNull);
      expect(theme.textSelectionTheme.cursorColor, NorveColors.charcoal);
    },
  );

  test('navigation and segmented controls use readable selected states', () {
    expect(theme.navigationBarTheme.indicatorColor, NorveInteraction.selected);
    expect(
      theme.navigationBarTheme.iconTheme!.resolve({
        WidgetState.selected,
      })!.color,
      NorveColors.charcoal,
    );
    expect(
      theme.navigationBarTheme.iconTheme!.resolve({})!.color,
      NorveColors.muted,
    );
    expect(
      theme.segmentedButtonTheme.style!.backgroundColor!.resolve({
        WidgetState.selected,
      }),
      NorveColors.charcoal,
    );
    expect(
      theme.segmentedButtonTheme.style!.foregroundColor!.resolve({
        WidgetState.selected,
      }),
      NorveColors.white,
    );
  });

  test('focused text fields use a visible charcoal border', () {
    expect(
      theme.inputDecorationTheme.focusedBorder!.borderSide.color,
      NorveColors.charcoal,
    );
    expect(theme.inputDecorationTheme.focusedBorder!.borderSide.width, 1.5);
  });
}
