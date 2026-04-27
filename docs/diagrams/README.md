# RoomEase UML Diagrams

This folder contains PlantUML diagrams for the RoomEase application SRS documentation.

## Folder Structure

```
docs/diagrams/
├── auth/           # Authentication subsystem diagrams
├── roomspace/      # Roomspace management subsystem diagrams
├── expense/        # Expense management subsystem diagrams
├── notification/   # Notification & profile subsystem diagrams
├── analytics/      # Analytics & insights subsystem diagrams
├── structure/      # System-wide structural diagrams
├── README.md       # This file
└── DIAGRAMS_STATUS.md
```

---

## Subsystem Diagrams

### 1. Authentication (auth/)
| File | Type | Description |
|------|------|-------------|
| `1-use-case-auth.puml` | Use Case | Authentication use cases |
| `activity-signup.puml` | Activity | User signup flow |
| `activity-login.puml` | Activity | User login flow |
| `sequence-signup.puml` | Sequence | Signup sequence |
| `sequence-login.puml` | Sequence | Login sequence |
| `sequence-google-signin.puml` | Sequence | Google sign-in sequence |
| `auth-class-diagram.puml` | Class | Authentication class diagram |
| `dfd-authentication.puml` | DFD | Authentication data flow |

### 2. Roomspace Management (roomspace/)
| File | Type | Description |
|------|------|-------------|
| `2-use-case-roomspace.puml` | Use Case | Roomspace management use cases |
| `activity-create-roomspace.puml` | Activity | Create roomspace flow |
| `activity-join-roomspace.puml` | Activity | Join roomspace flow |
| `sequence-create-roomspace.puml` | Sequence | Create roomspace sequence |
| `sequence-join-roomspace.puml` | Sequence | Join roomspace sequence |
| `class-roomspace-subsystem.puml` | Class | Roomspace class diagram |
| `erd-roomspace-subsystem.puml` | ERD | Roomspace ERD |

### 3. Expense Management (expense/)
| File | Type | Description |
|------|------|-------------|
| `3-use-case-expense.puml` | Use Case | Expense management use cases |
| `activity-add-expense.puml` | Activity | Add expense flow |
| `sequence-add-expense.puml` | Sequence | Add expense sequence |
| `expense-class-diagram.puml` | Class | Expense class diagram |
| `expense-erd.puml` | ERD | Expense ERD |
| `expense-activity-create.puml` | Activity | Expense creation flow |
| `expense-activity-settlement.puml` | Activity | Settlement flow |
| `expense-balance-calculation-activity.puml` | Activity | Balance calculation |
| `expense-filtering-sequence.puml` | Sequence | Expense filtering |
| `expense-notification-sequence.puml` | Sequence | Expense notifications |
| `expense-sequence-balance-calculation.puml` | Sequence | Balance calc sequence |
| `expense-sequence-create.puml` | Sequence | Create expense sequence |
| `expense-sequence-settlement.puml` | Sequence | Settlement sequence |
| `expense-use-case-diagram.puml` | Use Case | Expense use cases |

### 4. Notifications (notification/)
| File | Type | Description |
|------|------|-------------|
| `6-use-case-notification.puml` | Use Case | Notification use cases |
| `7-use-case-profile.puml` | Use Case | User profile use cases |

### 5. Analytics (analytics/)
| File | Type | Description |
|------|------|-------------|
| `5-use-case-analytics.puml` | Use Case | Analytics use cases |
| `activity-view-analytics.puml` | Activity | View analytics flow |
| `sequence-analytics.puml` | Sequence | Analytics sequence |

### 6. Structure (system-wide)
| File | Type | Description |
|------|------|-------------|
| `class-diagram.puml` | Class | Overall system class diagram |
| `erd-database.puml` | ERD | Complete database ERD |
| `erd-auth-subsystem.puml` | ERD | Authentication subsystem ERD |
| `fdd-system.puml` | FDD | Functional decomposition diagram |

---

## Implemented Subsystems

| Code | Subsystem | Status |
|------|-----------|--------|
| AUTH | Authentication | ✅ Built |
| ROOM | Roomspace Management | ✅ Built |
| EXP | Expense Management | ✅ Built |
| NOTIF | Notifications | ✅ Built |
| PROF | User Profile | ✅ Built |
| ANL | Expense Analytics | ✅ Built |

---

## How to Generate Images

### Option 1: VS Code Extension (Recommended)
1. Install "PlantUML" extension
2. Open any `.puml` file
3. Press `Alt+D` to preview
4. Right-click → "Export Current Diagram"

### Option 2: Online Generator
1. Go to [PlantUML Web Server](http://www.plantuml.com/plantuml/uml/)
2. Paste the diagram code
3. Download PNG/SVG

### Option 3: Command Line
```bash
# Install PlantUML
# Windows: choco install plantuml
# Mac: brew install plantuml

# Generate all diagrams
plantuml *.puml

# Generate specific diagram as PNG
plantuml -tpng auth/sequence-login.puml

# Generate as SVG
plantuml -tsvg structure/erd-database.puml
```

---

## Notes

- All diagrams follow PlantUML syntax
- Diagrams are version-controlled and should be updated with code changes
- Use these diagrams for documentation, presentations, and onboarding
- OCR diagrams were removed as the feature is not implemented