from PIL import Image
import os

source = r'C:\Users\shahs\.gemini\antigravity\brain\05bf50a1-bf60-404a-80af-73b4fda63480\media__1775741483218.jpg'
dest_app = 'frontend/app/assets/images/logo.png'
dest_deploy = 'DEPLOY/POS_Terminal/data/flutter_assets/assets/images/logo.png'

# Load the JPG
img = Image.open(source)

# Save as proper PNG for the App
img.save(dest_app, 'PNG')
img.save(dest_deploy, 'PNG')

# Create a specialized version for the Installer if needed
# Inno Setup can be finicky with PNG depths, let's try a standard BMP if IS still complains, 
# but a clean PNG conversion usually works.
print("Image converted to proper PNG format.")
