int *
test(void)
{
//	int *q = malloc (4);
//	return q;
	
	return malloc (4);
}

int
main(void)
{
	int *p;

	p = test();
	free (p);
}
