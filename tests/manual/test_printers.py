import win32print
try:
    printers = win32print.EnumPrinters(2 | 4)
    print(f"Found {len(printers)} printers:")
    for p in printers:
        print(f" - {p[2]}")
except Exception as e:
    print(f"Error: {e}")
