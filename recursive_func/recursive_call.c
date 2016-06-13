char *test (int n)
{
	char *p;
	
	if (n == 1)
		p = malloc (4);
	else if (n > 1)
		p = test (n - 1);

	return p;
}

void main(void)
{
	char *p;

	p = test (3);

	free (p);
}
