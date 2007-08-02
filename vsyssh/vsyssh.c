/* gcc -Wall -O2 -g chpid.c -o chpid */
#define _XOPEN_SOURCE
#define _XOPEN_SOURCE_EXTENDED
#define _SVID_SOURCE
#define _GNU_SOURCE
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/mount.h>
#include <sys/vfs.h>
#include <fcntl.h>
#include <unistd.h>
#include <sched.h>
#include <stdarg.h>
#include <dirent.h>

int main(int argc, char **argv, char **envp)
{
	if (argc<3) {
		printf("Usage: vsyssh <vsys entry> <cmd>\n");
		exit(1);
	}
	else {
		int vfd0,vfd1;
		char *inf,*outf;
		inf=(char *)malloc(strlen(argv[1])+3);
		outf=(char *)malloc(strlen(argv[2])+4);
		strcpy(inf,argv[1]);
		strcpy(inf,argv[2]);
		strcat(inf,".in");
		strcat(outf,".out");

		vfd1 = open(inf,O_WRONLY);
		vfd0 = open(outf,O_RDONLY);

		if (vfd0==-1 || vfd1 == -1) {
			printf("Error opening vsys entry %s\n", argv[1]);
			exit(1);
		}

		close(0);
		close(1);

		dup2(vfd0,0);
		dup2(vfd1,1);

		execve(argv[3],argv+3,envp);
       }

       return;

}
