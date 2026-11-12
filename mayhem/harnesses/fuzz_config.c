/* Config (.ini) file parser plus a walk over everything it produced and a save round trip. */
#include "common.h"

static uint8_t save_buf[1 << 16];

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
   (void)argc;
   (void)argv;
   a5_init();
   return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
   ALLEGRO_FILE *f = a5_open(data, size);
   ALLEGRO_CONFIG *cfg = al_load_config_file_f(f);
   al_fclose(f);
   if (!cfg)
      return -1;

   ALLEGRO_CONFIG_SECTION *sec;
   const char *sname = al_get_first_config_section(cfg, &sec);
   while (sname) {
      ALLEGRO_CONFIG_ENTRY *ent;
      const char *key = al_get_first_config_entry(cfg, sname, &ent);
      while (key) {
         volatile const char *v = al_get_config_value(cfg, sname, key);
         (void)v;
         key = al_get_next_config_entry(&ent);
      }
      sname = al_get_next_config_section(&sec);
   }

   ALLEGRO_FILE *out = al_open_memfile(save_buf, sizeof save_buf, "w");
   if (!out)
      abort();
   al_save_config_file_f(out, cfg);
   al_fclose(out);

   al_destroy_config(cfg);
   return 0;
}
