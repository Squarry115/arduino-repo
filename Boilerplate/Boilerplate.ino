
#include <Arduino.h>
#include <MPS.h>
#include <DHT.h>
#include <math.h>
#include <stdint.h>

#include "config.h"

// ---- CONSTANTES ----

static constexpr uint8_t kDhtPin = 0;
static constexpr uint8_t kLedPin = 2;

static constexpr uint32_t kCounterPeriodMs = 2000;
static constexpr uint32_t kClimatePeriodMs = 2000;
static constexpr uint32_t kHeartbeatPeriodMs = 1000;

constexpr mps::Subject kSubHb =
    mps::makeSubject("hb_" DEVICE_NAME);

constexpr mps::Subject kSubStatusCounter =
    mps::makeSubject("status_" DEVICE_NAME "_counter");

constexpr mps::Subject kSubCmdResetCounter =
    mps::makeSubject("cmd_" DEVICE_NAME "_reset_counter");

constexpr mps::Subject kSubStatusClimate =
    mps::makeSubject("status_" DEVICE_NAME "_climate");

constexpr mps::Subject kSubCmdLedPower =
    mps::makeSubject("cmd_" DEVICE_NAME "_led_power");

constexpr mps::Subject kSubStatusLedPower =
    mps::makeSubject("status_" DEVICE_NAME "_led_power");

constexpr mps::Subject kSubSetLedColor =
    mps::makeSubject("set_" DEVICE_NAME "_led_color");

constexpr mps::Subject kSubStatusLedColor =
    mps::makeSubject("status_" DEVICE_NAME "_led_color");

// ---- STRUCTURES PAYLOAD ----

/// Valeur actuelle du compteur.
struct __attribute__((packed)) CounterPayload {
  uint32_t value;
};

static_assert(sizeof(CounterPayload) == 4,
              "CounterPayload = 4 octets");

/// Température et humidité mesurées par le DHT11.
struct __attribute__((packed)) ClimatePayload {
  int16_t temperatureCentiDegrees;
  uint8_t humidityPercent;
};

static_assert(sizeof(ClimatePayload) == 3,
              "ClimatePayload = 3 octets");

/// État réel de l'alimentation de la LED.
struct __attribute__((packed)) LedPowerPayload {
  uint8_t isOn;
};

static_assert(sizeof(LedPowerPayload) == 1,
              "LedPowerPayload = 1 octet");

/// Couleur RGB appliquée à la LED.
struct __attribute__((packed)) LedColorPayload {
  uint8_t red;
  uint8_t green;
  uint8_t blue;
};

static_assert(sizeof(LedColorPayload) == 3,
              "LedColorPayload = 3 octets");

// ---- VARIABLES ----

static uint32_t gLastHeartbeatMs = 0;


static DHT gDht(kDhtPin, DHT11);

static CounterPayload gCounter = {0};
static ClimatePayload gClimate = {};
static LedPowerPayload gLedPower = {0};
static LedColorPayload gLedColor = {0, 0, 0};

static bool gHasClimateReading = false;

static uint32_t gLastCounterUpdateMs = 0;
static uint32_t gLastClimateReadMs = 0;

// ---- PUBLICATION DES ETATS ----

/// Publie la valeur actuelle du compteur.
static void publishCounter() {
  MPS.publishValue(kSubStatusCounter, gCounter);
}

/// Publie la dernière mesure valide du DHT11.
static void publishClimate() {
  if (!gHasClimateReading) {
    return;
  }

  MPS.publishValue(kSubStatusClimate, gClimate);
}

/// Publie l'état réel de l'alimentation de la LED.
static void publishLedPower() {
  MPS.publishValue(kSubStatusLedPower, gLedPower);
}

/// Publie la couleur actuellement sélectionnée.
static void publishLedColor() {
  MPS.publishValue(kSubStatusLedColor, gLedColor);
}

// ---- LED RGB ----

/// Applique l'état et la couleur mémorisés à la LED intégrée.
static void applyLedOutput() {
  if (gLedPower.isOn == 0) {
    rgbLedWrite(kLedPin, 0, 0, 0);
    return;
  }

  rgbLedWrite(
      kLedPin,
      gLedColor.red,
      gLedColor.green,
      gLedColor.blue
  );
}

// ---- LECTURE DU CAPTEUR ----

/// Lit le DHT11 et publie une mesure valide.
static void readClimate() {
  const float temperature = gDht.readTemperature();
  const float humidity = gDht.readHumidity();

  if (isnan(temperature) || isnan(humidity)) {
    return;
  }

  if (humidity < 0.0f || humidity > 100.0f) {
    return;
  }

  gClimate.temperatureCentiDegrees =
      static_cast<int16_t>(roundf(temperature * 100.0f));

  gClimate.humidityPercent =
      static_cast<uint8_t>(roundf(humidity));

  gHasClimateReading = true;

  publishClimate();
}

// ---- HANDLERS ----

/// Réinitialise le compteur après réception d'une commande valide.
static void onCmdResetCounter(
    const mps::FrameView& message,
    void*
) {
  if (message.payloadLength != 0) {
    return;
  }

  gCounter.value = 0;
  publishCounter();
}

/// Applique l'état d'alimentation demandé à la LED.
static void onCmdLedPower(
    const mps::FrameView& message,
    void*
) {
  LedPowerPayload payload = {};

  if (!mps::readPayloadAs(message, &payload)) {
    return;
  }

  if (payload.isOn > 1) {
    return;
  }

  gLedPower = payload;

  applyLedOutput();
  publishLedPower();
}

/// Applique la couleur demandée par l'interface.
static void onSetLedColor(
    const mps::FrameView& message,
    void*
) {
  LedColorPayload payload = {};

  if (!mps::readPayloadAs(message, &payload)) {
    return;
  }

  gLedColor = payload;

  applyLedOutput();
  publishLedColor();
}

// ---- SESSION MPS ----

/// Republie tous les états connus à chaque ouverture de session.
static void onSessionOpened() {
  publishCounter();
  publishClimate();
  publishLedPower();
  publishLedColor();
}

// ---- INITIALISATION ----

/// Initialise les capteurs, la LED et les abonnements MPS.
void setup() {

  gLastHeartbeatMs = millis();

  gDht.begin();

  applyLedOutput();

  MPS.setRegisteredCallback(onSessionOpened);

  MPS.on(kSubCmdResetCounter, onCmdResetCounter);
  MPS.on(kSubCmdLedPower, onCmdLedPower);
  MPS.on(kSubSetLedColor, onSetLedColor);

  MPS.begin(
      kGatewayMacAddress,
      DEVICE_NAME,
      kWifiChannel
  );

  gLastCounterUpdateMs = millis();
  gLastClimateReadMs = millis();
}


/// Maintient la communication et actualise périodiquement les mesures.

/// Maintient la communication et actualise périodiquement les mesures.
void loop() {
  MPS.loop();

  const uint32_t now = millis();

  if (now - gLastHeartbeatMs >= kHeartbeatPeriodMs) {
    gLastHeartbeatMs = now;
    MPS.publishHeartbeat(kSubHb);
  }

  if (now - gLastCounterUpdateMs >= kCounterPeriodMs) {
    gLastCounterUpdateMs = now;

    gCounter.value += 1;
    publishCounter();
  }

  if (now - gLastClimateReadMs >= kClimatePeriodMs) {
    gLastClimateReadMs = now;
    readClimate();
  }
}

