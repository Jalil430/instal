# Project Structure

## Clean Architecture Pattern

The project follows Clean Architecture principles with clear separation of concerns:

```
lib/
├── core/                    # Shared infrastructure
├── features/               # Feature modules (domain-driven)
├── shared/                # Cross-cutting concerns
└── main.dart              # Application entry point
```

## Core Layer (`lib/core/`)

Infrastructure and cross-cutting concerns:

- **`api/`** - HTTP client and caching services
- **`theme/`** - App theming and design system
- **`routes/`** - Navigation configuration
- **`localization/`** - Internationalization setup
- **`widgets/`** - Core reusable widgets (AuthGuard)

## Feature Modules (`lib/features/`)

Each feature follows Clean Architecture layers:

```
features/[feature_name]/
├── data/
│   ├── datasources/       # Remote & local data sources
│   ├── models/           # Data transfer objects
│   └── repositories/     # Repository implementations
├── domain/
│   ├── entities/         # Business objects
│   ├── repositories/     # Repository contracts
│   ├── usecases/        # Business logic
│   └── services/        # Domain services
├── presentation/
│   ├── screens/         # UI screens
│   ├── widgets/         # Feature-specific widgets
│   └── providers/       # State management
└── screens/             # Legacy screen location
```

### Current Features

- **`auth/`** - Authentication and user management
- **`clients/`** - Client management and CRUD operations
- **`investors/`** - Investor portfolio management
- **`installments/`** - Payment tracking and schedules
- **`analytics/`** - Dashboard and reporting
- **`settings/`** - User preferences and configuration

## Shared Layer (`lib/shared/`)

Cross-cutting utilities and components:

- **`database/`** - SQLite database helper and migrations
- **`navigation/`** - Main layout and navigation structure
- **`widgets/`** - Reusable UI components (buttons, dialogs, forms)

## Backend Structure (`functions/`)

Serverless functions organized by domain:

```
functions/
├── auth-*/              # Authentication endpoints
├── create-*/           # Entity creation endpoints
├── get-*/              # Single entity retrieval
├── list-*/             # Entity listing endpoints
├── search-*/           # Search functionality
├── update-*/           # Entity updates
├── delete-*/           # Entity deletion
└── shared/             # Common utilities (JWT auth)
```

## Naming Conventions

### Files and Directories
- **Snake_case** for file names: `client_list_screen.dart`
- **Lowercase** for directory names: `lib/features/clients/`
- **Descriptive names** that indicate purpose and layer

### Classes and Functions
- **PascalCase** for classes: `ClientRepository`, `AuthService`
- **camelCase** for functions and variables: `getCurrentUser()`, `clientList`
- **Descriptive naming** that reflects business domain

### Feature Organization Rules

1. **Domain First**: Organize by business domain (clients, investors, installments)
2. **Layer Separation**: Keep data, domain, and presentation layers distinct
3. **Dependency Direction**: Dependencies flow inward (presentation → domain ← data)
4. **Single Responsibility**: Each file/class has one clear purpose

## File Naming Patterns

### Screens
- `[feature_name]_screen.dart` - Main feature screens
- `add_edit_[entity]_screen.dart` - Create/update forms
- `[entity]_details_screen.dart` - Detail views
- `[entity]_list_screen.dart` - List/table views

### Widgets
- `[entity]_list_item.dart` - List item components
- `custom_[component].dart` - Reusable UI components
- `[feature]_[widget_name].dart` - Feature-specific widgets

### Data Layer
- `[entity]_model.dart` - Data transfer objects
- `[entity]_repository_impl.dart` - Repository implementations
- `[entity]_remote_datasource.dart` - API data sources
- `[entity]_local_datasource.dart` - Local storage

### Domain Layer
- `[entity].dart` - Domain entities (business objects)
- `[entity]_repository.dart` - Repository contracts
- `[action]_[entity].dart` - Use cases (e.g., `create_client.dart`)

## Design System Integration

The project includes a comprehensive design system documented in `lib/core/theme/DESIGN_PATTERNS.md`:

- **Typography System**: Consistent font sizes (12px, 14px, 16px) and weights
- **Color Patterns**: Subtle and bright element styling
- **Layout Standards**: Spacing, borders, and container patterns
- **Component Patterns**: Tables, forms, buttons, and interactive elements

## API Integration

- **OpenAPI Specification**: `instal-api.yaml` defines all backend endpoints
- **RESTful Design**: Standard HTTP methods and resource-based URLs
- **JWT Authentication**: Bearer token authentication for protected endpoints
- **Error Handling**: Consistent error responses and client-side handling

## Development Guidelines

1. **Follow Clean Architecture**: Respect layer boundaries and dependency rules
2. **Use Design Patterns**: Reference `DESIGN_PATTERNS.md` for UI consistency
3. **Domain-Driven Design**: Organize code by business domains, not technical layers
4. **Single Source of Truth**: Keep business logic in domain layer use cases
5. **Testable Code**: Structure allows for easy unit and integration testing