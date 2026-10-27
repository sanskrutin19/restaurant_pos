import os
import shutil
import sys

# Path to the persistent data folder
appdata = os.environ.get('APPDATA')
if appdata:
    target_dir = os.path.join(appdata, "Servezy")
    if os.path.exists(target_dir):
        print(f"Removing legacy data at: {target_dir}")
        try:
            shutil.rmtree(target_dir)
            print("Successfully cleared legacy data! The next time you run the app, the FIXED menu will be loaded.")
        except Exception as e:
            print(f"Error: Could not remove folder (it might be in use). Please close the Servezy app and try again. {e}")
    else:
        print("No legacy data found in AppData/Roaming/Servezy.")
else:
    print("Could not find APPDATA environment variable.")
