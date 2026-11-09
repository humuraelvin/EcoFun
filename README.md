#  EcoStep

EcoStep is a gamified, eco-friendly mobile application built with **Flutter**. It is designed to encourage users to build sustainable habits, learn about environmental issues, and take real-world actions to combat climate change through a step-by-step daily routine.

---

##  Key Features

- **Daily Environmental News**
  Rwanda-focused English headlines come from a Google News RSS search; Kinyarwanda environmental stories are collected from Rebero and Izuba RSS feeds. EcoStep shows the feed summary and links to the publisher for the full story. Reading progress is tracked in the app.
  
-  **Educational Quizzes**
  Test your knowledge! After reading the daily news, users are prompted to take quick quizzes to reinforce what they've learned.

-  **Climate Missions**
  Take real-world action through daily eco-friendly tasks (e.g., "Use a reusable tumbler"). Complete missions by snapping a photo as proof and writing a short journal entry about your action.

-  **Streaks & History**
  Stay motivated by building a daily streak. The app features a home dashboard that tracks your consecutive days of completing routines and maintains a history of your past environmental contributions.

-  **Interactive Map**
  Explore your surroundings with an interactive map feature to discover local eco-friendly locations, community events, or recycling spots.

-  **User Profiles & Authentication**
  Secure and seamless login using Google Sign-In. The profile section tracks individual user progress, scores, and overall impact over time.

---

## Tech Stack & Architecture

This project is built using modern Flutter development practices and libraries:

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.8.1)
- **State Management & Routing**: [GetX](https://pub.dev/packages/get)
- **Dependency Injection**: [get_it](https://pub.dev/packages/get_it) & [injectable](https://pub.dev/packages/injectable)
- **Backend & Auth**: [Firebase Core](https://pub.dev/packages/firebase_core) & [Google Sign-In](https://pub.dev/packages/google_sign_in)
- **Data Models**: [Freezed](https://pub.dev/packages/freezed) & [json_serializable](https://pub.dev/packages/json_serializable)
- **Localization**: [easy_localization](https://pub.dev/packages/easy_localization)
- **Assets Generation**: [flutter_gen](https://pub.dev/packages/flutter_gen)
- **Hardware Integrations**: [image_picker](https://pub.dev/packages/image_picker), [permission_handler](https://pub.dev/packages/permission_handler), & Local Notifications.

---

## Folder Structure

The project follows a clean, feature-first folder structure located in `lib/`:

```text
lib/
 ┣ core/                # Shared utilities, DI, theming, and common widgets
 ┣ features/            # Feature modules
 ┃ ┣ auth/              # Google Sign-In and authentication logic
 ┃ ┣ climate_mission/   # Daily action tasks, camera integration, and journals
 ┃ ┣ history/           # User's completed missions and past activities
 ┃ ┣ home/              # Main dashboard, date selector, and streak tracking
 ┃ ┣ map/               # Interactive eco-map views
 ┃ ┣ news/              # Environmental news feeds and reading progress
 ┃ ┣ profile/           # User stats, settings, and sign-out
 ┃ ┗ quiz/              # Post-news educational quizzes
 ┣ gen/                 # Auto-generated asset files (flutter_gen)
 ┗ main.dart            # Application entry point
```

---

## Getting Started

### Prerequisites
- Flutter SDK (`^3.8.1` or higher)
- Dart SDK
- Android Studio / Xcode for emulators

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Flutter_EcoStep
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run code generation (Freezed, Injectable, etc.)**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Environment Setup**
   Ensure you have the required `.env` file inside `assets/config/.env` and the proper Firebase configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS) set up in their respective native directories.

5. **Run the app**
   ```bash
   flutter run
   ```

---

*EcoStep — Small steps today for a greener tomorrow! *
