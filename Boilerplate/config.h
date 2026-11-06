#pragma once

#include <stdint.h>

static const uint8_t kGatewayMacAddress[6] = {0x90,0xDA,0x72,0x53,0x5D,0x88}; // Adresse de la passerelle (écriture hexadécimale)
constexpr uint8_t kWifiChannel = 4; // Canal wifi de la passerelle

#define DEVICE_NAME "sensor_boiler" // modifiez cette valeur avec le nom de votre capteur (sensor_<groupe>), ex : "sensor_a"

