# ZenjiGO Rider — Flutter Frontend

A polished frontend prototype for the ZenjiGO rider app, designed to match the ZenjiGO Driver visual system.

## Included flows

- Dark mode by default + full light mode
- English / Kiswahili UI preference
- Onboarding, location permissions and rider registration
- Zanzibar location hierarchy and profile setup
- Four-tab shell: Home, Wallet, Chat, Profile
- Map-based ride booking with Boda, Bajaji, Taxi, Airport and Parcel services
- Nearby-driver map markers and ride lifecycle simulation
- Driver acceptance, approach, arrival, live trip progress and receipt
- Ride cancellation and driver reporting flows
- Driver chat and ZenjiGO Support chat
- WhatsApp-style replies, message selection/deletion, edit, copy, emoji and translation preview
- Saved locations and ride history
- Promotions and referral flows
- Payment method management
  - Mobile Money: M-Pesa, Mix by Yas, Airtel Money, HaloPesa
  - Bank Card
  - Default payment method management
  - Validation and confirmation states
  - Safe deletion rules
- ZenjiGO Wallet
  - Top-up amount selection
  - Saved payment method selection
  - Add-payment flow directly from top-up
  - Simulated secure processing + success receipt
  - Transaction history
- Responsive dark/light styling using the same ZenjiGO palette and typography family as the Driver app

## Frontend/backend boundary

This project intentionally contains frontend/demo state only. Payment gateways, OTP delivery, production maps/geocoding, real-time sockets, push notifications and backend persistence should be connected through the existing provider/state layer when the backend APIs are ready.

## Run

```bash
flutter pub get
flutter analyze
flutter run
```
