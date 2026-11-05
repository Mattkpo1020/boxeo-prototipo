extends RefCounted

enum Style { PRESSURE, COUNTER, MOBILITY }

const LABELS := ["PRESIÓN", "CONTRAGOLPE", "MOVILIDAD"]

# La selección pertenece a esta sesión y se conserva al reiniciar el sparring.
static var selected: int = Style.PRESSURE
