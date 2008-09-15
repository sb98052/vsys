/* dcookie retrieval vsys entry, required by Chopstix.
 * The lookup_dcookie system call retrieves a pathname */

#define __NR_LOOKUP_DCOOKIE 253

#include <sys/syscall.h>
#include <asm/page.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

#define INT64_MAXSZ	"18446744073709551615Z"

int lookup_dcookie(uint64_t cookie, char * buf, size_t size)
{
	        return syscall(__NR_LOOKUP_DCOOKIE, cookie, buf, size);
}

int main(int argc,char *argv[]) {
		/* fs/dcookie.c uses PAGE_SIZE */
		char path_buf[16384],dcookie_buf[sizeof(INT64_MAXSZ)];

		/* In case nothing happens */
		path_buf[0]='\0';

		while (fgets(dcookie_buf, sizeof(dcookie_buf),stdin)) {
			if (lookup_dcookie(atoll(dcookie_buf), path_buf, sizeof(path_buf))>0) {	
					printf("%s\n",path_buf);
			}
			else {
					printf("% Not found\n");
			}
		}
}
