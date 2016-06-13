char *p;
void
test (void)
{
	int i = 0;

	if (i > 0) {
		p = malloc (4);
		exit(1);
	} else
		p = malloc (8);
}

void
main(void)
{
	test();
	free (p);
}
