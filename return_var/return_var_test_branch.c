int *
test(void)
{
	int i;
	int *p, *t;

	if (i > 0) {
		p = malloc(4);
		free (p);
		return p;
	}

	return t;
}

int
main(void)
{
	int *q;

	q = test();
	free (q);
}
