"""python-uv reference service.

Public surface declared via ``__all__`` so pdoc and importers can rely on the
intended API instead of the underscore-prefix convention alone (pdoc rule 7).
"""

from app.main import create_app

__all__ = ["create_app"]
