## Cliente HTTP del backend local (Autoload "Api").
##
## Centraliza toda la comunicación con el servidor FastAPI de la Persona 5.
## Si cambian las rutas del backend, solo hay que editar las constantes de este archivo.
extends Node

## Dirección donde corre el backend (uvicorn).
const BASE_URL := "http://127.0.0.1:8000"

## Ruta que lista los recursos en la API de FastAPI.
const RESOURCES_ENDPOINT := "/api/resources"


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


## Sube una imagen local al backend mediante POST multipart/form-data.
## Devuelve el recurso creado o un diccionario vacío si falla o el backend no está disponible.
func upload_image(file_path: String, resource_name: String = "") -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var file_bytes := file.get_buffer(file.get_length())
	file.close()

	if resource_name == "":
		resource_name = file_path.get_file().get_basename()

	var boundary := "GodotBoundary" + str(Time.get_ticks_msec())
	var body := PackedByteArray()

	var add_field = func(field_name: String, value: String):
		var s := "--" + boundary + "\r\n"
		s += "Content-Disposition: form-data; name=\"" + field_name + "\"\r\n\r\n"
		s += value + "\r\n"
		body.append_array(s.to_utf8_buffer())

	add_field.call("name", resource_name)
	add_field.call("type", "image")
	add_field.call("category", "obras")

	var ext := file_path.get_extension().to_lower()
	var mime := "image/jpeg" if ext in ["jpg", "jpeg"] else ("image/png" if ext == "png" else "image/webp")
	var file_header := "--" + boundary + "\r\n"
	file_header += "Content-Disposition: form-data; name=\"file\"; filename=\"" + file_path.get_file() + "\"\r\n"
	file_header += "Content-Type: " + mime + "\r\n\r\n"
	body.append_array(file_header.to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())

	var footer := "--" + boundary + "--\r\n"
	body.append_array(footer.to_utf8_buffer())

	var headers := PackedStringArray([
		"Content-Type: multipart/form-data; boundary=" + boundary
	])

	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request_raw(BASE_URL + RESOURCES_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {}

	var res = await http.request_completed
	http.queue_free()

	if res[0] != HTTPRequest.RESULT_SUCCESS or (res[1] != 200 and res[1] != 201):
		return {}

	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return data if data is Dictionary else {}