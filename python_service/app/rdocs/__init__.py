from app.rdocs.mapper import MappedDocument, map_rdocs_result
from app.rdocs.pipeline import RussianDocsFieldsProvider
from app.rdocs.provider import DocumentFieldsProvider, DocumentFieldsSnapshot

__all__ = [
    "DocumentFieldsProvider",
    "DocumentFieldsSnapshot",
    "MappedDocument",
    "RussianDocsFieldsProvider",
    "map_rdocs_result",
]
