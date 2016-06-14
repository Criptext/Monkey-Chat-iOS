/*
 *  SGSProtocol.h
 *  LuckyOnline
 *
 *  Created by Timothy Braun on 3/11/09.
 *  Copyright 2009 Fellowship Village. All rights reserved.
 *
 */

#define MOKSGS_MSG_MAX_LENGTH		65535

#define MOKSGS_MAX_PAYLOAD_LENGTH	65533

#define MOKSGS_MSG_INIT_LEN		(MOKSGS_MSG_MAX_LENGTH - MOKSGS_MAX_PAYLOAD_LENGTH)

#define MOKSGS_MSG_VERSION			'\005'

#define MOKSGS_OPCODE_OFFSET		2

#define MOKSGS_MSG_LENGTH_OFFSET	2

typedef enum {
    MOKSGSOpcodeLoginRequest = 0x10,
    MOKSGSOpcodeLoginSuccess = 0x11,
    MOKSGSOpcodeLoginFailure = 0x12,
    MOKSGSOpcodeLoginRedirect = 0x13,
    MOKSGSOpcodeReconnectRequest = 0x20,
    MOKSGSOpcodeReconnectSuccess = 0x21,
    MOKSGSOpcodeReconnectFailure = 0x22,
    MOKSGSOpcodeSessionMessage = 0x30,
    MOKSGSOpcodeLogoutRequest = 0x40,
    MOKSGSOpcodeLogoutSuccess = 0x41,
    MOKSGSOpcodeChannelJoin = 0x50,
    MOKSGSOpcodeChannelLeave = 0x51,
    MOKSGSOpcodeChannelMessage = 0x52,
} MOKSGSOpcode;