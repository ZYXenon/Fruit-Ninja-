/**
 * Copyright (c) 2015 - present LibDriver All rights reserved
 * 
 * The MIT License (MIT)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE. 
 *
 * @file      driver_ov2640_interface_template.c
 * @brief     driver ov2640 interface template source file
 * @version   1.0.0
 * @author    Shifeng Li
 * @date      2023-11-30
 *
 * <h3>history</h3>
 * <table>
 * <tr><th>Date        <th>Version  <th>Author      <th>Description
 * <tr><td>2023/11/30  <td>1.0      <td>Shifeng Li  <td>first upload
 * </table>
 */

#include "driver_ov2640_interface.h"

#include <stdarg.h>
#include <stdio.h>

#include "altera_avalon_i2c.h"
#include "io.h"
#include "priv/alt_busy_sleep.h"
#include "sys/alt_stdio.h"
#include "system.h"
#include "unistd.h"

#if defined(CAM_CTRL_PIO_BASE) && (CAM_CTRL_PIO_BASE == 0x20u)
#undef CAM_CTRL_PIO_BASE
#define CAM_CTRL_PIO_BASE 0xF0u
#endif

#ifndef CAM_CTRL_PIO_BASE
#define CAM_CTRL_PIO_BASE 0xF0u
#endif

#define CAM_CTRL_PWDN_MASK     0x1u
#define CAM_CTRL_RESET_N_MASK  0x2u
#define SCCB_RETRY_COUNT       12u
#define SCCB_RETRY_DELAY_US    2000u
#define SCCB_SPEED_HZ          25000u
#define CAM_RESET_DELAY_US     50000u

static ALT_AVALON_I2C_DEV_t *g_i2c;
static uint32_t g_cam_ctrl_shadow = CAM_CTRL_PWDN_MASK;

static const char *i2c_status_name(ALT_AVALON_I2C_STATUS_CODE status)
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

static void cam_ctrl_write_shadow(void)
{
    IOWR_32DIRECT(CAM_CTRL_PIO_BASE, 0, g_cam_ctrl_shadow);
}

static uint8_t sccb_select_target(uint8_t addr)
{
    if (g_i2c == NULL)
    {
        return 1;
    }

    alt_avalon_i2c_master_target_set(g_i2c, (alt_u32)(addr >> 1));

    return 0;
}

/**
 * @brief  interface sccb bus init
 * @return status code
 *         - 0 success
 *         - 1 sccb init failed
 * @note   none
 */
uint8_t ov2640_interface_sccb_init(void)
{
    ALT_AVALON_I2C_MASTER_CONFIG_t cfg;

    g_i2c = alt_avalon_i2c_open(I2C_0_NAME);
    if (g_i2c == NULL)
    {
        return 1;
    }

    alt_avalon_i2c_master_config_get(g_i2c, &cfg);
    cfg.addr_mode = ALT_AVALON_I2C_ADDR_MODE_7_BIT;
    if (alt_avalon_i2c_master_config_speed_set(g_i2c, &cfg, SCCB_SPEED_HZ) != ALT_AVALON_I2C_SUCCESS)
    {
        return 1;
    }
    alt_avalon_i2c_master_config_set(g_i2c, &cfg);

    return 0;
}

/**
 * @brief  interface sccb bus deinit
 * @return status code
 *         - 0 success
 *         - 1 sccb deinit failed
 * @note   none
 */
uint8_t ov2640_interface_sccb_deinit(void)
{
    g_i2c = NULL;

    return 0;
}

/**
 * @brief      interface sccb bus read
 * @param[in]  addr sccb device write address
 * @param[in]  reg sccb register address
 * @param[out] *buf pointer to a data buffer
 * @param[in]  len length of the data buffer
 * @return     status code
 *             - 0 success
 *             - 1 read failed
 * @note       none
 */
uint8_t ov2640_interface_sccb_read(uint8_t addr, uint8_t reg, uint8_t *buf, uint16_t len)
{
    uint16_t i;
    ALT_AVALON_I2C_STATUS_CODE last_status = ALT_AVALON_I2C_ERROR;

    if ((buf == NULL) || (sccb_select_target(addr) != 0))
    {
        return 1;
    }

    for (i = 0; i < len; i++)
    {
        alt_u32 retry;
        alt_u8 reg_addr = (alt_u8)(reg + i);

        for (retry = 0; retry < SCCB_RETRY_COUNT; retry++)
        {
            ALT_AVALON_I2C_STATUS_CODE status;

            (void)sccb_select_target(addr);
            status = alt_avalon_i2c_master_tx_rx(g_i2c, &reg_addr, 1, &buf[i], 1, 0);
            last_status = status;
            if (status == ALT_AVALON_I2C_SUCCESS)
            {
                break;
            }
            alt_busy_sleep(SCCB_RETRY_DELAY_US);

            (void)sccb_select_target(addr);
            status = alt_avalon_i2c_master_tx(g_i2c, &reg_addr, 1, 0);
            last_status = status;
            if (status == ALT_AVALON_I2C_SUCCESS)
            {
                alt_busy_sleep(SCCB_RETRY_DELAY_US);
                status = alt_avalon_i2c_master_rx(g_i2c, &buf[i], 1, 0);
                last_status = status;
                if (status == ALT_AVALON_I2C_SUCCESS)
                {
                    break;
                }
            }
            alt_busy_sleep(SCCB_RETRY_DELAY_US);
        }

        if (retry == SCCB_RETRY_COUNT)
        {
            ov2640_interface_debug_print("sccb read failed: dev=0x%02X target7=0x%02X reg=0x%02X status=%s(%d)\r\n",
                                         addr,
                                         addr >> 1,
                                         reg_addr,
                                         i2c_status_name(last_status),
                                         (int)last_status);
            return 1;
        }
    }

    return 0;
}

/**
 * @brief     interface sccb bus write
 * @param[in] addr sccb device write address
 * @param[in] reg sccb register address
 * @param[in] *buf pointer to a data buffer
 * @param[in] len length of the data buffer
 * @return    status code
 *            - 0 success
 *            - 1 write failed
 * @note      none
 */
uint8_t ov2640_interface_sccb_write(uint8_t addr, uint8_t reg, uint8_t *buf, uint16_t len)
{
    uint16_t i;
    ALT_AVALON_I2C_STATUS_CODE last_status = ALT_AVALON_I2C_ERROR;

    if ((buf == NULL) || (sccb_select_target(addr) != 0))
    {
        return 1;
    }

    for (i = 0; i < len; i++)
    {
        alt_u32 retry;
        alt_u8 tx[2];

        tx[0] = (alt_u8)(reg + i);
        tx[1] = buf[i];

        for (retry = 0; retry < SCCB_RETRY_COUNT; retry++)
        {
            ALT_AVALON_I2C_STATUS_CODE status;

            (void)sccb_select_target(addr);
            status = alt_avalon_i2c_master_tx(g_i2c, tx, sizeof(tx), 0);
            last_status = status;
            if (status == ALT_AVALON_I2C_SUCCESS)
            {
                break;
            }
            alt_busy_sleep(SCCB_RETRY_DELAY_US);
        }

        if (retry == SCCB_RETRY_COUNT)
        {
            ov2640_interface_debug_print("sccb write failed: dev=0x%02X target7=0x%02X reg=0x%02X data=0x%02X status=%s(%d)\r\n",
                                         addr,
                                         addr >> 1,
                                         tx[0],
                                         tx[1],
                                         i2c_status_name(last_status),
                                         (int)last_status);
            return 1;
        }
    }

    return 0;
}

/**
 * @brief  interface power down init
 * @return status code
 *         - 0 success
 *         - 1 power down init failed
 * @note   none
 */
uint8_t ov2640_interface_power_down_init(void)
{
    g_cam_ctrl_shadow |= CAM_CTRL_PWDN_MASK;
    g_cam_ctrl_shadow &= ~CAM_CTRL_RESET_N_MASK;
    cam_ctrl_write_shadow();
    alt_busy_sleep(CAM_RESET_DELAY_US);

    return 0;
}

/**
 * @brief  interface power down deinit
 * @return status code
 *         - 0 success
 *         - 1 power down deinit failed
 * @note   none
 */
uint8_t ov2640_interface_power_down_deinit(void)
{
    g_cam_ctrl_shadow |= CAM_CTRL_PWDN_MASK;
    g_cam_ctrl_shadow &= ~CAM_CTRL_RESET_N_MASK;
    cam_ctrl_write_shadow();
    alt_busy_sleep(CAM_RESET_DELAY_US);

    return 0;
}

/**
 * @brief     interface power down write
 * @param[in] level set level
 * @return    status code
 *            - 0 success
 *            - 1 power down write failed
 * @note      none
 */
uint8_t ov2640_interface_power_down_write(uint8_t level)
{
    if (level != 0)
    {
        g_cam_ctrl_shadow |= CAM_CTRL_PWDN_MASK;
    }
    else
    {
        g_cam_ctrl_shadow &= ~CAM_CTRL_PWDN_MASK;
    }

    cam_ctrl_write_shadow();
    alt_busy_sleep(CAM_RESET_DELAY_US);

    return 0;
}

/**
 * @brief  interface reset init
 * @return status code
 *         - 0 success
 *         - 1 reset init failed
 * @note   none
 */
uint8_t ov2640_interface_reset_init(void)
{
    g_cam_ctrl_shadow &= ~CAM_CTRL_RESET_N_MASK;
    cam_ctrl_write_shadow();
    alt_busy_sleep(CAM_RESET_DELAY_US);

    return 0;
}

/**
 * @brief  interface reset deinit
 * @return status code
 *         - 0 success
 *         - 1 reset deinit failed
 * @note   none
 */
uint8_t ov2640_interface_reset_deinit(void)
{
    g_cam_ctrl_shadow &= ~CAM_CTRL_RESET_N_MASK;
    cam_ctrl_write_shadow();
    alt_busy_sleep(CAM_RESET_DELAY_US);

    return 0;
}

/**
 * @brief     interface reset write
 * @param[in] level set level
 * @return    status code
 *            - 0 success
 *            - 1 reset write failed
 * @note      none
 */
uint8_t ov2640_interface_reset_write(uint8_t level)
{
    if (level != 0)
    {
        g_cam_ctrl_shadow |= CAM_CTRL_RESET_N_MASK;
    }
    else
    {
        g_cam_ctrl_shadow &= ~CAM_CTRL_RESET_N_MASK;
    }

    cam_ctrl_write_shadow();
    alt_busy_sleep(CAM_RESET_DELAY_US);

    return 0;
}

/**
 * @brief     interface delay ms
 * @param[in] ms time
 * @note      none
 */
void ov2640_interface_delay_ms(uint32_t ms)
{
    alt_busy_sleep(ms * 1000u);
}

/**
 * @brief     interface print format data
 * @param[in] fmt format data
 * @note      none
 */
void ov2640_interface_debug_print(const char *const fmt, ...)
{
#if defined(JTAG_UART_0_BASE) && (JTAG_UART_0_BASE == 0x88u)
    (void)fmt;
#else
    va_list args;

    va_start(args, fmt);
    (void)vprintf(fmt, args);
    va_end(args);
    (void)fflush(stdout);
#endif
}
