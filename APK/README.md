# Motorcycle System - Pre-built Application Packages (APKs)

This directory contains production and testing Android Application Packages (APKs) ready to install on physical Android smartphones and tablets.

---

## Available Packages

| Package Name | Architecture | Build Type | Size | Description |
| :--- | :--- | :--- | :--- | :--- |
| **`motorcycle-system-flutter-release.apk`** | ARM64 / Universal | Release | ~45.0 MB | Full Flutter cross-platform HUD dashboard, live telemetry visualizers, predictive maintenance monitor, AI rider profiler, SOS blackbox, and UBI insurance scoring. |
| **`motorcycle-system-native-android-debug.apk`** | Universal | Debug | ~15.6 MB | Native Android Kotlin client with low-level Bluetooth ELM327 OBD-II protocol handler and embedded TensorFlow Lite edge inference models. |

---

## Installation Guide

1. Transfer the desired `.apk` file to your Android phone via USB cable, Google Drive, or by downloading directly from GitHub.
2. In Android Settings, enable **"Install unknown apps"** for your file manager or browser.
3. Tap on the `.apk` file and select **Install**.
4. Grant runtime permissions for:
   - **Bluetooth & Nearby Devices** (to connect to the ELM327 OBD-II scanner & BLE TPMS sensors).
   - **Location / GPS** (for IMU tilt tracking and road speed verification).
