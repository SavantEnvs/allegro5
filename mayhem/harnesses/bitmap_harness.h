/* Loads the input as one bitmap format through the image addon. Define BITMAP_EXT to pin the
 * loader (".bmp", ".tga", ...); leave it undefined to let al_identify_bitmap_f pick by signature. */
#include "common.h"
#include <allegro5/allegro_image.h>

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
   (void)argc;
   (void)argv;
   a5_init();
   if (!al_init_image_addon())
      abort();
   return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
   ALLEGRO_FILE *f = a5_open(data, size);
#ifdef BITMAP_EXT
   const char *ident = BITMAP_EXT;
#else
   const char *ident = al_identify_bitmap_f(f);
   if (!ident) {
      al_fclose(f);
      return -1;
   }
#endif

   ALLEGRO_BITMAP *bmp = al_load_bitmap_f(f, ident);
   al_fclose(f);
   if (!bmp)
      return -1;

   /* Read back the first and last decoded pixels so the decoded buffer is exercised. */
   int w = al_get_bitmap_width(bmp);
   int h = al_get_bitmap_height(bmp);
   ALLEGRO_COLOR a = al_get_pixel(bmp, 0, 0);
   ALLEGRO_COLOR b = al_get_pixel(bmp, w - 1, h - 1);
   volatile float sink = a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a;
   (void)sink;

   al_destroy_bitmap(bmp);
   return 0;
}
