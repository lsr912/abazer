struct demo {
	void *p;
} *q;

extern void _mtx_lock_flags (void *l);
extern void _mtx_unlock_flags (void *l);

void
test (void)
{
	int i;

	if (i == 0)
		_mtx_lock_flags (&q->p);
	else if (i == 1)
		_mtx_unlock_flags (&q->p);
}

int
main(void)
{
	int i = 0;
	struct demo *w;
	
	test();
	test();
	test();
}
