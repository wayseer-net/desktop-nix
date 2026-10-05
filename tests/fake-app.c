// Stands in for the app: prints its argv[0], its arguments and its LD_LIBRARY_PATH, a line each.
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
	const char *path = getenv("LD_LIBRARY_PATH");
	printf("%s\n", argv[0]);
	for (int i = 1; i < argc; i++) printf("%s|", argv[i]);
	printf("\n%s\n", path ? path : "(unset)");
	return 0;
}
