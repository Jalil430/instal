# Design Patterns for Consistent UI

This document outlines the established design patterns and conventions used throughout the application to ensure visual consistency and maintainable code.

## Typography System

### Font Sizes & Weights
- **14px**: Primary text size for most content (body text, table data, form inputs)
  - Weight: `FontWeight.w500` for emphasized content (client names, product names)
  - Weight: `FontWeight.w400` for regular content (amounts, dates)
- **13px**: Middle-ground text size for secondary information
  - Weight: `FontWeight.w400` for regular content
- **12px**: Small text for labels, hints, and secondary information
  - Weight: `FontWeight.w400` for regular content
  - Weight: `FontWeight.w400` for ALL CAPS labels (table headers, status labels)
- **16px**: Larger text for titles and important headings
  - Weight: `FontWeight.w500` or `FontWeight.w600`

### Text Color Hierarchy
- **Primary Text**: `AppTheme.textPrimary` - Main content, headings
- **Secondary Text**: `AppTheme.textSecondary` - Supporting information, labels
- **Interactive Text**: `AppTheme.interactiveBrightColor` - Links, clickable elements
- **Status Text**: Use appropriate status colors (success, warning, error)

### Typography Usage Examples
```dart
// Main content text (14px, w500)
Text(
  'Client Name',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontWeight: FontWeight.w500,
    fontSize: 14,
  ),
)

// Secondary information (14px, w400)
Text(
  '100 000 ₽',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontWeight: FontWeight.w400,
    fontSize: 14,
  ),
)

// Table headers (12px, w400, ALL CAPS)
Text(
  'КЛИЕНТ',
  style: Theme.of(context).textTheme.labelMedium?.copyWith(
    color: AppTheme.textSecondary,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    letterSpacing: 0.5,
  ),
)

// Small labels (12px, w400)
Text(
  'Срок оплаты',
  style: Theme.of(context).textTheme.bodySmall?.copyWith(
    color: AppTheme.textSecondary,
    fontSize: 12,
  ),
)
```

## Layout & Spacing System

### Container Spacing
- **Screen Padding**: 32px horizontal, 28px top, 20px bottom for main headers
- **Content Padding**: 32px horizontal, 12px vertical for table rows
- **Card Margins**: 16px horizontal for main content containers
- **Element Spacing**: 16px between major UI elements, 8px for related elements

### Border Radius Standards
- **Large Containers**: 12px (main content areas, cards)
- **Medium Elements**: 8px (buttons, input fields)
- **Small Elements**: 6px (status badges, small buttons)

### Layout Patterns
```dart
// Main content container
Container(
  margin: const EdgeInsets.symmetric(horizontal: 16),
  decoration: BoxDecoration(
    color: AppTheme.surfaceColor,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.02),
        offset: const Offset(0, 1),
        blurRadius: 3,
        spreadRadius: 0,
      ),
    ],
  ),
)

// Header section
Container(
  padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
  decoration: BoxDecoration(
    color: AppTheme.surfaceColor,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        offset: const Offset(0, 2),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ],
  ),
)
```

## Color System & Element Patterns

### Subtle Element Design Pattern
For interactive elements that need subtle primary color styling (search bars, dropdowns, buttons, table headers):

#### Primary Pattern
- **Background**: `AppTheme.subtleBackgroundColor` (primary color with 0.04 opacity)
- **Border**: `AppTheme.subtleBorderColor` (primary color with 0.1 opacity)

#### Hover States & Emphasis
- **Hover Background**: `AppTheme.subtleHoverColor` (primary color with 0.08 opacity)
- **Accent Elements**: `AppTheme.subtleAccentColor` (primary color with 0.15 opacity)

### Bright and Standing Out Elements Design Pattern
For elements that need to draw attention and stand out prominently (primary buttons, call-to-action elements, important links):

#### Primary Pattern
- **Primary Color**: `AppTheme.brightPrimaryColor` (full intensity primary color)
- **Secondary Color**: `AppTheme.brightSecondaryColor` (darker variant for depth/gradients)
- **Interactive Elements**: `AppTheme.interactiveBrightColor` (primary color for links, CTAs)

### Color Usage Rules
1. **Primary Bright Elements**: Call-to-action buttons, important links, active states
2. **Subtle Elements**: Search bars, dropdowns, table headers, secondary buttons
3. **Neutral Elements**: Regular text, backgrounds use white or grey shades
4. **Status Elements**: Use semantic colors (success, warning, error) with appropriate opacity

## Table Design Pattern

### Table Structure
- **Header**: Subtle background with ALL CAPS labels (12px, w400)
- **Rows**: Clean white/grey backgrounds with subtle borders
- **Hover States**: Light background change with subtle shadow
- **Expandable Rows**: Slightly different background color for expanded content

### Table Implementation
```dart
// Table header
Container(
  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  decoration: BoxDecoration(
    color: AppTheme.subtleBackgroundColor,
    border: Border(
      bottom: BorderSide(
        color: AppTheme.subtleBorderColor,
        width: 1,
      ),
    ),
  ),
)

// Table row with hover
Container(
  decoration: BoxDecoration(
    color: isHovered 
        ? AppTheme.backgroundColor.withOpacity(0.6)
        : AppTheme.surfaceColor,
    border: Border(
      bottom: BorderSide(
        color: AppTheme.borderColor.withOpacity(0.3),
        width: 1,
      ),
    ),
    boxShadow: isHovered ? [
      BoxShadow(
        color: AppTheme.primaryColor.withOpacity(0.08),
        offset: const Offset(0, 2),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ] : null,
  ),
)
```

## Interactive Elements

### Button Patterns
- **Primary Action**: Bright primary color with gradient and shadow
- **Secondary Action**: Subtle background with primary border
- **Small Actions**: 28x28px with subtle styling and hover states

### Status Badges
- **Fixed Width**: 110-120px for consistency
- **Rounded Corners**: 6px border radius
- **Color Coding**: Semantic colors with appropriate opacity

### Hover & Animation Standards
- **Duration**: 200ms for most hover transitions, 150ms for quick interactions
- **Curve**: `Curves.easeInOut` for smooth transitions
- **Opacity Changes**: Subtle (0.6-0.8 range) for background changes

## Form & Input Patterns

### Search Bars
- **Width**: 320px standard width
- **Styling**: Subtle background pattern
- **Placeholder**: Descriptive with context (e.g., "Поиск рассрочки...")

### Dropdowns
- **Width**: 200px standard width for sort/filter dropdowns
- **Styling**: Subtle background pattern matching search bars

## Empty States

### Design Pattern
- **Icon**: Large (56px) with subtle color and opacity
- **Container**: Gradient background with border
- **Text Hierarchy**: Title (headlineSmall) + description (bodyMedium)
- **Action Button**: Primary CTA with enhanced styling

### Implementation
```dart
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppTheme.textSecondary.withOpacity(0.05),
        AppTheme.textSecondary.withOpacity(0.02),
      ],
    ),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: AppTheme.textSecondary.withOpacity(0.1),
      width: 1,
    ),
  ),
)
```

## Animation & Transitions

### Standard Durations
- **Quick Interactions**: 150ms (button hovers, small state changes)
- **Standard Transitions**: 200ms (row hovers, expansion states)
- **Content Transitions**: 300ms (fade in/out, major state changes)
- **Staggered Animations**: Base duration + (index * 50ms) for list items

### Animation Curves
- **Ease In Out**: `Curves.easeInOut` - Standard for most transitions
- **Ease Out Cubic**: `Curves.easeOutCubic` - For content appearing
- **Ease In Cubic**: `Curves.easeInCubic` - For content disappearing

## Guidelines for Implementation

1. **Consistency First**: Always use established patterns before creating new ones
2. **Typography Hierarchy**: Stick to 12px, 13px, 14px, 16px sizes with defined weights
3. **Color Discipline**: Use bright for attention, subtle for interaction, neutral for content
4. **Spacing System**: Follow the 8px grid system (8, 12, 16, 20, 24, 28, 32px)
5. **Animation Consistency**: Use standard durations and curves
6. **Accessibility**: Maintain proper contrast ratios and touch target sizes

## Benefits

1. **Visual Consistency**: All screens follow the same design language
2. **Development Speed**: Predefined patterns reduce decision-making time
3. **Maintainability**: Centralized design tokens make updates easier
4. **User Experience**: Consistent interactions create intuitive interfaces
5. **Scalability**: New features can easily adopt existing patterns

## Documentation Updates

When adding new patterns:
1. Document the pattern with code examples
2. Explain when and why to use it
3. Include visual specifications (sizes, colors, spacing)
4. Update this document with new additions
5. Ensure patterns align with existing design system