# RoomEase UML Diagrams

This directory contains PlantUML diagrams for the RoomEase application.

## Diagrams

### Use Case Diagram
- **File**: `use-case-diagram.puml`
- **Description**: Shows all use cases and actors in the RoomEase system
- **Actors**: User, Roommate, Admin

### Activity Diagrams

#### 1. User Authentication
- **File**: `activity-user-authentication.puml`
- **Description**: Flow of user registration and login process
- **Key Flows**: Sign up, Login, Email verification

#### 2. Roomspace Management
- **File**: `activity-roomspace-management.puml`
- **Description**: Managing roomspaces (create, join, leave)
- **Key Flows**: Create roomspace, Join roomspace, Manage expenses

### Sequence Diagrams

#### 1. Login Flow
- **File**: `sequence-login.puml`
- **Description**: Detailed interaction between components during login
- **Components**: Flutter App, Firebase Auth, Go Backend, PostgreSQL

#### 2. Create Roomspace
- **File**: `sequence-create-roomspace.puml`
- **Description**: Process of creating a new roomspace
- **Components**: Flutter App, Go Backend, PostgreSQL

#### 3. Join Roomspace
- **File**: `sequence-join-roomspace.puml`
- **Description**: Process of joining an existing roomspace using Room ID
- **Components**: Flutter App, Go Backend, PostgreSQL

#### 4. Change Password
- **File**: `sequence-change-password.puml`
- **Description**: Password change flow using Firebase Authentication
- **Components**: Flutter App, Firebase Auth

## How to View

### Online
1. Copy the content of any `.puml` file
2. Go to [PlantUML Online Editor](http://www.plantuml.com/plantuml/uml/)
3. Paste the content and view the diagram

### VS Code
1. Install the "PlantUML" extension
2. Open any `.puml` file
3. Press `Alt+D` to preview

### Command Line
```bash
# Install PlantUML
brew install plantuml  # macOS
# or
sudo apt-get install plantuml  # Linux

# Generate PNG
plantuml use-case-diagram.puml

# Generate SVG
plantuml -tsvg use-case-diagram.puml
```

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
               │  (Supabase) │
               └─────────────┘
```

## Key Features Documented

1. **Authentication**: Firebase Auth + Backend session management
2. **Roomspace Management**: Create, join, and manage shared spaces
3. **User Management**: Profile, settings, password change
4. **Expense Tracking**: Add and split expenses (coming soon)
5. **Real-time Updates**: Notifications and member management (coming soon)

## Notes

- All diagrams follow PlantUML syntax
- Diagrams are version-controlled and should be updated with code changes
- Use these diagrams for documentation, presentations, and onboarding
