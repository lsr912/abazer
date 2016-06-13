#include <stdio.h>
#include <stdlib.h>

struct demo {
	int i;
	char *s;
};

struct demo*
test (struct demo *q)
{
	struct demo *t;

	t = q;
	return t;
}

void
main(void)
{
	struct demo *p, *r;
	int i;
	
	p = malloc(sizeof (struct demo));
	p->s = malloc (4);
	
	r = test(p);

	free(r->s);
	free(r);
	free(p->s);
	free(p);
}
