# Play Store Deployment Guide (Soko Seller Terminal)

This guide outlines the steps to build and deploy the production release of the Seller Terminal.

## 1. Generate Production Keystore (One-time setup)
You need a cryptographic key to sign the app. **Keep this file safe!** If you lose it, you cannot update your app on the Play Store.

Run the following command in your terminal:

```bash
cd /var/www/soko/app/soko_seller_terminal/android

keytool -genkey -v -keystore release-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias soko-seller-release
```
*Follow the prompts. Remember the passwords you set.*

## 2. Configure `key.properties`
Create a new file at `android/key.properties` (this file is ignored by git for security):

```properties
storeFile=release-keystore.jks
storePassword=<YOUR_STORE_PASSWORD>
keyAlias=soko-seller-release
keyPassword=<YOUR_KEY_PASSWORD>
```

## 3. Build Release Bundle (AAB)
We have a helper script that runs preflight checks (tests, analysis) and builds the signed bundle.

```bash
cd /var/www/soko/app/soko_seller_terminal
bash scripts/build_release_aab.sh
```

If successful, you will see:
`✅ Build complete: build/app/outputs/bundle/release/app-release.aab`

## 4. Upload to Google Play Console
1.  Go to [Google Play Console](https://play.google.com/console).
2.  Select **Soko Seller Terminal**.
3.  Go to **Testing > Internal testing** (recommended for first test) or **Production**.
4.  Click **Create new release**.
5.  Upload the `app-release.aab` file generated in Step 3.
6.  Update release notes and Save.

## 5. Troubleshooting
- **Keystore not found**: Ensure `storeFile` in `key.properties` matches the filename in `android/`.
- **Wrong password**: Double-check passwords in `key.properties`.
- **Version code conflict**: If Play Console says "Version code 1 already exists", edit `pubspec.yaml` and increment the version (e.g., `1.0.1+2` -> `+2` is the version code).
