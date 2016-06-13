#include <stdio.h>
#include <stdlib.h>

struct demo {
	int i;
	char *s;
};

struct demo*
test (struct demo *p, struct demo *q)
{
	struct demo *t;
	int i;

	if (i >= 0) {
		t = p;
	}else{
		t = q;
	}
	return t;
}

void
main(void)
{
	struct demo *p, *q, *r;
	int i;
	
	p = malloc(sizeof (struct demo));
	p->s = malloc (4);
	q = malloc(sizeof (struct demo));
	q->s = malloc(4);
	
	r = test(p, q);

	free(r->s);
	free(r);
	free(p->s);
	free(p);
	free(q->s);
	free(q);
}
