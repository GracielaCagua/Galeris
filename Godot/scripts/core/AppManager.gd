extends Node
signal modo_cambiado(nuevo_modo)

enum Modo {
	VISUALIZAR,
	CREAR
}

var modo_actual: Modo = Modo.VISUALIZAR


func cambiar_modo(nuevo_modo: Modo) -> void:
	if modo_actual == nuevo_modo:
		return
	
	modo_actual = nuevo_modo
	modo_cambiado.emit(modo_actual)


func esta_en_modo_visualizar() -> bool:
	return modo_actual == Modo.VISUALIZAR


func esta_en_modo_crear() -> bool:
	return modo_actual == Modo.CREAR
	
func obtener_nombre_modo() -> String:
	if modo_actual == Modo.VISUALIZAR:
		return "Modo Visualizar"
		
	return "Modo Crear"

func puede_editar() -> bool:
	return modo_actual == Modo.CREAR
