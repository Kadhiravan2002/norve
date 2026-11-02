import 'package:flutter/material.dart';

abstract final class NorveColors {
  static const charcoal = Color(0xFF24211E);
  static const ivory = Color(0xFFF5F1EA);
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0xFF77716A);
  static const line = Color(0xFFE8E2D9);
}

/// Shared interaction tokens for NORVÉ's light theme.
abstract final class NorveInteraction {
  static const hover = Color(0x0F24211E);
  static const focus = Color(0x1A24211E);
  static const pressed = Color(0x1A24211E);
  static const selected = Color(0x1424211E);
  static const disabled = NorveColors.muted;

  static Color? overlay(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return null;
    if (states.contains(WidgetState.pressed)) return pressed;
    if (states.contains(WidgetState.focused)) return focus;
    if (states.contains(WidgetState.hovered)) return hover;
    return null;
  }

  static WidgetStateProperty<Color?> get overlayProperty =>
      WidgetStateProperty.resolveWith(overlay);

  static WidgetStateProperty<Color?> foreground({
    required Color enabled,
    required Color disabled,
  }) => WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled) ? disabled : enabled,
  );
}

abstract final class NorveTheme {
  static ThemeData get light {
    final body = ThemeData(fontFamily: 'Inter').textTheme;
    const display = TextStyle(
      fontFamily: 'PlayfairDisplay',
      color: NorveColors.charcoal,
    );
    final brandedText = body.copyWith(
      displayLarge: display.copyWith(fontSize: 57),
      displayMedium: display.copyWith(fontSize: 45),
      displaySmall: display.copyWith(fontSize: 36),
      headlineLarge: display.copyWith(fontSize: 32),
      headlineMedium: display.copyWith(fontSize: 28),
      headlineSmall: display.copyWith(fontSize: 24),
      titleLarge: display.copyWith(fontSize: 22),
      titleMedium: display.copyWith(fontSize: 16),
      titleSmall: display.copyWith(fontSize: 14),
    );

    const scheme = ColorScheme.light(
      primary: NorveColors.charcoal,
      onPrimary: NorveColors.white,
      primaryContainer: NorveColors.ivory,
      onPrimaryContainer: NorveColors.charcoal,
      secondary: NorveColors.charcoal,
      onSecondary: NorveColors.white,
      secondaryContainer: NorveColors.ivory,
      onSecondaryContainer: NorveColors.charcoal,
      tertiary: NorveColors.charcoal,
      onTertiary: NorveColors.white,
      tertiaryContainer: NorveColors.ivory,
      onTertiaryContainer: NorveColors.charcoal,
      surface: NorveColors.ivory,
      onSurface: NorveColors.charcoal,
      surfaceTint: Colors.transparent,
      outline: NorveColors.line,
      outlineVariant: NorveColors.line,
      shadow: Colors.transparent,
      scrim: NorveColors.charcoal,
      inverseSurface: NorveColors.charcoal,
      onInverseSurface: NorveColors.white,
      inversePrimary: NorveColors.ivory,
    );

    final buttonOverlay = NorveInteraction.overlayProperty;
    const standardBorderRadius = BorderRadius.all(Radius.circular(4));
    const standardShape = RoundedRectangleBorder(
      borderRadius: standardBorderRadius,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: NorveColors.ivory,
      colorScheme: scheme,
      textTheme: brandedText.apply(
        bodyColor: NorveColors.charcoal,
        displayColor: NorveColors.charcoal,
      ),
      hoverColor: NorveInteraction.hover,
      focusColor: NorveInteraction.focus,
      splashColor: NorveInteraction.pressed,
      highlightColor: NorveInteraction.hover,
      disabledColor: NorveInteraction.disabled,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: NorveColors.ivory,
        foregroundColor: NorveColors.charcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      iconTheme: const IconThemeData(color: NorveColors.charcoal),
      dividerColor: NorveColors.line,
      dividerTheme: const DividerThemeData(
        color: NorveColors.line,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: NorveColors.charcoal,
        selectionColor: NorveInteraction.selected,
        selectionHandleColor: NorveColors.charcoal,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: NorveInteraction.foreground(
            enabled: NorveColors.charcoal,
            disabled: NorveColors.muted,
          ),
          overlayColor: buttonOverlay,
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: NorveInteraction.foreground(
            enabled: NorveColors.charcoal,
            disabled: NorveColors.muted,
          ),
          overlayColor: buttonOverlay,
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? NorveColors.line
                  : NorveColors.charcoal,
            ),
          ),
          shape: WidgetStatePropertyAll(standardShape),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          foregroundColor: NorveInteraction.foreground(
            enabled: NorveColors.white,
            disabled: NorveColors.muted,
          ),
          backgroundColor: NorveInteraction.foreground(
            enabled: NorveColors.charcoal,
            disabled: NorveColors.line,
          ),
          overlayColor: buttonOverlay,
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(standardShape),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: NorveInteraction.foreground(
            enabled: NorveColors.white,
            disabled: NorveColors.muted,
          ),
          backgroundColor: NorveInteraction.foreground(
            enabled: NorveColors.charcoal,
            disabled: NorveColors.line,
          ),
          overlayColor: buttonOverlay,
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(standardShape),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: NorveInteraction.foreground(
            enabled: NorveColors.charcoal,
            disabled: NorveColors.muted,
          ),
          overlayColor: buttonOverlay,
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NorveColors.ivory,
        surfaceTintColor: Colors.transparent,
        indicatorColor: NorveInteraction.selected,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? NorveColors.charcoal : NorveColors.muted,
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? NorveColors.charcoal : NorveColors.muted,
            size: 20,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: NorveColors.ivory,
        indicatorColor: NorveInteraction.selected,
        selectedIconTheme: const IconThemeData(color: NorveColors.charcoal),
        unselectedIconTheme: const IconThemeData(color: NorveColors.muted),
        selectedLabelTextStyle: const TextStyle(
          color: NorveColors.charcoal,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: NorveColors.muted,
          fontFamily: 'Inter',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: NorveColors.muted),
        hintStyle: const TextStyle(color: NorveColors.muted),
        prefixIconColor: NorveColors.muted,
        suffixIconColor: NorveColors.muted,
        floatingLabelStyle: const TextStyle(color: NorveColors.charcoal),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: NorveColors.charcoal, width: 1.5),
          borderRadius: standardBorderRadius,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: NorveColors.line),
          borderRadius: standardBorderRadius,
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: NorveColors.line),
          borderRadius: standardBorderRadius,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(color: NorveColors.charcoal),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(NorveColors.white),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(0),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: NorveColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        textStyle: TextStyle(color: NorveColors.charcoal),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: NorveColors.charcoal,
        unselectedLabelColor: NorveColors.muted,
        indicatorColor: NorveColors.charcoal,
        overlayColor: buttonOverlay,
        dividerColor: NorveColors.line,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? NorveColors.white
                : NorveColors.charcoal;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? NorveColors.charcoal
                : NorveColors.ivory;
          }),
          overlayColor: buttonOverlay,
          side: const WidgetStatePropertyAll(
            BorderSide(color: NorveColors.line),
          ),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return NorveColors.line;
          if (states.contains(WidgetState.selected)) {
            return NorveColors.charcoal;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(NorveColors.white),
        overlayColor: buttonOverlay,
        side: const BorderSide(color: NorveColors.muted),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return NorveColors.muted;
          return NorveColors.charcoal;
        }),
        overlayColor: buttonOverlay,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return NorveColors.muted;
          return states.contains(WidgetState.selected)
              ? NorveColors.ivory
              : NorveColors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return NorveColors.line;
          return states.contains(WidgetState.selected)
              ? NorveColors.charcoal
              : NorveColors.muted;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(NorveColors.line),
        overlayColor: buttonOverlay,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: NorveColors.charcoal,
        inactiveTrackColor: NorveColors.line,
        thumbColor: NorveColors.charcoal,
        overlayColor: NorveInteraction.focus,
        valueIndicatorColor: NorveColors.charcoal,
        valueIndicatorTextStyle: TextStyle(color: NorveColors.white),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: NorveColors.ivory,
        selectedColor: NorveInteraction.selected,
        disabledColor: NorveColors.ivory,
        checkmarkColor: NorveColors.charcoal,
        side: BorderSide(color: NorveColors.line),
        labelStyle: TextStyle(color: NorveColors.charcoal),
        secondaryLabelStyle: TextStyle(color: NorveColors.charcoal),
      ),
      cardTheme: const CardThemeData(
        color: NorveColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
