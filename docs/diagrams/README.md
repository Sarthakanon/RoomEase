# RoomEase UML Diagrams

This folder contains PlantUML diagrams for the RoomEase application SRS documentation.

## Diagram Order (as per SRS Sample)
1. Activity Diagrams
2. Use Case Diagrams
3. Wireframes (external)
4. ERD
5. Data Dictionary (in SRS document)
6. Class Diagram
7. Sequence Diagrams

---

## 1. Use Case Diagrams (7 - one per subsystem)

| File | Subsystem | Description |
|------|-----------|-------------|
| `1-use-case-auth.puml` | AUTH | Authentication use cases |
| `2-use-case-roomspace.puml` | ROOM | Roomspace management use cases |
| `3-use-case-expense.puml` | EXP | Expense management use cases |
| `4-use-case-ocr.puml` | OCR | OCR bill scanner use cases |
| `5-use-case-analytics.puml` | ANL | Analytics use cases |
| `6-use-case-notification.puml` | NOTIF | Notification use cases |
| `7-use-case-profile.puml` | PROF | User profile use cases |

---

## 2. Activity Diagrams (one per functional requirement)

| File | Requirement | Description |
|------|-------------|-------------|
| `activity-signup.puml` | AUTH-F-1.0 | User signup flow |
| `activity-login.puml` | AUTH-F-1.1 | User login flow |
| `activity-create-roomspace.puml` | ROOM-F-1.0 | Create roomspace flow |
| `activity-join-roomspace.puml` | ROOM-F-2.0 | Join roomspace flow |
| `activity-add-expense.puml` | EXP-F-1.0 | Add expense flow |
| `activity-ocr-scan.puml` | OCR-F-2.0 | OCR bill scanning flow |
| `activity-view-analytics.puml` | ANL-F-1.0 | View analytics flow |

---

## 3. Sequence Diagrams

| File | Feature | Description |
|------|---------|-------------|
| `sequence-login.puml` | Login | User login sequence |
| `sequence-create-roomspace.puml` | Create Room | Create roomspace sequence |
| `sequence-join-roomspace.puml` | Join Room | Join with approval sequence |
| `sequence-add-expense.puml` | Add Expense | Add expense with notification |
| `sequence-ocr-scan.puml` | OCR Scan | OCR processing sequence |
| `sequence-analytics.puml` | Analytics | View analytics sequence |

---

## 4. Structural Diagrams

| File | Type | Description |
|------|------|-------------|
| `fdd-system.puml` | FDD | Functional Decomposition Diagram |
| `erd-database.puml` | ERD | Entity Relationship Diagram |
| `class-diagram.puml` | Class | Application class diagram |

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
plantuml -tpng sequence-login.puml

# Generate as SVG
plantuml -tsvg erd-database.puml
```

---

## Subsystem Summary

| Code | Subsystem | Status |
|------|-----------|--------|
| AUTH | Authentication | ✅ Built |
| ROOM | Roomspace Management | ✅ Built |
| NOTIF | Notifications | ✅ Built |
| PROF | User Profile | ✅ Built |
| EXP | Expense Management | 🔄 Partial |
| OCR | OCR Bill Scanner | ❌ Pending |
| ANL | Expense Analytics | ❌ Pending |

---

## Architecture Overview

```
┌─────────────┐
│ Flutter App │
│  (Mobile)   │
└──────┬──────┘
       │
       ├─────────────┐
       │             │
┌──────▼──────┐ ┌───▼────────┐
│  Firebase   │ │ Go Backend │
│    Auth     │ │  (REST API)│
└─────────────┘ └─────┬──────┘
                      │
               ┌──────▼──────┐
               │ PostgreSQL  │
               │  Database   │
               └─────────────┘
```

---

## Notes

- All diagrams follow PlantUML syntax
- Diagrams are version-controlled and should be updated with code changes
- Use these diagrams for documentation, presentations, and onboarding
- SRS document location: `.kiro/specs/SRS_RoomEase.md`
