#include <stdlib.h>

#include "yaml.h"

yaml_parser_t *
yaml__allocate_parser(void)
{
  return malloc (sizeof (yaml_parser_t));
}

void
yaml__deallocate_parser(yaml_parser_t *parser)
{
  free (parser);
}
