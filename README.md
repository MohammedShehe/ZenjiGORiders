# ZenjiGO Rider App (Frontend)

Premium ride-hailing Flutter app for Zanzibar (Unguja & Pemba).

## Features

- **Splash & Onboarding** – Animated logo, About Us, Language (EN/SW), Permissions
- **Authentication** – Phone + OTP (SMS/WhatsApp), full Sign Up with Zanzibar location hierarchy
- **Home** – Live map (flutter_map), nearby drivers, ride types (Boda/Bajaji/Taxi/Airport), fare estimate
- **Ride Details** – Driver info, call/chat/share, cancel & report
- **Wallet** – Balance, top-up with slider (+500), mobile money sources
- **Payments** – Cash, Mobile Money, Bank card (with live preview), ZenjiGO Wallet
- **In-App Chat** – WhatsApp-style, pinned ZenjiGO Support, translate toggle, 30-day auto-delete notice
- **Profile** – Edit info, ride history, saved locations, support contacts, language, dark/light mode, logout
- **Extras** – Parcel delivery, Tour packages, Promotions & offers
- **4 Bottom Tabs** – Home · Wallet · Chat · Profile
- **Themes** – Dark (default) & Light with custom ZenjiGO colors
- **i18n** – English & Kiswahili

## Run

```bash
cd zenjigo_riders
flutter pub get
flutter run
```

## Demo OTP

Any 4-digit code works (e.g. `1234`).

## Organization

- Phone: +255 676 891 227
- Email: zenjigo@support.com
- Instagram: @zenjigo

## Notes

- Frontend only – all data is mocked
- Map uses free Carto tiles (no API key required)
- Logos included in `assets/logos/`
