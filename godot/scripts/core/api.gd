## Cliente HTTP del backend local (Autoload "Api").
##
## Centraliza toda la comunicación con el servidor FastAPI de la Persona 5.
## Si cambian las rutas del backend, solo hay que editar las constantes de este archivo.
extends Node

## Dirección donde corre el backend (uvicorn).
const BASE_URL := "http://127.0.0.1:8000"

## Ruta que lista los recursos. AJUSTAR según backend/app/main.py.
const RESOURCES_ENDPOINT := "/resources"


## Convierte una ruta relativa del backend en una URL completa.
## Si [param path] ya es una URL ([code]http...[/code]), la devuelve igual.
func file_url(path: String) -> String:
	if path.begins_with("http"):
		return path
	return BASE_URL + "/" + path.lstrip("/")


## Pide al backend la lista de recursos (imágenes, modelos, etc.).
## Devuelve un [Array] de [Dictionary]; si algo falla, devuelve un arreglo vacío.
## Se usa con [code]await[/code]: [code]var lista = await Api.list_resources()[/code]
func list_resources() -> Array:
	var http := HTTPRequest.new()
	add_child(http)

	if http.request(BASE_URL + RESOURCES_ENDPOINT) != OK:
		http.queue_free()
		return []

	# request_completed devuelve: [resultado, código HTTP, cabeceras, cuerpo]
	var res = await http.request_completed
	http.queue_free()

	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return []

	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return data if data is Array else []


## Descarga una imagen (PNG, JPG o WEBP) desde [param url].
## Devuelve un [Image], o [code]null[/code] si la descarga o el formato fallan.
func download_image(url: String) -> Image:
	var http := HTTPRequest.new()
	add_child(http)

	if http.request(url) != OK:
		http.queue_free()
		return null

	var res = await http.request_completed
	http.queue_free()

	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return null

	var body: PackedByteArray = res[3]
	var img := Image.new()

	# Se prueba cada formato hasta que alguno funcione.
	var err := img.load_png_from_buffer(body)
	if err != OK:
		err = img.load_jpg_from_buffer(body)
	if err != OK:
		err = img.load_webp_from_buffer(body)

	return img if err == OK else null