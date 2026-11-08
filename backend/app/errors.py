from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from sqlalchemy.exc import DataError, OperationalError


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(OperationalError)
    def database_unavailable(_request: Request, _error: OperationalError) -> JSONResponse:
        # El error original incluye datos de conexión: no se envía al cliente.
        return JSONResponse(status_code=503, content={"detail": "La base de datos no está disponible"})

    @app.exception_handler(DataError)
    def invalid_data(_request: Request, _error: DataError) -> JSONResponse:
        # PostgreSQL rechaza valores que otras bases aceptan, como el carácter NUL.
        return JSONResponse(status_code=422, content={"detail": "Los datos contienen valores no válidos"})
