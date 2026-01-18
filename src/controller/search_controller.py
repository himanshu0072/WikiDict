from typing import Union
from fastapi import APIRouter, Request, Query
from src.errors import NotFoundException, BadRequestException, ErrorResponse
from src.config import get_index_loader
from src.models import SuccessResponse, SearchMeaning, AutocompleteItem
from src.utils import read_meaning_from_s3
from datetime import datetime, timezone
from html import escape

router = APIRouter(prefix="", tags=["Search"])

# get /search
@router.get(
    "/search",
    response_model=SuccessResponse[SearchMeaning],
    responses={
        200: {"description": "Word found successfully"},
        400: {"description": "Invalid request", "model": ErrorResponse},
        404: {"description": "Word not found", "model": ErrorResponse},
        500: {"description": "Internal server error", "model": ErrorResponse},
    }
)
async def search(
    request: Request,
    word: str = Query(..., description="Word to search for", min_length=1, max_length=50)
) -> Union[SuccessResponse, ErrorResponse]:
    """
    Search for a word in the dictionary.

    Returns a standardized success response with word and meaning data.

    Raises:
        BadRequestException: If the word parameter is invalid
        NotFoundException: If the word is not found in the dictionary

    Returns:
        SuccessResponse[SearchData]: Standard success response with word data
    """

    # Get the index loader
    index = get_index_loader()
    data_file_path = index.manifest.get("file_path")

    # Search for the word in the index
    result = index.get_value_by_key(word)

    if not result:
        raise NotFoundException(
            detail=f"Word '{word}' not found in dictionary",
            resource="Word"
        )

    # Extract offset and length from the index
    offset = result.get("offset")
    length = result.get("length")

    if offset is None or length is None:
        raise NotFoundException(
            detail=f"Invalid index data for word '{word}'",
            resource="Word"
        )

    # Read the actual meaning from S3 using the offset and length
    # All S3-related exceptions are handled in read_meaning_from_s3
    meaning_text = read_meaning_from_s3(offset, length, file_key=data_file_path)

    return {
        "status": "success",
        "data": {
            "word": word,
            "meaning": meaning_text
        },
        "result_count": 1,
        "message": "Word found successfully",
        "request_id": getattr(request.state, "request_id", None),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

# get /autocomplete
@router.get(
        "/autocomplete", 
        response_model=SuccessResponse[list[AutocompleteItem]],
        responses={
            200: {"description": "Autocomplete suggestions returned successfully"},
            400: {"description": "Invalid request", "model": ErrorResponse},
            500: {"description": "Internal server error", "model": ErrorResponse},
        }
    )
async def autocomplete(
        request: Request,
        q: str = Query(..., description="Query string for autocomplete"),
        limit: int = Query(default=10, ge=1, le=50, description="Maximum number of suggestions")
    ) -> Union[SuccessResponse, ErrorResponse]:
    index = get_index_loader()
    autocomplete_result = index.autosuggest_keys(q, max_suggestions=limit)

    # Create highlighted suggestions (bold the matched part)
    result = []
    for word in autocomplete_result:
        split_position = len(q)
        matched_part = word[:split_position]
        remaining_part = word[split_position:]
        highlighted = f"<b>{escape(matched_part)}</b>{escape(remaining_part)}"
        result.append(AutocompleteItem(word=word, highlighted=highlighted))

    return {
        "status": "success",
        "data": result,
        "result_count": len(result),
        "message": f"{len(result)} suggestions found",
        "request_id": getattr(request.state, "request_id", None),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }