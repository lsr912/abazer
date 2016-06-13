#include <stdlib.h>

extern int *q;

void
test(void)
{
	q = malloc (4);
}
