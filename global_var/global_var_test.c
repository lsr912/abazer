#include <stdlib.h>

int *q;

void
test(void)
{
	q = malloc (4);
}

void
test1(void)
{
	free (q);
}

int
main(void)
{
	test ();
	test1();
}
