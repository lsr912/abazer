#include <stdlib.h>

int *q;

void test(void);
void test1(void);

int
main(void)
{
	test ();
	test1();
	free(q);
}
