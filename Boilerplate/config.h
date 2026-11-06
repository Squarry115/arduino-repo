#pragma once

#include <stdint.h>

static const uint8_t kGatewayMacAddress[6] = {0x90,0xDA,0x72,0x53,0x5D,0x88};
constexpr uint8_t kWifiChannel = 4;
#define DEVICE_NAME "sensor_k" // exemple, sensor_<groupe>, minuscules, 16 caractères au plus