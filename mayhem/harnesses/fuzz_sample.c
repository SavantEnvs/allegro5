/* Audio sample loaders (WAV, VOC, FLAC, Ogg Vorbis, Opus, tracker modules), picked by signature. */
#include "common.h"
#include <allegro5/allegro_audio.h>
#include <allegro5/allegro_acodec.h>

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
   (void)argc;
   (void)argv;
   a5_init();
   /* The destructor list that samples register with is set up even when no sound driver is
    * available (headless), so the result is deliberately ignored. */
   al_install_audio();
   if (!al_init_acodec_addon())
      abort();
   return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
   ALLEGRO_FILE *f = a5_open(data, size);
   const char *ident = al_identify_sample_f(f);
   if (!ident) {
      al_fclose(f);
      return -1;
   }
   al_fseek(f, 0, ALLEGRO_SEEK_SET);

   ALLEGRO_SAMPLE *s = al_load_sample_f(f, ident);
   al_fclose(f);
   if (!s)
      return -1;

   al_destroy_sample(s);
   return 0;
}
