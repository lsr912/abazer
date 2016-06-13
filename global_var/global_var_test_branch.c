#include <stdlib.h>

int *q;

void
test(void)
{
	int i;
	if(i > 0){
		q = malloc (4);
	}
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
