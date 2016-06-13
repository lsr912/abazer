void
test (char **q)
{
	free (*q);
}

int
main(void)
{
	char *p;

	p = malloc (4);
	test (&p);
	free (p);
}
