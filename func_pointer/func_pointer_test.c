
//static void
//test(void)
//{
//	free (p);
//}

void (*f)(void);

int
main(void)
{

	static char *p;
	char *t;
	int i = 0;
	p = malloc (4);
	if (i == 0) {
		free (p);
		p = malloc (4);
		return 1;
	}

	t = malloc (4);
	free (t);	
	return 2;
//	free (p);
//	f = test;
//	f();
}
