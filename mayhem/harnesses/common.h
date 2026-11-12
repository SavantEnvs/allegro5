/* Shared setup for the Allegro 5 harnesses. Allegro's X11 system driver starts in headless
 * mode when no X server is reachable, so al_init() works with no display; every bitmap is a
 * memory bitmap. */
#ifndef MAYHEM_COMMON_H
#define MAYHEM_COMMON_H

#include <allegro5/allegro.h>
#include <allegro5/allegro_memfile.h>
#include <stdint.h>
#include <stdlib.h>

static void a5_init(void)
{
   if (!al_init())
      abort();
   al_set_new_bitmap_flags(ALLEGRO_MEMORY_BITMAP);
}

/* Read-only view of the fuzzer's input, as the ALLEGRO_FILE every *_f loader takes. */
static ALLEGRO_FILE *a5_open(const uint8_t *data, size_t size)
{
   ALLEGRO_FILE *f = al_open_memfile((void *)data, (int64_t)size, "r");
   if (!f)
      abort();
   return f;
}

#endif
