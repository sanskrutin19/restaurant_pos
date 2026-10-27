import hashlib
import platform
import subprocess
import os


def _load_secret_salt():
    """
    The license salt is kept out of source control.
    Lookup order:
      1. SERVEZY_LICENSE_SALT environment variable
      2. backend/services/_license_secret.py (gitignored, bundled by PyInstaller)
    """
    salt = os.environ.get("SERVEZY_LICENSE_SALT")
    if salt:
        return salt
    try:
        from backend.services._license_secret import SECRET_SALT
        return SECRET_SALT
    except ImportError:
        return None


class LicenseManager:
    # A secret salt unique to your company. DON'T SHARE THIS.
    SECRET_SALT = _load_secret_salt()

    @staticmethod
    def get_machine_id():
        """Generates a unique hardware ID for this PC."""
        try:
            # Try to get motherboard UUID on Windows
            if platform.system() == "Windows":
                # Modern PowerShell approach (wmic is deprecated)
                try:
                    cmd = 'powershell -Command "(Get-CimInstance -ClassName Win32_ComputerSystemProduct).UUID"'
                    uuid = subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode().strip()
                    if uuid and uuid.lower() not in ("", "none", "to be filled by o.e.m."):
                        return uuid
                except Exception:
                    pass
                
                # Fallback: Windows Machine GUID from registry
                try:
                    cmd = 'reg query "HKLM\\SOFTWARE\\Microsoft\\Cryptography" /v MachineGuid'
                    output = subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode()
                    for line in output.split('\n'):
                        if 'MachineGuid' in line:
                            guid = line.split()[-1].strip()
                            if guid:
                                return guid.upper()
                except Exception:
                    pass
            
            # Fallback to node/processor info
            fallback = platform.node() + platform.processor() + platform.machine()
            return hashlib.sha256(fallback.encode()).hexdigest()[:16].upper()
        except Exception:
            return "UNAVAILABLE-ID"

    @staticmethod
    def generate_license_key(machine_id: str):
        """
        The algorithm to generate a key from an ID.
        You will use this in your private generator app.
        """
        if not LicenseManager.SECRET_SALT:
            raise RuntimeError(
                "License salt not configured. Set SERVEZY_LICENSE_SALT or create "
                "backend/services/_license_secret.py (see backend/services/_license_secret.example.py)."
            )
        raw = f"{machine_id}-{LicenseManager.SECRET_SALT}"
        # Create a 16-character alphanumeric key
        full_hash = hashlib.sha256(raw.encode()).hexdigest().upper()
        # Format as XXXX-XXXX-XXXX-XXXX
        return f"{full_hash[0:4]}-{full_hash[4:8]}-{full_hash[8:12]}-{full_hash[12:16]}"

    @staticmethod
    def verify_key(machine_id: str, key: str):
        """Checks if the key matches the machine fingerprint."""
        if not LicenseManager.SECRET_SALT:
            return False
        # Remove dashes for comparison
        clean_key = key.replace("-", "").upper()
        expected_key = LicenseManager.generate_license_key(machine_id).replace("-", "").upper()
        return clean_key == expected_key

# Global instance for validation
license_manager = LicenseManager()
