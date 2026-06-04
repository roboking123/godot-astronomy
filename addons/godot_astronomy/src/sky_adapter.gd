class_name SkyAdapter
## Base class for connecting CelestialBody to external sky systems.
## Subclass this and override apply() to drive your own sky shader, lighting, etc.
## Attach as a child of CelestialBody or assign via export.
extends Resource


## Called every frame with the latest sky state.
## Override this in your subclass to drive your sky system.
func apply(_state: CelestialState) -> void:
	pass
