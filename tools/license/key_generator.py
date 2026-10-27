# DO NOT SHARE THIS TOOL'S OUTPUT WITH ANYONE BUT THE LICENSED CUSTOMER.
# Private tool to generate license keys. The salt is read by LicenseManager from
# SERVEZY_LICENSE_SALT or backend/services/_license_secret.py (never committed).
#
# Run from the repo root:  python -m tools.license.key_generator

from backend.services.license import LicenseManager


if __name__ == "__main__":
    print("-" * 40)
    print(" SERVEZY POS - LICENSE KEY GENERATOR")
    print("-" * 40)

    mid = input("\nEnter Customer's Machine ID: ").strip().upper()
    if mid:
        license_key = LicenseManager.generate_license_key(mid)
        print(f"\nSUCCESS! Generated License Key:")
        print(f">>> {license_key} <<<")
        print("\nGive this key to your customer.")
    else:
        print("Error: Machine ID cannot be empty.")

    input("\nPress Enter to exit...")
