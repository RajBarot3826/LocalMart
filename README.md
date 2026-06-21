# 🛍️ LocalMart

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

LocalMart is a modern, beautifully designed hyper-local e-commerce and retail aggregation application built with Flutter. It connects users to local businesses, offering a seamless shopping experience with dynamic multilingual support, offline capabilities, and a polished user interface.

## ✨ Key Features

- **🌍 Multilingual Localization**: True dynamic translation supporting English, Hindi, and Gujarati. Not only static UI text, but dynamic API content (Product Specs, Store Names, Addresses) are seamlessly translated on the fly.
- **📱 Modern UI/UX**: Built using cutting-edge Flutter design patterns including `CustomScrollView`, `SliverAppBar`, fading hero animations, glassmorphism, and responsive layouts.
- **🛒 Dynamic Product Specifications**: Fully flexible product details engine. Whether the backend sends specifications for Electronics (Brand, RAM, Warranty) or Groceries (Weight, Shelf Life), the app automatically builds and translates the UI.
- **🌙 Theming**: Consistent color palette and typography utilizing an engineered `AppTheme` for scalable dark and light mode implementations.
- **📞 Direct Store Communication**: Built-in intents for calling the store owner and sharing the store's deep link / details using the native share sheet.
- **📶 Offline Resilience**: Built-in network state handling with offline indicators and local fallback data handling.

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter (Dart)
- **Architecture**: Scalable component-based widget tree with separated models, screens, and utility layers.
- **State Management**: InheritedWidgets / Stateful patterns optimized for performant rebuilds.
- **Networking**: Configured API handler ready for RESTful backend integration.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / Xcode

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/localmart.git
   ```
2. Navigate into the directory:
   ```bash
   cd localmart
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the application:
   ```bash
   flutter run
   ```

## 📂 Project Structure

```text
lib/
├── models/         # Data structures and JSON serialization
├── screens/        # Full screen views (Home, Store, Product Detail, etc.)
├── theme/          # Centralized color palettes and typography
├── utils/          # Helpers, API handlers, and the Locale translation engine
├── widgets/        # Reusable UI components (StoreCards, AppBars, etc.)
└── main.dart       # App entry point
```

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! 
Feel free to check [issues page](#) if you want to contribute.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Built with ❤️ for the local retail ecosystem.*
