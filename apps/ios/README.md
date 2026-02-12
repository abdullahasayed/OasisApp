# Oasis International Market iOS App

SwiftUI app scaffold for shopper and admin workflows.

## Features wired in code
- Shopper catalog by category
- Cart and checkout form (name + phone + slot)
- Order lookup by order number + phone
- Admin login
- Admin inventory list
- Admin order queue with status transitions and fulfill action
- Protocol-based payment and printer services for Stripe and Epson integration

## Generate Xcode project (recommended)
This repo includes source files but not a checked-in `.xcodeproj`.

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen)
2. From `apps/ios`, run:
   - `xcodegen generate`
3. Open `OasisMarkets.xcodeproj`
4. Set signing team and run on iPhone/iPad simulator

## API base URL
`ApiClient` defaults to `http://localhost:4000`. Change this in `ApiClient.swift` or inject a custom URL at app startup.
