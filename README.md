# Depot HMI et Arduino

## Contrats

### Godot vers ESP32

SUB_CMD_RESET_COUNTER = "cmd_" + DEVICE_NAME + "_reset_counter"
  - description : requête de réinitialisation du compteur
  - payload : vide
  - nom dans arduino : kSubCmdResetCounter
  
SUB_CMD_LED_POWER = "cmd_" + DEVICE_NAME + "_led_power"
  - description : requête d'extinction ou d'allumage de la led
  - payload : bit à 0 pour extinction, 1 pour allumage
  - nom dans arduino : kSubCmdLedPower

SUB_SET_LED_COLOR = "set_" + DEVICE_NAME + "_led_color"
  - description : changement de la couleur de la led selon celle définie par l'utilisateur dans l'IHM
  - payload : 3 int pour rouge, vert et bleu respectivement
  - nom dans arduino : kSubSetLedColor

### ESP32 vers Godot

kSubStatusCounter = "status_" DEVICE_NAME "_counter"
  - description : renvoie le statut du compteur
  - payload : uint32_t contenant la valeur actuelle du compteur
  - taille en octets : 4 
  - nom dans godot : SUB_STATUS_COUNTER
  
kSubStatusClimat = "status_" DEVICE_NAME "_climat"
  - description : envoie les valeurs de température et d'humidité captées par le dht11
  - payload : int16_t pour la température en centièmes de degrés °C et uint_16 pour l'humidité en %
  - taille en octets : 4
  - nom dans godot : SUB_STATUS_CLIMAT

kSubStatusLedPower = "status_" DEVICE_NAME "_led_power"
  - description : envoie le statut actuel de la led si allumée ou éteinte 
  - payload : uint8_t correspondant à 1 pour "allumé" et 0 pour "éteint"
  - taille en octet : 1
  - nom dans godot : SUB_STATUS_LED_POWER

kSubStatusLedColor = "status_" DEVICE_NAME "_led_color"
  - description : envoie la couleur actuelle de la led
  - payload : 3 uint8_t pour rouge, vert et bleu
  - taille en octet : 3
  - nom dans godot : SUB_STATUS_LED_COLOR

