'''
Docstring for src.config.load_indexes

This module is responsible for loading and managing indexes used in the application.


'''
from src.config import  env_settings
from src.utils import read_json_from_s3, load_index_from_local


class IndexLoader:

    def __init__(self):
        print("Loading manifest from S3...")
        self.manifest = self.load_manifest()

        print("Loading index from S3...")
        # self.indexes = load_index_from_local("../data/index.json")
        self.indexes = self.load_indexes()

        print("Building search index...")
        # Store original keys (for returning results)
        self.sorted_keys = list(self.indexes.keys())
        # Store lowercase keys (for fast case-insensitive search)
        self.sorted_keys_lower = [k.lower() for k in self.sorted_keys]

        print(f"✓ Index ready: {len(self.indexes):,} entries")

    def load_manifest(self) -> dict:
        try:
            return read_json_from_s3(
                bucket_name=env_settings.bucket_name,
                file_name="manifest.json"
            )
        except Exception as e:
            print(f"Error loading manifest: {e}")
            raise e
    
    def load_indexes(self) -> dict:
        index_key = self.manifest["index_file_path"]

        if not index_key:
            raise ValueError("Index file path not found in manifest.")

        try:
            return read_json_from_s3(
                bucket_name=env_settings.bucket_name,
                file_name=index_key
            )
        except Exception as e:
            print(f"Error loading index from S3: {e}")
            raise e

    def get_value_by_key(self, key: str) -> dict | None:
        return self.indexes.get(key, None)
    
    def autosuggest_keys(self, query: str, max_suggestions: int = 10, case_sensitive: bool = False) -> list[str]:
        """Return a list of keys that start with the given query string."""
        if not query:
            return []

        suggestions = []
        query_to_check = query if case_sensitive else query.lower()
        keys_to_search = self.sorted_keys if case_sensitive else self.sorted_keys_lower

        # Binary search for leftmost position >= query
        low, high = 0, len(keys_to_search)
        while low < high:
            mid = (low + high) // 2
            if keys_to_search[mid] < query_to_check:
                low = mid + 1
            else:
                high = mid

        start_index = low

        # Collect suggestions
        for i in range(start_index, min(start_index + max_suggestions, len(keys_to_search))):
            if keys_to_search[i].startswith(query_to_check):
                suggestions.append(self.sorted_keys[i])
            else:
                break  # No more matches

        return suggestions


# Lazy initialization - don't create instance at module load
_index_loader: IndexLoader | None = None


def get_index_loader() -> IndexLoader:
    """
    Get or create the singleton IndexLoader instance.
    This lazy initialization allows for proper error handling during startup.
    """
    global _index_loader
    if _index_loader is None:
        _index_loader = IndexLoader()
    return _index_loader


if __name__ == "__main__":
    # Get the loader instance
    loader = get_index_loader()

    # Test exact lookup
    print("\n=== Exact Lookup Test ===")
    result = loader.get_value_by_key("a join western")
    print(f"'a join western': {result}")

    # Test autosuggest
    print("\n=== Autosuggest Test ===")
    suggestions = loader.autosuggest_keys("app", max_suggestions=50)
    print(f"Suggestions for 'app': {suggestions}")

    suggestions = loader.autosuggest_keys("a ", max_suggestions=10)
    print(f"\nSuggestions for 'a ': {suggestions}")

    # Test case sensitivity
    suggestions_case = loader.autosuggest_keys("A", max_suggestions=5, case_sensitive=True)
    print(f"\nCase-sensitive 'A': {suggestions_case}")
    
