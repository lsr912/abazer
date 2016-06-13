void
test (char **q)
{
	free (*q);
}

int
main(void)
{
	char *p;
	char *q;
	char *r;
	int i;

	p = malloc(4);
	q = malloc(4);
	if( i > 0 )
		r = p;
	else
		r = q;

	test(&r);
	free(p);
	free(q);
}
