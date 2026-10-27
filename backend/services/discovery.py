import socket
from zeroconf import IPVersion, ServiceInfo, Zeroconf
import logging

class DiscoveryService:
    def __init__(self, port: int = 8000, name: str = "Servezy-Server"):
        self.port = port
        self.name = name
        self.zeroconf = None
        self.service_info = None

    def start(self):
        try:
            self.zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
            
            # Get local IP
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)
            
            # If for some reason we get localhost, try harder to get the real network IP
            if local_ip.startswith("127."):
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                try:
                    # doesn't even have to be reachable
                    s.connect(('10.255.255.255', 1))
                    local_ip = s.getsockname()[0]
                except Exception:
                    pass
                finally:
                    s.close()

            desc = {'version': '1.0.0', 'path': '/'}
            
            self.service_info = ServiceInfo(
                "_pos-api._tcp.local.",
                f"{self.name}._pos-api._tcp.local.",
                addresses=[socket.inet_aton(local_ip)],
                port=self.port,
                properties=desc,
                server=f"{hostname}.local.",
            )

            print(f"Broadcasting POS Discovery on {local_ip}:{self.port}...")
            self.zeroconf.register_service(self.service_info)
        except Exception as e:
            print(f"Failed to start discovery service: {e}")

    def stop(self):
        if self.zeroconf:
            if self.service_info:
                self.zeroconf.unregister_service(self.service_info)
            self.zeroconf.close()
            print("Discovery service stopped.")

# Global instance
discovery_manager = DiscoveryService()
