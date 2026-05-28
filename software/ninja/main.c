#include <stdint.h>
#include <stdio.h>

#include "driver_ov2640_basic.h"
#include "driver_wm8731.h"
#include "io.h"
#include "priv/alt_busy_sleep.h"
#include "system.h"

#ifndef EFFECT_EVENT_PIO_BASE
#define EFFECT_EVENT_PIO_BASE 0x20u
#endif

#ifndef FRUIT3_DESC_PIO_BASE
#define FRUIT3_DESC_PIO_BASE 0x30u
#endif

#ifndef FRUIT2_DESC_PIO_BASE
#define FRUIT2_DESC_PIO_BASE 0x80u
#endif

#ifndef FRUIT1_DESC_PIO_BASE
#define FRUIT1_DESC_PIO_BASE 0x90u
#endif

#ifndef FRUIT0_DESC_PIO_BASE
#define FRUIT0_DESC_PIO_BASE 0xA0u
#endif

#ifndef GAME_CTRL_PIO_BASE
#define GAME_CTRL_PIO_BASE 0xB0u
#endif

#ifndef TRACKER_STATUS_PIO_BASE
#define TRACKER_STATUS_PIO_BASE 0xC0u
#endif

#ifndef FRAME_COUNTER_PIO_BASE
#define FRAME_COUNTER_PIO_BASE 0xD0u
#endif

#ifndef KEYS_PIO_BASE
#define KEYS_PIO_BASE 0xE0u
#endif

#define MAX_FRUITS 4
#define FP_SHIFT 4

#define GAME_START   0u
#define GAME_PLAYING 1u
#define GAME_OVER    2u
#define GAME_HIGHSCORES 3u

#define FRUIT_BOMB 5u

#define TRACKER_VALID_MASK (1u << 30)
#define KEY1_MASK          (1u << 1)
#define KEY2_MASK          (1u << 2)
#define KEY3_MASK          (1u << 3)
#define BLADE_CUT_MIN_DELTA 14u
#define FRUIT_HIT_PADDING 36u
#define COMBO_MAX_COUNT 4u
#define COMBO_BONUS_STEP 5u
#define BLADE_TRAIL_HIT_STEPS 8u

typedef struct fruit_state {
    uint8_t active;
    uint8_t type;
    int32_t x_fp;
    int32_t y_fp;
    int32_t vx_fp;
    int32_t vy_fp;
} fruit_state_t;

static fruit_state_t fruits[MAX_FRUITS];
static uint16_t lfsr = 0xACE1u;
static uint8_t commit_toggle;
static uint8_t effect_toggle;
static uint8_t game_state = GAME_START;
static uint8_t high_scores_return_state = GAME_START;
static uint16_t score_value;
static uint8_t bomb_hits;
static uint8_t time_tens = 6u;
static uint8_t time_ones;
static uint8_t second_frame_count;
static uint8_t auto_spawn_timer;
static uint8_t next_spawn_delay = 45u;
static uint8_t combo_count;
static uint16_t top_scores[5];
static uint8_t prev_blade_valid;
static uint16_t prev_blade_x;
static uint16_t prev_blade_y;
static uint16_t blade_cut_start_x;
static uint16_t blade_cut_start_y;
static uint16_t blade_cut_end_x;
static uint16_t blade_cut_end_y;

static void apply_score_delta(int16_t delta);

static uint32_t pio_read(uint32_t base)
{
    return IORD_32DIRECT(base, 0);
}

static void pio_write(uint32_t base, uint32_t value)
{
    IOWR_32DIRECT(base, 0, value);
}

static void reset_blade_motion(void)
{
    prev_blade_valid = 0u;
    prev_blade_x = 0u;
    prev_blade_y = 0u;
    blade_cut_start_x = 0u;
    blade_cut_start_y = 0u;
    blade_cut_end_x = 0u;
    blade_cut_end_y = 0u;
}

static void reset_combo(void)
{
    combo_count = 0u;
}

static int16_t register_fruit_slice(void)
{
    int16_t score_delta = 10;

    if (combo_count < COMBO_MAX_COUNT)
    {
        combo_count++;
    }

    if (combo_count > 1u)
    {
        score_delta += (int16_t)((combo_count - 1u) * COMBO_BONUS_STEP);
    }

    if (score_delta > 25)
    {
        score_delta = 25;
    }

    apply_score_delta(score_delta);
    return score_delta;
}

static int16_t multi_slice_bonus(uint8_t sliced_count)
{
    switch (sliced_count)
    {
        case 2u:
            return 10;
        case 3u:
            return 25;
        case 4u:
            return 25;
        default:
            return 0;
    }
}

static uint16_t abs_i32(int32_t value)
{
    return (uint16_t)((value < 0) ? -value : value);
}

static uint8_t ellipse_hit_i32(int32_t dx, int32_t dy, uint16_t rx, uint16_t ry)
{
    int64_t dx64 = dx;
    int64_t dy64 = dy;
    int64_t rx64 = rx;
    int64_t ry64 = ry;
    int64_t lhs = (dx64 * dx64 * ry64 * ry64) +
                  (dy64 * dy64 * rx64 * rx64);
    int64_t rhs = rx64 * rx64 * ry64 * ry64;

    return (lhs <= rhs) ? 1u : 0u;
}

static uint8_t blade_trail_hits_ellipse(int32_t fruit_x, int32_t fruit_y, uint16_t rx, uint16_t ry)
{
    uint8_t step;
    int32_t start_x = (int32_t)blade_cut_start_x;
    int32_t start_y = (int32_t)blade_cut_start_y;
    int32_t dx = (int32_t)blade_cut_end_x - start_x;
    int32_t dy = (int32_t)blade_cut_end_y - start_y;

    for (step = 0u; step <= BLADE_TRAIL_HIT_STEPS; step++)
    {
        int32_t sample_x = start_x + ((dx * (int32_t)step) / (int32_t)BLADE_TRAIL_HIT_STEPS);
        int32_t sample_y = start_y + ((dy * (int32_t)step) / (int32_t)BLADE_TRAIL_HIT_STEPS);

        if (ellipse_hit_i32(sample_x - fruit_x, sample_y - fruit_y, rx, ry))
        {
            return 1u;
        }
    }

    return 0u;
}

static uint8_t blade_cut_active(uint8_t blade_valid, uint16_t blade_x, uint16_t blade_y)
{
    uint8_t cut_active = 0u;

    if (blade_valid && prev_blade_valid)
    {
        uint16_t dx = abs_i32((int32_t)blade_x - (int32_t)prev_blade_x);
        uint16_t dy = abs_i32((int32_t)blade_y - (int32_t)prev_blade_y);

        if ((uint16_t)(dx + dy) >= BLADE_CUT_MIN_DELTA)
        {
            cut_active = 1u;
            blade_cut_start_x = prev_blade_x;
            blade_cut_start_y = prev_blade_y;
            blade_cut_end_x = blade_x;
            blade_cut_end_y = blade_y;
        }
    }

    if (blade_valid)
    {
        prev_blade_valid = 1u;
        prev_blade_x = blade_x;
        prev_blade_y = blade_y;
    }
    else
    {
        prev_blade_valid = 0u;
    }

    return cut_active;
}

static uint16_t fruit_half_width(uint8_t type)
{
    switch (type)
    {
        case 2u:
            return 49u;
        case 3u:
            return 31u;
        case 4u:
            return 63u;
        case FRUIT_BOMB:
            return 33u;
        default:
            return 32u;
    }
}

static uint16_t fruit_half_height(uint8_t type)
{
    switch (type)
    {
        case 2u:
            return 43u;
        case 3u:
            return 30u;
        case 4u:
            return 25u;
        case FRUIT_BOMB:
            return 34u;
        default:
            return 32u;
    }
}

static void lfsr_step(void)
{
    uint16_t feedback = (uint16_t)(((lfsr >> 15) ^ (lfsr >> 13) ^ (lfsr >> 12) ^ (lfsr >> 10)) & 1u);
    lfsr = (uint16_t)((lfsr << 1) | feedback);

    if (lfsr == 0u)
    {
        lfsr = 0xACE1u;
    }
}

static uint8_t first_free_fruit(void)
{
    uint8_t i;

    for (i = 0; i < MAX_FRUITS; i++)
    {
        if (!fruits[i].active)
        {
            return i;
        }
    }

    return MAX_FRUITS;
}

static uint8_t all_fruits_active(void)
{
    uint8_t i;

    for (i = 0; i < MAX_FRUITS; i++)
    {
        if (!fruits[i].active)
        {
            return 0u;
        }
    }

    return 1u;
}

static void clear_fruits(void)
{
    uint8_t i;

    for (i = 0; i < MAX_FRUITS; i++)
    {
        fruits[i].active = 0u;
        fruits[i].type = 0u;
        fruits[i].x_fp = 320 << FP_SHIFT;
        fruits[i].y_fp = 479 << FP_SHIFT;
        fruits[i].vx_fp = 0;
        fruits[i].vy_fp = 0;
    }
}

static void record_score(uint16_t score)
{
    uint8_t i;
    uint8_t j;

    for (i = 0u; i < 5u; i++)
    {
        if (score > top_scores[i])
        {
            for (j = 4u; j > i; j--)
            {
                top_scores[j] = top_scores[j - 1u];
            }

            top_scores[i] = score;
            break;
        }
    }
}

static void finish_game(void)
{
    clear_fruits();
    record_score(score_value);
    game_state = GAME_OVER;
}

static void start_game(void)
{
    clear_fruits();
    score_value = 0u;
    bomb_hits = 0u;
    time_tens = 6u;
    time_ones = 0u;
    second_frame_count = 0u;
    auto_spawn_timer = 0u;
    next_spawn_delay = 45u;
    reset_blade_motion();
    reset_combo();
    game_state = GAME_PLAYING;
}

static void spawn_fruit(void)
{
    uint8_t slot = first_free_fruit();
    int32_t vx_mag;
    int32_t vy_mag;
    uint8_t raw_type;

    if (slot == MAX_FRUITS)
    {
        return;
    }

    raw_type = (uint8_t)((lfsr >> 2) & 0x7u);
    if (raw_type > FRUIT_BOMB)
    {
        raw_type = (uint8_t)(lfsr & 0x3u);
    }

    vx_mag = 1 + ((lfsr >> 7) & 0x3u);
    vy_mag = 11 + ((lfsr >> 9) & 0x7u);

    fruits[slot].active = 1u;
    fruits[slot].type = raw_type;
    fruits[slot].x_fp = (160 + (((lfsr >> 2) & 0xFu) * 20)) << FP_SHIFT;
    fruits[slot].y_fp = 479 << FP_SHIFT;
    fruits[slot].vx_fp = ((lfsr & (1u << 6)) ? vx_mag : -vx_mag) * (1 << FP_SHIFT);
    fruits[slot].vy_fp = -vy_mag * (1 << FP_SHIFT);

    auto_spawn_timer = 0u;
    next_spawn_delay = (uint8_t)(24u + ((lfsr >> 10) & 0x3Fu));
}

static void apply_score_delta(int16_t delta)
{
    int32_t next_score = (int32_t)score_value + delta;

    if (next_score < 0)
    {
        next_score = 0;
    }
    else if (next_score > 9999)
    {
        next_score = 9999;
    }

    score_value = (uint16_t)next_score;
}

static uint8_t popup_class_for_score(int16_t score_delta)
{
    if (score_delta >= 25)
    {
        return 3u;
    }
    if (score_delta >= 20)
    {
        return 2u;
    }
    if (score_delta >= 15)
    {
        return 1u;
    }

    return 0u;
}

static void emit_slice_effect(uint8_t slot, uint8_t popup_class)
{
    int32_t x = fruits[slot].x_fp >> FP_SHIFT;
    int32_t y = fruits[slot].y_fp >> FP_SHIFT;
    uint32_t word;

    if (x < 0)
    {
        x = 0;
    }
    else if (x > 639)
    {
        x = 639;
    }

    if (y < 0)
    {
        y = 0;
    }
    else if (y > 479)
    {
        y = 479;
    }

    effect_toggle ^= 1u;
    word = ((uint32_t)effect_toggle << 31) |
           ((uint32_t)(slot & 0x3u) << 29) |
           ((uint32_t)(fruits[slot].type & 0x7u) << 26) |
           (((uint32_t)x & 0xFFFu) << 14) |
           (((uint32_t)y & 0xFFFu) << 2) |
           ((uint32_t)popup_class & 0x3u);

    pio_write(EFFECT_EVENT_PIO_BASE, word);
}

static void update_fruits(uint8_t blade_valid, uint16_t blade_x, uint16_t blade_y)
{
    uint8_t i;
    uint8_t sliced_fruits_this_frame = 0u;
    uint8_t sliced_bomb_this_frame = 0u;

    (void)blade_x;
    (void)blade_y;

    for (i = 0; i < MAX_FRUITS; i++)
    {
        if (!fruits[i].active)
        {
            continue;
        }

        if (blade_valid)
        {
            int32_t fruit_x = fruits[i].x_fp >> FP_SHIFT;
            int32_t fruit_y = fruits[i].y_fp >> FP_SHIFT;
            uint16_t hit_w = fruit_half_width(fruits[i].type) + FRUIT_HIT_PADDING;
            uint16_t hit_h = fruit_half_height(fruits[i].type) + FRUIT_HIT_PADDING;

            if (blade_trail_hits_ellipse(fruit_x, fruit_y, hit_w, hit_h))
            {
                if (fruits[i].type == FRUIT_BOMB)
                {
                    emit_slice_effect(i, 0u);
                    reset_combo();
                    sliced_bomb_this_frame = 1u;
                    apply_score_delta(-30);
                    if (bomb_hits < 3u)
                    {
                        bomb_hits++;
                    }
                }
                else
                {
                    int16_t slice_score = register_fruit_slice();
                    emit_slice_effect(i, popup_class_for_score(slice_score));
                    sliced_fruits_this_frame++;
                }

                fruits[i].active = 0u;
                continue;
            }
        }

        fruits[i].x_fp += fruits[i].vx_fp;
        fruits[i].y_fp += fruits[i].vy_fp;
        fruits[i].vy_fp += 6;

        if ((fruits[i].x_fp < (-64 * (1 << FP_SHIFT))) ||
            (fruits[i].x_fp > (704 << FP_SHIFT)) ||
            (fruits[i].y_fp > (540 << FP_SHIFT)))
        {
            if (fruits[i].type != FRUIT_BOMB)
            {
                reset_combo();
                apply_score_delta(-5);
            }

            fruits[i].active = 0u;
        }
    }

    if ((sliced_fruits_this_frame > 1u) && !sliced_bomb_this_frame)
    {
        apply_score_delta(multi_slice_bonus(sliced_fruits_this_frame));
    }

}

static void update_timer(void)
{
    if ((time_tens == 0u) && (time_ones == 0u))
    {
        return;
    }

    if (second_frame_count == 59u)
    {
        second_frame_count = 0u;

        if (time_ones != 0u)
        {
            time_ones--;
        }
        else
        {
            time_ones = 9u;
            time_tens--;
        }
    }
    else
    {
        second_frame_count++;
    }
}

static uint32_t pack_fruit_desc(uint8_t slot)
{
    int32_t x = fruits[slot].x_fp >> FP_SHIFT;
    int32_t y = fruits[slot].y_fp >> FP_SHIFT;

    return ((uint32_t)(fruits[slot].active ? 1u : 0u) << 31) |
           ((uint32_t)(fruits[slot].type & 0x7u) << 28) |
           (((uint32_t)x & 0xFFFu) << 16) |
           (((uint32_t)y & 0xFFFu) << 4);
}

static uint32_t pack_score_pair(uint16_t low_score, uint16_t high_score)
{
    return ((uint32_t)(high_score & 0x3FFFu) << 16) |
           ((uint32_t)(low_score & 0x3FFFu));
}

static void publish_game_state(void)
{
    uint32_t ctrl;

    if (game_state == GAME_HIGHSCORES)
    {
        pio_write(FRUIT0_DESC_PIO_BASE, pack_score_pair(top_scores[0], top_scores[1]));
        pio_write(FRUIT1_DESC_PIO_BASE, pack_score_pair(top_scores[2], top_scores[3]));
        pio_write(FRUIT2_DESC_PIO_BASE, (uint32_t)(top_scores[4] & 0x3FFFu));
        pio_write(FRUIT3_DESC_PIO_BASE, 0u);
    }
    else
    {
        pio_write(FRUIT0_DESC_PIO_BASE, pack_fruit_desc(0));
        pio_write(FRUIT1_DESC_PIO_BASE, pack_fruit_desc(1));
        pio_write(FRUIT2_DESC_PIO_BASE, pack_fruit_desc(2));
        pio_write(FRUIT3_DESC_PIO_BASE, pack_fruit_desc(3));
    }

    commit_toggle ^= 1u;
    ctrl = ((uint32_t)commit_toggle << 31) |
           (1u << 30) |
           ((uint32_t)(game_state & 0x3u) << 28) |
           ((uint32_t)(bomb_hits & 0x3u) << 26) |
           ((uint32_t)(score_value & 0x3FFFu) << 12) |
           ((uint32_t)(time_tens & 0xFu) << 8) |
           ((uint32_t)(time_ones & 0xFu) << 4);

    pio_write(GAME_CTRL_PIO_BASE, ctrl);
}

static void game_step(
    uint8_t key1_pressed,
    uint8_t key2_pressed,
    uint8_t key3_pressed,
    uint8_t blade_valid,
    uint16_t blade_x,
    uint16_t blade_y
)
{
    lfsr_step();

    switch (game_state)
    {
        case GAME_START:
            clear_fruits();
            if (key1_pressed)
            {
                start_game();
            }
            else if (key2_pressed)
            {
                high_scores_return_state = GAME_START;
                game_state = GAME_HIGHSCORES;
            }
            break;

        case GAME_PLAYING:
            update_timer();
            update_fruits(blade_valid, blade_x, blade_y);

            if (((time_tens == 0u) && (time_ones == 0u)) || (bomb_hits >= 3u))
            {
                finish_game();
                break;
            }

            if (!all_fruits_active())
            {
                if ((auto_spawn_timer >= next_spawn_delay) || key2_pressed)
                {
                    spawn_fruit();
                }
                else if (auto_spawn_timer < 127u)
                {
                    auto_spawn_timer++;
                }
            }
            break;

        case GAME_OVER:
            clear_fruits();
            if (key2_pressed)
            {
                start_game();
            }
            else if (key1_pressed)
            {
                game_state = GAME_START;
            }
            else if (key3_pressed)
            {
                high_scores_return_state = GAME_OVER;
                game_state = GAME_HIGHSCORES;
            }
            break;

        case GAME_HIGHSCORES:
            clear_fruits();
            if (key1_pressed)
            {
                game_state = high_scores_return_state;
            }
            else if (key2_pressed)
            {
                start_game();
            }
            break;

        default:
            game_state = GAME_START;
            break;
    }
}

int main(void)
{
    uint32_t last_frame = pio_read(FRAME_COUNTER_PIO_BASE);
    uint32_t prev_keys = 0xFu;

    clear_fruits();
    publish_game_state();

    (void)wm8731_init();

    if (ov2640_basic_init() != 0)
    {
        while (1)
        {
        }
    }

    if (ov2640_basic_set_rgb565_mode() != 0)
    {
        while (1)
        {
        }
    }

    if (ov2640_basic_set_image_resolution(OV2640_IMAGE_RESOLUTION_QVGA) != 0)
    {
        while (1)
        {
        }
    }

    alt_busy_sleep(1000000u);

    while (1)
    {
        uint32_t frame = pio_read(FRAME_COUNTER_PIO_BASE);

        if (frame != last_frame)
        {
            uint32_t keys = pio_read(KEYS_PIO_BASE) & 0xFu;
            uint32_t tracker = pio_read(TRACKER_STATUS_PIO_BASE);
            uint8_t key1_pressed = ((prev_keys & KEY1_MASK) != 0u) && ((keys & KEY1_MASK) == 0u);
            uint8_t key2_pressed = ((prev_keys & KEY2_MASK) != 0u) && ((keys & KEY2_MASK) == 0u);
            uint8_t key3_down = ((keys & KEY3_MASK) == 0u);
            uint8_t key3_pressed = (((prev_keys & KEY3_MASK) != 0u) && key3_down) ||
                                   ((game_state == GAME_OVER) && key3_down);
            uint8_t blade_valid = (tracker & TRACKER_VALID_MASK) ? 1u : 0u;
            uint16_t blade_x = (uint16_t)((tracker >> 20) & 0x3FFu);
            uint16_t blade_y = (uint16_t)((tracker >> 10) & 0x3FFu);
            uint8_t blade_cut_valid = blade_cut_active(blade_valid, blade_x, blade_y);

            last_frame = frame;
            prev_keys = keys;

            game_step(key1_pressed, key2_pressed, key3_pressed, blade_cut_valid, blade_x, blade_y);
            publish_game_state();
        }
    }
}
