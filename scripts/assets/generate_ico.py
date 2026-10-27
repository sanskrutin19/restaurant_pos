"""Generate a proper multi-resolution .ico file from the logo PNG."""
from PIL import Image
import os

logo_path = os.path.join("frontend", "app", "assets", "images", "logo.png")
img = Image.open(logo_path)

# Convert to RGBA (ico needs alpha channel)
if img.mode != 'RGBA':
    img = img.convert('RGBA')

# Make it square by padding the shorter dimension
max_dim = max(img.size)
square = Image.new('RGBA', (max_dim, max_dim), (0, 0, 0, 0))
offset = ((max_dim - img.size[0]) // 2, (max_dim - img.size[1]) // 2)
square.paste(img, offset)

# Generate all standard Windows icon sizes
sizes = [16, 24, 32, 48, 64, 128, 256]

# Save to Windows runner resources
ico_path = os.path.join("frontend", "app", "windows", "runner", "resources", "app_icon.ico")
square.save(ico_path, format='ICO', sizes=[(s, s) for s in sizes])

# Also save a copy to the project root for the server exe
square.save("app_icon.ico", format='ICO', sizes=[(s, s) for s in sizes])

print(f"Generated ICO at: {ico_path}")
print(f"ICO file size: {os.path.getsize(ico_path)} bytes")
print(f"Root ICO file size: {os.path.getsize('app_icon.ico')} bytes")
