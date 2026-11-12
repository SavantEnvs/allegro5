/* TrueType/OpenType loading and text layout/rendering through the TTF addon. */
#include "common.h"
#include <allegro5/allegro_font.h>
#include <allegro5/allegro_ttf.h>

static ALLEGRO_BITMAP *canvas;

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
   (void)argc;
   (void)argv;
   a5_init();
   if (!al_init_font_addon() || !al_init_ttf_addon())
      abort();
   canvas = al_create_bitmap(256, 64);
   if (!canvas)
      abort();
   al_set_target_bitmap(canvas);
   return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
   /* The font owns the file once loaded; FreeType closes it itself when loading fails. */
   ALLEGRO_FILE *f = a5_open(data, size);
   ALLEGRO_FONT *font = al_load_ttf_font_f(f, "input.ttf", 16, 0);
   if (!font)
      return -1;

   static const char text[] = "Allegro 5: The quick brown fox, 0123456789";
   volatile int width = al_get_text_width(font, text);
   (void)width;
   al_draw_text(font, al_map_rgb(255, 255, 255), 0, 0, 0, text);

   al_destroy_font(font);
   return 0;
}
