# Card Scanner — Setup Guide

A simple Flutter app that opens the camera, lets you frame a card, and reads
its 16-digit number, expiry date, and (best-effort) cardholder name using
on-device OCR. No internet connection or paid API needed.

## 1. Create the Flutter project

If you don't already have a project, create one:

```
flutter create card_scanner_app
cd card_scanner_app
```

## 2. Copy in these files

Replace the generated `pubspec.yaml` with the one provided, and copy the
`lib/` folder (with its `screens/`, `utils/`, and `widgets/` subfolders) into
your project, replacing the default `lib/main.dart`.

## 3. Install the packages

```
flutter pub get
```

If any package fails to resolve (package versions move fast — by the time
you read this, newer ones may exist), just run this instead and Flutter will
pick the latest compatible versions automatically:

```
flutter pub add camera google_mlkit_text_recognition permission_handler
```

## 4. Android setup

**`android/app/build.gradle`** (or `build.gradle.kts`) — make sure the
minimum SDK version is at least 21:

```
defaultConfig {
    minSdkVersion 21
    ...
}
```

**`android/app/src/main/AndroidManifest.xml`** — add the camera permission
just above the `<application>` tag:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

## 5. iOS setup

**`ios/Runner/Info.plist`** — add a usage description (iOS requires this or
the app will crash when requesting camera access):

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan your card.</string>
```

## 6. Run it

```
flutter run
```

Tap "Scan a card", line the card up inside the white frame on a flat,
well-lit surface, and tap the capture button.

## How it works

1. **`camera`** opens the device's back camera and takes a photo when you
   tap the capture button.
2. **`google_mlkit_text_recognition`** (Google's on-device ML Kit) reads all
   the text visible in that photo — completely offline, free, and private
   to the device.
3. **`lib/utils/card_parser.dart`** scans that raw text with a few regular
   expressions to find: a 13-19 digit run (and prefers a 16-digit one that
   passes the Luhn checksum real card numbers use), an `MM/YY` expiry
   pattern, and the most plausible all-letters line for the cardholder name.
4. The result is shown on a simple card-shaped widget.

## Notes & limitations

- The name-extraction step is a heuristic (it picks the most plausible line
  of letters) — it works on most cards but won't be perfect on every design.
- CVV is deliberately **not** scanned. Real payment apps avoid reading it
  from a photo since it's meant to prove physical possession of the card,
  and there's no good reason to store or transmit it as an image.
- This app keeps everything on the device — it doesn't send the photo or any
  extracted text anywhere. If you build on this for a real product that
  needs to *use* the card number (e.g. to charge it), don't send the raw
  number to your own server: hand it directly to a payment processor's SDK
  (e.g. Stripe, Braintree) which tokenizes it, so your app/server never
  touches or stores the real card number. That also keeps you out of
  PCI-DSS scope, which is a substantial compliance burden otherwise.

## Possible easy upgrades

- Add `image_picker` if you'd like to test with a photo from the gallery
  instead of the live camera (handy on emulators without a working camera).
- Swap the regex-based parser for a purpose-built card-scanning SDK package
  if you want higher out-of-the-box accuracy at the cost of less control
  over the logic.
