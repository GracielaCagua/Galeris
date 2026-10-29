## Estado global de la aplicación (Autoload "GameState").
##
## Guarda en qué modo está el usuario: visualizar o crear.
## Cualquier sistema de edición debe consultar [method can_edit] antes de actuar;
## así el Modo visualizar queda bloqueado en un solo punto.
extends Node

## Modos disponibles de la aplicación.
enum Mode { NONE, VISUALIZE, CREATE }

## Se emite cada vez que cambia el modo. [param mode] es un valor de [enum Mode].
signal mode_changed(mode: int)

## Modo actual. No modificar directamente: usar [method set_mode].
var mode: int = Mode.NONE


## Cambia el modo actual y avisa a todos los que escuchan la señal.
func set_mode(new_mode: int) -> void:
	mode = new_mode
	mode_changed.emit(mode)


## Devuelve [code]true[/code] solo en Modo crear.
## Las herramientas de edición deben llamar a esta función antes de hacer cualquier cambio.
func can_edit() -> bool:
	return mode == Mode.CREATE