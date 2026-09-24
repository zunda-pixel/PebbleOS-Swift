/* SPDX-FileCopyrightText: 2026 Core Devices LLC */
/* SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

//! Shared bounds for the AccessoryNotifications transport, referenced by both the
//! BLE transport and the notification consumer so the two stay in sync.
//! A CoreBluetooth UUID renders as 36 chars; cap the feature/session id well above.
#define ACCESSORY_TRANSPORT_MAX_FEATURE_ID_LEN 64
//! Largest decrypted notification payload we accept.
#define ACCESSORY_TRANSPORT_MAX_PAYLOAD 2048

//! Register the AccessoryNotifications transport GATT service.
//! @see accessory_transport_service.c
void accessory_transport_service_init(void);

//! Handler invoked with a decrypted AccessoryNotifications payload (Apple's custom
//! serialized notification format) plus the transport featureID (session id
//! string) it arrived on — the consumer keeps that so a later action reply can be
//! sealed for the same feature.
typedef void (*AccessoryTransportNotificationHandler)(const uint8_t *data, size_t len,
                                                      const char *feature_id,
                                                      size_t feature_id_len);

//! Register the consumer that parses and surfaces decrypted notifications. Called
//! once at init by the upper layer. Explicit registration rather than a weak
//! symbol, so the wiring does not depend on link order. NULL clears it.
void accessory_transport_service_set_handler(AccessoryTransportNotificationHandler handler);

//! Seal an accessory->host reply for `feature_id` and notify it to the phone
//! (0x82 RESPONSE frame). Callable from any task. Returns false if there is no
//! active session/connection or sealing fails. Used by the notification action UI.
bool accessory_transport_service_send_response(const char *feature_id, size_t feature_id_len,
                                               const uint8_t *payload, size_t payload_len);
