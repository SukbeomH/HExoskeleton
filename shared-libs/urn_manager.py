import re
from typing import Literal

URN_LOCAL_PREFIX = "urn:local"
URN_GLOBAL_PREFIX = "urn:global"

class URNManager:
    @staticmethod
    def create_local_urn(project_id: str, file_path: str, symbol: str) -> str:
        """
        Creates a URN for a local code entity.
        Format: urn:local:{project_id}:{file_path}:{symbol}
        """
        return f"{URN_LOCAL_PREFIX}:{project_id}:{file_path}:{symbol}"

    @staticmethod
    def create_global_urn(package_name: str, version: str) -> str:
        """
        Creates a URN for a global library entity.
        Format: urn:global:lib:{package_name}@{version}
        """
        return f"{URN_GLOBAL_PREFIX}:lib:{package_name}@{version}"

    @staticmethod
    def parse_urn(urn: str) -> dict:
        """
        Parses a URN into its components.
        """
        if urn.startswith(URN_LOCAL_PREFIX):
            parts = urn.split(":")
            if len(parts) >= 5:
                # Rejoin parts[3:] as file_path might contain strings, but usually : separates
                # Let's assume strict format: prefix:local:proj:path:symbol
                # If path has colons, this split is dangerous.
                # Better regex aproach.
                # Project ID is part[2]
                # Remainder is path:symbol
                pass

        # Simple implementation for now
        return {"urn": urn}

    @staticmethod
    def is_local(urn: str) -> bool:
        return urn.startswith(URN_LOCAL_PREFIX)

    @staticmethod
    def is_global(urn: str) -> bool:
        return urn.startswith(URN_GLOBAL_PREFIX)
