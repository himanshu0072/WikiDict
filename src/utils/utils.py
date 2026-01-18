import boto3
from src.config.settings import env_settings, app_settings
import json
from functools import lru_cache
from botocore.exceptions import ClientError, NoCredentialsError, PartialCredentialsError
from src.errors import (
    NotFoundException,
    InternalServerException,
    ServiceUnavailableException
)

def get_s3_client(read_timeout:int = 30):
    """Create and return an S3 client with credentials from environment settings."""
    from botocore.config import Config

    # Configure client with connection pooling and timeouts
    config = Config(
        retries={'max_attempts': 3, 'mode': 'adaptive'},
        connect_timeout=5,
        read_timeout=read_timeout,
        max_pool_connections=50
    )

    return boto3.client(
        "s3",
        aws_access_key_id=env_settings.access_key,
        aws_secret_access_key=env_settings.secret_key,
        region_name=env_settings.region,
        config=config
    )
def read_json_from_s3(bucket_name: str, file_name: str):
    """Read a JSON file from S3 and return its content."""
    s3_client = get_s3_client(120)
    response = s3_client.get_object(
        Bucket=bucket_name,
        Key=file_name
    )
    content = response['Body'].read().decode('utf-8')
    data = json.loads(content)
    return data

def _read_meaning_from_s3_uncached(offset: int, length: int, file_key: str) -> str:
    """
    Internal function to read meaning text from S3 using byte offset and length.
    This function is wrapped with LRU cache based on configuration.

    Args:
        offset: Byte offset where the meaning starts in the file
        length: Number of bytes to read
        file_key: S3 file key/path

    Returns:
        str: The meaning text extracted from the specified byte range
    """
    bucket_name = env_settings.bucket_name
    if not bucket_name or not bucket_name.strip():
        raise InternalServerException(
            detail="Bucket is not configured properly. Please contact to administrator"
        )

    if not file_key or not file_key.strip():
        raise NotFoundException(
            detail="File path not found in manifest. Please contact to administrator",
            resource="S3 Object"
        )

    # Use the module-level S3 client for connection reuse
    s3_client = get_s3_client()

    # Calculate the byte range: bytes=start-end (end is inclusive in S3)
    byte_range = f"bytes={offset}-{offset + length - 1}"

    try:
        # Get object with specific byte range
        response = s3_client.get_object(
            Bucket=bucket_name,
            Key=file_key,
            Range=byte_range
        )

        # Read and decode the content
        meaning_bytes = response['Body'].read()
        meaning_text = meaning_bytes.decode('utf-8')

        return meaning_text.strip()

    except NoCredentialsError:
        raise InternalServerException(
            detail="AWS credentials not configured properly"
        )
    except PartialCredentialsError:
        raise InternalServerException(
            detail="Incomplete AWS credentials"
        )
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        error_message = e.response.get('Error', {}).get('Message', str(e))

        if error_code == 'NoSuchKey':
            raise NotFoundException(
                detail=f"Meaning data file '{file_key}' not found in S3",
                resource="S3 Object"
            )
        elif error_code == 'NoSuchBucket':
            raise InternalServerException(
                detail=f"S3 bucket '{bucket_name}' does not exist"
            )
        elif error_code == 'AccessDenied':
            raise InternalServerException(
                detail="Access denied to S3 resource. Check IAM permissions"
            )
        elif error_code in ['RequestTimeout', 'ServiceUnavailable', 'SlowDown']:
            raise ServiceUnavailableException(
                detail=f"S3 service temporarily unavailable: {error_message}"
            )
        elif error_code == 'InvalidRange':
            raise InternalServerException(
                detail=f"Invalid byte range requested: offset={offset}, length={length}"
            )
        else:
            raise InternalServerException(
                detail=f"S3 error ({error_code}): {error_message}"
            )
    except UnicodeDecodeError as e:
        raise InternalServerException(
            detail=f"Failed to decode meaning text at offset {offset}. Data may be corrupted or not UTF-8 encoded"
        )
    except Exception as e:
        raise InternalServerException(
            detail=f"Unexpected error reading from S3: {str(e)}"
        )


# load index from data/index.json

def load_index_from_local(file_path: str) -> dict:
    """Load index data from a local JSON file."""
    with open("data/index.json", 'r') as file:
        data = json.load(file)
    return data


# Create cached version of read_meaning_from_s3 based on configuration
if app_settings.cache.enabled:
    # Apply LRU cache with configured size
    read_meaning_from_s3 = lru_cache(maxsize=app_settings.cache.max_size)(_read_meaning_from_s3_uncached)
    print(f"✓ S3 cache enabled: {app_settings.cache.max_size:,} entries (~{app_settings.cache.max_size * 8 // 1024} MB)")
else:
    # Cache disabled - use uncached version
    read_meaning_from_s3 = _read_meaning_from_s3_uncached
    print("⚠ S3 cache disabled")


if __name__ == "__main__":
    print("S3 client utility loaded.")
    print(f"Cache configuration: enabled={app_settings.cache.enabled}, max_size={app_settings.cache.max_size}")
