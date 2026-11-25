# RaceDay Runner Mobile App

This is the Flutter mobile and web client for the RaceDay application.

## Before you start

Make sure you have:

- Flutter installed and available in your terminal.
- Docker Desktop running.
- The backend project available so you can run its Docker Compose file.

## Run the backend

From the backend project directory, start the API:

```powershell
docker compose -f deploy/docker-compose.yml --profile api up -d --build
```

The API listens on port `5080`.

## Run the app on a physical phone

The phone and the computer running the backend must be connected to the same Wi-Fi network.

### 1. Allow API traffic through Windows Firewall

Open PowerShell **as Administrator** and run:

```powershell
New-NetFirewallRule -DisplayName "Docker Backend 5080" -Direction Inbound -LocalPort 5080 -Protocol TCP -Action Allow
```

### 2. Find your computer's local IP address

Open Command Prompt and run:

```text
ipconfig
```

Under **Wireless LAN adapter Wi-Fi**, copy the **IPv4 Address**. For example:

```text
192.168.1.6
```

### 3. Configure the app

Create a file named `.env` in the project root. Set `API_URL` to your computer's IP address and port `5080`:

```text
API_URL=http://192.168.1.6:5080
```

Replace `192.168.1.6` with your own IPv4 address. Do not use `localhost` on a physical phone because it refers to the phone itself.

Start the Flutter app with your phone connected:

```powershell
flutter run
```

## Run the app on the web

### 1. Configure the API URL

In the project's `.env` file, use:

```text
API_URL=http://localhost:5080
```

### 2. Allow the web app in the backend

Copy the URL shown by Flutter when the web app starts, for example `http://localhost:xxxxx`, and add it to `ALLOWS_CORS` in the backend `.env` file.

### 3. Restart the backend

Run this command again from the backend project directory so the CORS setting is applied:

```powershell
docker compose -f deploy/docker-compose.yml --profile api up -d --build
```

Then start the Flutter web app:

```powershell
flutter run -d chrome
```

## Runner features

- Account registration, email OTP verification/resend, password recovery and password change.
- Event discovery, registration, medical document upload, payment and BIB/QR tickets.
- Profile editing and avatar upload (JPG/PNG/WEBP/GIF, up to 2MB).
- **Hoạt động** tab: BIB photo search, photo download/report, personal results,
  certificates, payment/refund history and complaints with evidence attachments.
- Event details and tickets link to the published leaderboard and the course map
  for each distance. Registration workflow and race status are displayed separately.
- Certificates are exported as PNG images after the API confirms eligibility.
- Refund requests are system-error claims awaiting verification; a quote is not an approved refund.

These features use the existing WebAPI contracts. BIB searches only return matched,
published photos. OCR processing and photo publication remain server/photographer tasks.
The backend's existing photo access rules still apply; BIB ownership is not restricted
by the mobile client. Course maps use OpenStreetMap tiles and need internet access.

## Android payment return

The Android app accepts `raceday://payment-return?registrationId=<uuid>`.
Opening a link only triggers an authenticated reload; URL payment statuses are never trusted.
An open checkout also refreshes when the app resumes.

For browser checkout to return to the Android app, host the bundled
`web/payment-return.html` on an HTTP/HTTPS origin reachable by the phone and configure:

```dotenv
PAYMENT_RETURN_URL=https://your-runner-host/payment-return.html
PAYMENT_CANCEL_URL=https://your-runner-host/payment-return.html
```

The app adds the registration ID and native-client flag automatically. The callback
page offers an **Mở ứng dụng RaceDay** link if the browser blocks automatic opening.
Without a hosted callback, return to the app manually and use **Kiểm tra thanh toán**.
No backend redirect endpoint is required. This repository currently has no iOS target;
the native return configuration here is for Android.

## Verification

```powershell
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

`test/runner_activity_test.dart` covers the added API contracts, account forms, photo
pagination/report retries, certificate eligibility, result publication, refund guards,
race statuses, callback validation and narrow/tablet layouts. Device file pickers,
live PayOS redirects, SMTP delivery and OCR accuracy require testing with their configured services.
