# Design Patterns for Consistent UI

This document outlines the established design patterns and conventions used throughout the application to ensure visual consistency and maintainable code.

## Subtle Element Design Pattern

For interactive elements that need subtle primary color styling (search bars, dropdowns, buttons, table headers), use these predefined constants instead of hardcoded opacity values:

### Primary Pattern
- **Background**: `AppTheme.subtleBackgroundColor` (primary color with 0.04 opacity)
- **Border**: `AppTheme.subtleBorderColor` (primary color with 0.1 opacity)

### Hover States & Emphasis
- **Hover Background**: `AppTheme.subtleHoverColor` (primary color with 0.08 opacity)
- **Accent Elements**: `AppTheme.subtleAccentColor` (primary color with 0.15 opacity)

### Usage Examples

#### Search Input Field
```dart
CustomSearchBar(
  value: searchQuery,
  onChanged: (value) => setState(() => searchQuery = value),
  hintText: 'Search items...',
  width: 320, // optional
  icon: Icons.search_rounded, // optional
)
```

#### Dropdown Container
```dart
Container(
  decoration: BoxDecoration(
    color: AppTheme.subtleBackgroundColor,
    border: Border.all(color: AppTheme.subtleBorderColor),
    borderRadius: BorderRadius.circular(12),
  ),
)
```

#### Table Header
```dart
Container(
  decoration: BoxDecoration(
    color: AppTheme.subtleBackgroundColor,
    border: Border(
      bottom: BorderSide(color: AppTheme.subtleBorderColor),
    ),
  ),
)
```

#### Hover States
```dart
Container(
  decoration: BoxDecoration(
    color: isHovered 
        ? AppTheme.subtleHoverColor 
        : AppTheme.subtleBackgroundColor,
    border: Border.all(
      color: isHovered 
          ? AppTheme.subtleAccentColor 
          : AppTheme.subtleBorderColor,
    ),
  ),
)
```

## Benefits

1. **Consistency**: All subtle elements follow the same visual pattern
2. **Maintainability**: Color changes only need to be made in AppTheme
3. **Readability**: Code is more self-documenting with descriptive property names
4. **Scalability**: Easy to extend with additional subtle color variations

## Guidelines

- Always use these constants instead of hardcoded `withOpacity()` calls
- For new interactive elements, follow this established pattern
- If you need different opacity levels, add them to AppTheme first
- Document any new patterns in this file 

## Bright and Standing Out Elements Design Pattern

For elements that need to draw attention and stand out prominently (primary buttons, call-to-action elements, important links), use these predefined constants:

### Primary Pattern
- **Primary Color**: `AppTheme.brightPrimaryColor` (full intensity primary color)
- **Secondary Color**: `AppTheme.brightSecondaryColor` (darker variant for depth/gradients)
- **Accent Color**: `AppTheme.brightAccentColor` (accent color for special highlights)

### Interactive Elements
- **Default State**: `AppTheme.interactiveBrightColor` (primary color)
- **Hover State**: `AppTheme.interactiveBrightHover` (darker primary for hover)
- **Shadow**: `AppTheme.interactiveBrightShadow` (primary with 0.3 opacity)

### Usage Examples

#### Primary Action Button
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [AppTheme.brightPrimaryColor, AppTheme.brightSecondaryColor],
    ),
    boxShadow: [
      BoxShadow(color: AppTheme.interactiveBrightShadow),
    ],
  ),
)
```

#### Interactive Link/Text
```dart
Text(
  'Client Name',
  style: TextStyle(
    color: AppTheme.interactiveBrightColor,
    decoration: TextDecoration.underline,
    decorationColor: AppTheme.interactiveBrightColor,
  ),
)
```

#### Status Indicator (Blue)
```dart
Container(
  decoration: BoxDecoration(
    color: AppTheme.pendingColor, // Matches primary for consistent blue
    // pendingColor is now set to primaryColor for consistency
  ),
)
```

## Color Consistency Rules

1. **Blue Elements**: All blue UI elements should use `AppTheme.primaryColor` or related variants
2. **Status Colors**: Blue status (pending) uses `AppTheme.pendingColor` which is set to `primaryColor`
3. **Interactive Elements**: Links, buttons, CTAs use the bright pattern colors
4. **Subtle Elements**: Background styling uses the subtle pattern colors

## Updated Guidelines

- Use bright pattern for attention-grabbing elements (buttons, links, CTAs)
- Use subtle pattern for background styling of interactive elements
- All blue colors should derive from the primary color for consistency
- Document any new color patterns in this file 