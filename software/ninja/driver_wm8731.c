#include "driver_wm8731.h"

#include <stdio.h>

#include "altera_avalon_i2c.h"
#include "priv/alt_busy_sleep.h"
#include "system.h"

#if defined(AUDIO_I2C_0_NAME)
#define WM8731_I2C_NAME AUDIO_I2C_0_NAME
#elif defined(CODEC_I2C_0_NAME)
#define WM8731_I2C_NAME CODEC_I2C_0_NAME
#elif defined(I2C_1_NAME)
#define WM8731_I2C_NAME I2C_1_NAME
#endif

#define WM8731_ADDR_7BIT 0x1Au
#define WM8731_I2C_SPEED_HZ 100000u
#define WM8731_RETRY_COUNT 8u
#define WM8731_RETRY_DELAY_US 1000u

static const char *wm8731_i2c_status_name(ALT_AVALON_I2C_STATUS_CODE status)
{
    switch ((int)status)
    {
        case ALT_AVALON_I2C_SUCCESS:
            return "SUCCESS";
        case ALT_AVALON_I2C_ERROR:
            return "ERROR";
        case ALT_AVALON_I2C_TIMEOUT:
            return "TIMEOUT";
        case ALT_AVALON_I2C_BAD_ARG:
            return "BAD_ARG";
        case ALT_AVALON_I2C_RANGE:
            return "RANGE";
        case ALT_AVALON_I2C_NACK_ERR:
            return "NACK";
        case ALT_AVALON_I2C_ARB_LOST_ERR:
            return "ARB_LOST";
        case ALT_AVALON_I2C_BUSY:
            return "BUSY";
        default:
            return "UNKNOWN";
    }
}

#ifdef WM8731_I2C_NAME
static int wm8731_write_reg(ALT_AVALON_I2C_DEV_t *i2c, unsigned int reg, unsigned int value)
{
    alt_u8 tx[2];
    unsigned int retry;
    ALT_AVALON_I2C_STATUS_CODE last_status = ALT_AVALON_I2C_ERROR;

    tx[0] = (alt_u8)(((reg & 0x7Fu) << 1) | ((value >> 8) & 0x1u));
    tx[1] = (alt_u8)(value & 0xFFu);

    for (retry = 0u; retry < WM8731_RETRY_COUNT; retry++)
    {
        ALT_AVALON_I2C_STATUS_CODE status;

        alt_avalon_i2c_master_target_set(i2c, WM8731_ADDR_7BIT);
        status = alt_avalon_i2c_master_tx(i2c, tx, 2, 0);
        last_status = status;
        if (status == ALT_AVALON_I2C_SUCCESS)
        {
            return 0;
        }

        alt_busy_sleep(WM8731_RETRY_DELAY_US);
    }

    printf("WM8731 reg write failed: reg=%u value=0x%03X status=%s(%d)\r\n",
           reg,
           value & 0x1FFu,
           wm8731_i2c_status_name(last_status),
           (int)last_status);
    return 1;
}
#endif

int wm8731_init(void)
{
#ifndef WM8731_I2C_NAME
    printf("WM8731 init skipped: add Platform Designer Avalon I2C named audio_i2c_0 and regenerate BSP.\r\n");
    return 1;
#else
    ALT_AVALON_I2C_MASTER_CONFIG_t cfg;
    ALT_AVALON_I2C_DEV_t *i2c;

    printf("WM8731 init using %s\r\n", WM8731_I2C_NAME);

    i2c = alt_avalon_i2c_open(WM8731_I2C_NAME);
    if (i2c == NULL)
    {
        printf("WM8731 init failed: cannot open %s\r\n", WM8731_I2C_NAME);
        return 1;
    }

    alt_avalon_i2c_master_config_get(i2c, &cfg);
    cfg.addr_mode = ALT_AVALON_I2C_ADDR_MODE_7_BIT;
    if (alt_avalon_i2c_master_config_speed_set(i2c, &cfg, WM8731_I2C_SPEED_HZ) != ALT_AVALON_I2C_SUCCESS)
    {
        printf("WM8731 init failed: cannot set I2C speed\r\n");
        return 1;
    }
    alt_avalon_i2c_master_config_set(i2c, &cfg);

    if (wm8731_write_reg(i2c, 15u, 0x000u) != 0) return 1; /* reset */
    alt_busy_sleep(10000u);
    if (wm8731_write_reg(i2c, 0u, 0x017u) != 0) return 1;  /* left line in muted path default */
    if (wm8731_write_reg(i2c, 1u, 0x017u) != 0) return 1;  /* right line in muted path default */
    if (wm8731_write_reg(i2c, 2u, 0x079u) != 0) return 1;  /* left headphone volume */
    if (wm8731_write_reg(i2c, 3u, 0x079u) != 0) return 1;  /* right headphone volume */
    if (wm8731_write_reg(i2c, 4u, 0x012u) != 0) return 1;  /* DAC selected, mic muted */
    if (wm8731_write_reg(i2c, 5u, 0x000u) != 0) return 1;  /* no deemphasis, DAC unmuted */
    if (wm8731_write_reg(i2c, 6u, 0x007u) != 0) return 1;  /* power down line-in, mic, ADC */
    if (wm8731_write_reg(i2c, 7u, 0x042u) != 0) return 1;  /* master mode, I2S, 16-bit */
    if (wm8731_write_reg(i2c, 8u, 0x001u) != 0) return 1;  /* USB mode, 48 kHz from 12 MHz XCK */
    if (wm8731_write_reg(i2c, 9u, 0x001u) != 0) return 1;  /* activate interface */

    printf("WM8731 init complete: I2S 16-bit DAC mode\r\n");
    return 0;
#endif
}
