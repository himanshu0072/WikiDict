from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str

class SearchMeaning(BaseModel):
    word: str
    meaning: str

class AutocompleteItem(BaseModel):
    word: str
    highlighted: str