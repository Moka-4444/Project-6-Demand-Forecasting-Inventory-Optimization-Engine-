# StockSense Mobile App 📈📱

A high-performance Flutter mobile application for real-time FMCG demand forecasting and inventory optimization.

## Features
- **Dynamic Theme Toggle**: Seamless dark/light mode switching with persistent state preservation across app restarts.
- **Role-Based Access**: Dedicated onboarding workflows and tailored dashboards for Manager and Staff roles.
- **120Hz Ultra-Smooth UI**: High refresh rate compatibility with custom sub-pixel aligned sparkline charts and glassmorphism cards.
- **Live Inventory Simulation**: Adjust safety stock, lead time, and service levels to compute reorder points and Economic Order Quantities (EOQ) on the fly.

## Getting Started

1. **Install Flutter Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run Locally:**
   ```bash
   flutter run
   ```

3. **Configure Backend Endpoint:**
   Update `lib/config/api_config.dart` to point to your running local FastAPI instance or live Azure App Service deployment.
