# Excel Data Finder & Franchise Manager (Demo)

Flutter Android project. Features:
- Import multiple `.xlsx` Excel workbooks (local device storage).
- Search all imported rows by mobile number OR CNIC.
- Attempts to identify Mobile/Phone and CNIC columns from header names; otherwise searches all cells.
- Shows matching rows with source filename and row values.
- Demo login screen (default username `admin`, password `1234`).

## Build APK using GitHub
1. Create a new GitHub repository.
2. Upload the contents of this ZIP (not the enclosing folder) to the repository root.
3. Open **Actions** and run **Build Excel Finder APK** (or push to `main`).
4. Download the `excel-franchise-finder-apk` artifact from the completed workflow.
5. Extract it and install `app-release.apk` on Android.

## Notes
- This is a demo starter project. Imported data is stored locally on the Android device.
- Use `.xlsx` files. Legacy `.xls` files should be saved as `.xlsx` in Excel first.
- Header recognition supports common English/Urdu variants; if a header isn't recognized, the app searches all cells as a fallback.
- The demo login is not production-grade authentication. Do not use sensitive real customer data until secure authentication, encryption, and backups are added.
