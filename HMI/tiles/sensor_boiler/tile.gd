
extends Tile

# ---- CONSTANTES ----

const DEVICE_NAME = "sensor_k"

const SUB_HB = "hb_" + DEVICE_NAME

const SUB_STATUS_COUNTER = "status_" + DEVICE_NAME + "_counter"
const SUB_CMD_RESET_COUNTER = "cmd_" + DEVICE_NAME + "_reset_counter"
const SUB_STATUS_CLIMAT = "status_" + DEVICE_NAME + "_climat"
const SUB_CMD_LED_POWER = "cmd_" + DEVICE_NAME + "_led_power"
const SUB_STATUS_LED_POWER = "status_" + DEVICE_NAME + "_led_power"
const SUB_SET_LED_COLOR = "set_" + DEVICE_NAME + "_led_color"
const SUB_STATUS_LED_COLOR = "status_" + DEVICE_NAME + "_led_color"

const HB_TIMEOUT_S := 3.5
const HB_BLINK_S := 0.5

const COUNTER_PAYLOAD_SIZE := 4
const COUNTER_VALUE_OFFSET := 0

const CLIMATE_PAYLOAD_SIZE := 4
const TEMPERATURE_OFFSET := 0
const HUMIDITY_OFFSET := 2
const CLIMATE_DIVIDER := 100

const LED_POWER_PAYLOAD_SIZE := 1
const LED_POWER_OFFSET := 0

const LED_COLOR_PAYLOAD_SIZE := 3
const RED_OFFSET := 0
const GREEN_OFFSET := 1
const BLUE_OFFSET := 2

const CONNECTED_COLOR := Color(1.0, 1.0, 1.0)
const DISCONNECTED_COLOR := Color(0.5, 0.5, 0.5)

# ---- VARIABLES ----

var _node_id: int = -1
var _seconds_since_hb: float = INF

var _connected: bool = false:
	set(value):
		if value == _connected:
			return

		_connected = value

		if _connected:
			_on_sensor_connected()
		else:
			_on_sensor_disconnected()


# ---- INITIALISATION ----

## Initialise les connexions des boutons de la tuile.
func _ready() -> void:
	super()

	%ResetButton.pressed.connect(_on_reset_button_pressed)
	%LedOnButton.pressed.connect(_on_led_on_button_pressed)
	%LedOffButton.pressed.connect(_on_led_off_button_pressed)
	%ApplyColorButton.pressed.connect(_on_apply_color_button_pressed)
	_on_sensor_disconnected()

# ---- ABONNEMENTS ----

## Retourne tous les subjects reçus par la tuile.
func get_subscriptions() -> PackedStringArray:
	var subscriptions: PackedStringArray = []

	subscriptions.append(SUB_HB)
	subscriptions.append(SUB_STATUS_COUNTER)
	subscriptions.append(SUB_STATUS_CLIMAT)
	subscriptions.append(SUB_STATUS_LED_POWER)
	subscriptions.append(SUB_STATUS_LED_COLOR)

	return subscriptions


# ---- CONNEXION ----
## Enregistre l'identifiant du capteur correspondant à cette tuile.
func on_node_online(
	node_id: int,
	_mac_address: String,
	device_name: String
) -> void:
	if device_name != DEVICE_NAME:
		return

	_node_id = node_id
	%IDLabel.text = "node_id : %d" % _node_id



## Signale la déconnexion du capteur.
func on_node_offline(node_id: int, _reason_code: int) -> void:
	if node_id == _node_id:
		_connected = false


## Signale la perte de connexion avec la passerelle.
func on_gateway_reachability_changed(
	is_gateway_reachable: bool
) -> void:
	if is_gateway_reachable:
		return

	_connected = false
	_node_id = -1


# ---- RECEPTION ----

## Distribue les messages reçus vers leur traitement spécifique.
func on_message(
	subject_name: String,
	source_id: int,
	payload: PackedByteArray
) -> void:
	if subject_name == SUB_HB:
		_on_hb(source_id)
		return

	if source_id != _node_id:
		return

	if subject_name == SUB_STATUS_COUNTER:
		_on_counter_status(payload)
	elif subject_name == SUB_STATUS_CLIMAT:
		_on_climate_status(payload)
	elif subject_name == SUB_STATUS_LED_POWER:
		_on_led_power_status(payload)
	elif subject_name == SUB_STATUS_LED_COLOR:
		_on_led_color_status(payload)


# ---- COMPTEUR ----

## Met à jour le compteur uniquement après réception du status.
func _on_counter_status(payload: PackedByteArray) -> void:
	if payload.size() != COUNTER_PAYLOAD_SIZE:
		return

	var counter: int = payload.decode_u32(COUNTER_VALUE_OFFSET)
	%CounterLabel.text = "Compteur : %d" % counter


## Envoie une demande de réinitialisation du compteur.
func _on_reset_button_pressed() -> void:
	publish(SUB_CMD_RESET_COUNTER, PackedByteArray(), true)


# ---- CLIMAT ----

## Décode et affiche la température et l'humidité du DHT11.
func _on_climate_status(payload: PackedByteArray) -> void:
	if payload.size() != CLIMATE_PAYLOAD_SIZE:
		return

	var temperature_centi = float(payload.decode_s16(TEMPERATURE_OFFSET)) / CLIMATE_DIVIDER
	var humidity: float = float(payload.decode_u16(HUMIDITY_OFFSET)) / CLIMATE_DIVIDER
	

	%TemperatureLabel.text = "Température : %.2f °C" % temperature_centi
	%HumidityLabel.text = "Humidité : %.2f %%" % humidity


# ---- LED RGB ----

## Affiche l'état réel de la LED confirmé par le capteur.
func _on_led_power_status(payload: PackedByteArray) -> void:
	if payload.size() != LED_POWER_PAYLOAD_SIZE:
		return

	var is_on: int = payload.decode_u8(LED_POWER_OFFSET)

	if is_on > 1:
		return

	if is_on == 1:
		%LedPowerLabel.text = "LED : allumée"
	else:
		%LedPowerLabel.text = "LED : éteinte"


## Affiche la couleur réellement appliquée à la LED.
func _on_led_color_status(payload: PackedByteArray) -> void:
	if payload.size() != LED_COLOR_PAYLOAD_SIZE:
		return

	var red: int = payload.decode_u8(RED_OFFSET)
	var green: int = payload.decode_u8(GREEN_OFFSET)
	var blue: int = payload.decode_u8(BLUE_OFFSET)

	%RedSlider.value = red
	%GreenSlider.value = green
	%BlueSlider.value = blue

	%LedColorPreview.color = Color8(red, green, blue)

	%LedColorLabel.text = "RGB : %d, %d, %d" % [
		red,
		green,
		blue
	]
	

## Envoie une commande d'allumage de la LED.
func _on_led_on_button_pressed() -> void:
	publish(SUB_CMD_LED_POWER, PackedByteArray([1]), true)


## Envoie une commande d'extinction de la LED.
func _on_led_off_button_pressed() -> void:
	publish(SUB_CMD_LED_POWER, PackedByteArray([0]), true)


## Envoie la couleur choisie dans les trois curseurs.
func _on_apply_color_button_pressed() -> void:
	var red: int = int(%RedSlider.value)
	var green: int = int(%GreenSlider.value)
	var blue: int = int(%BlueSlider.value)

	var payload := PackedByteArray()
	payload.append(red)
	payload.append(green)
	payload.append(blue)

	publish(SUB_SET_LED_COLOR, payload, true)


# ---- HEARTBEAT ----

## Actualise l'indicateur de heartbeat et détecte les pertes de connexion.
func _process(delta: float) -> void:
	_seconds_since_hb += delta

	%HeartbeatIcon.state = _seconds_since_hb < HB_BLINK_S

	if _connected and _seconds_since_hb >= HB_TIMEOUT_S:
		_connected = false
	
	%LedColorLabel.text = "RGB : %d, %d, %d" % [
		$RedSlider.value,
		$GreenSlider.value,
		$BlueSlider.value
	]
	%LedColorPreview.color = Color8($RedSlider.value, $GreenSlider.value, $BlueSlider.value)
	


## Actualise le délai du heartbeat reçu du capteur.
func _on_hb(source_id: int) -> void:
	if _node_id == -1:
		_node_id = source_id

	if source_id != _node_id:
		return

	_seconds_since_hb = 0.0
	_connected = true


# ---- ETAT DE LA TUILE ----

## Réactive les commandes et attend les états republiés par le capteur.
func _on_sensor_connected() -> void:
	%IDLabel.text = "node_id : %d" % _node_id
	%ConnectedIcon.state = true

	%CounterLabel.text = "Compteur : attente..."
	%TemperatureLabel.text = "Température : attente..."
	%HumidityLabel.text = "Humidité : attente..."
	%LedPowerLabel.text = "LED : attente..."
	%LedColorLabel.text = "RGB : attente..."

	%CounterLabel.modulate = CONNECTED_COLOR
	%TemperatureLabel.modulate = CONNECTED_COLOR
	%HumidityLabel.modulate = CONNECTED_COLOR
	%LedPowerLabel.modulate = CONNECTED_COLOR
	%LedColorLabel.modulate = CONNECTED_COLOR

	%ResetButton.disabled = false
	%LedOnButton.disabled = false
	%LedOffButton.disabled = false
	%ApplyColorButton.disabled = false

	%RedSlider.editable = true
	%GreenSlider.editable = true
	%BlueSlider.editable = true


## Marque les valeurs comme périmées et désactive les commandes.
func _on_sensor_disconnected() -> void:
	%IDLabel.text = "node_id : ∅"
	%ConnectedIcon.state = false

	%CounterLabel.text = "Compteur : périmé"
	%TemperatureLabel.text = "Température : périmée"
	%HumidityLabel.text = "Humidité : périmée"
	%LedPowerLabel.text = "LED : périmée"
	%LedColorLabel.text = "RGB : périmée"

	%CounterLabel.modulate = DISCONNECTED_COLOR
	%TemperatureLabel.modulate = DISCONNECTED_COLOR
	%HumidityLabel.modulate = DISCONNECTED_COLOR
	%LedPowerLabel.modulate = DISCONNECTED_COLOR
	%LedColorLabel.modulate = DISCONNECTED_COLOR

	%LedColorPreview.color = DISCONNECTED_COLOR

	%ResetButton.disabled = true
	%LedOnButton.disabled = true
	%LedOffButton.disabled = true
	%ApplyColorButton.disabled = true

	%RedSlider.editable = false
	%GreenSlider.editable = false
	%BlueSlider.editable = false


	
