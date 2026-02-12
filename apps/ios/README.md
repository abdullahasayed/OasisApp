# Oasis International Market iOS App

SwiftUI app with shopper and admin flows for pickup grocery ordering.

## What's ready now
- Branded UI refresh for Oasis International Market (red + jungle green + royal blue)
- Shopper flow: catalog, product details, cart, checkout, order tracking
- Admin flow: login, inventory stock updates, order status operations, fulfill/refund actions
- Demo mode (default in Debug) so the app is testable without backend setup
- Live API mode toggle in-app for backend testing

## Open in Xcode
A project file is now checked in:
- `apps/ios/OasisMarkets.xcodeproj`

Steps:
1. Open `apps/ios/OasisMarkets.xcodeproj`
2. Select the `OasisMarkets` scheme
3. Choose an iPhone simulator
4. Press Run

## Demo mode testing (no backend required)
- Demo mode is enabled by default for Debug builds.
- You can toggle Demo/Live from the app's main screen.
- Demo admin credentials:
  - Email: `admin@oasis.local`
  - Password: `OasisAdmin123!`

## Live backend testing
If you want real API calls:
1. Start API stack from repo root (`services/api` + database)
2. In app, switch off "Use Demo Data"
3. Ensure API base URL points to your backend (`ApiClient.swift` default is `http://localhost:4000`)

## Regenerate project (optional)
If you update `project.yml`:
1. Install XcodeGen: `brew install xcodegen`
2. From `apps/ios`: `xcodegen generate`
