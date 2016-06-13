#include <stdlib.h>

extern int *q;

void
test1(void)
{
	free (q);
}

