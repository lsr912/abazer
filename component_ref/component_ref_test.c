#include <stdio.h>
#include <stdlib.h>

struct demo {
	char *j;
	struct demo *s;
};

int
test (struct demo *q)
{

	(q->j) = malloc (4);
}

void
main(void)
{
	struct demo p;
	
	test (&p);
	test (&p);
//	p->s->j = malloc (4);
//	free(p->s->j);
	free(p.j);
//	free (t);
}
