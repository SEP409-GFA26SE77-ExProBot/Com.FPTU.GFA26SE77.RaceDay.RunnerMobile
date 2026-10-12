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
