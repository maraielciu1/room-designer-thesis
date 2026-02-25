# App Icon Setup Instructions

To set your app icon (the armchair and lamp icon) as the app logo:

## Step 1: Prepare Your Icon Image
1. You need a 1024x1024 pixel version of your icon image
2. Save it as a PNG file (e.g., `app-icon.png`)

## Step 2: Add to Xcode
1. Open your project in Xcode
2. Navigate to `RoomScanTest/Assets.xcassets/AppIcon.appiconset/`
3. In Xcode, click on `AppIcon` in the Assets catalog
4. You'll see three slots:
   - **iOS App Icon** (1024x1024) - Universal
   - **iOS App Icon** (1024x1024) - Dark appearance
   - **iOS App Icon** (1024x1024) - Tinted appearance

## Step 3: Drag and Drop
1. Drag your 1024x1024 icon image into the first slot (Universal)
2. Optionally, drag the same image (or a dark variant) into the Dark appearance slot
3. Optionally, drag the same image (or a tinted variant) into the Tinted appearance slot

## Step 4: Alternative Method (Manual)
If dragging doesn't work:
1. Copy your icon image file to: `RoomScanTest/Assets.xcassets/AppIcon.appiconset/`
2. Rename it to something like `app-icon-1024.png`
3. Edit `Contents.json` to reference your image file

## Step 5: Build and Run
1. Clean build folder (Cmd+Shift+K)
2. Build and run (Cmd+R)
3. The icon should appear on your home screen

## Notes:
- The icon must be exactly 1024x1024 pixels
- Use PNG format (no transparency for app icons)
- The icon will automatically be resized for different device sizes
- After adding the icon, you may need to delete the app from your device and reinstall to see the new icon
