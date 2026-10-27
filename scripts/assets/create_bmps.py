from PIL import Image
source = r'C:\Users\shahs\.gemini\antigravity\brain\05bf50a1-bf60-404a-80af-73b4fda63480\media__1775741483218.jpg'

img = Image.open(source)

# Installer Wizard Image (Large)
# Standard: 164 x 314
wizard_large = img.resize((164, 314), Image.Resampling.LANCZOS)
wizard_large.save('frontend/app/assets/images/wizard_large.bmp', 'BMP')

# Installer Small Image
# Standard: 55 x 55
wizard_small = img.resize((55, 55), Image.Resampling.LANCZOS)
wizard_small.save('frontend/app/assets/images/wizard_small.bmp', 'BMP')

print("Installer-specific BMPs created.")
