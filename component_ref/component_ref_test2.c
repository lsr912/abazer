#include <stdio.h>
#include <stdlib.h>

struct demo {
	int i;
	char *s;
};

struct demo*
test ()
{
	struct demo *p;

	p = malloc(sizeof (struct demo));
	p->s = malloc (4);
	return p;
}

void
main(void)
{
	struct demo *r;
	
	
	r = test();

	free(r->s);
	free(r);
}
