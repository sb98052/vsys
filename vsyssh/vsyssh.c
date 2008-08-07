/* gcc -Wall -O2 -g chpid.c -o chpid */
#define _XOPEN_SOURCE
#define _XOPEN_SOURCE_EXTENDED
#define _SVID_SOURCE
#define _GNU_SOURCE
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/select.h>
#include <sys/resource.h>
#include <sys/mount.h>
#include <sys/vfs.h>
#include <fcntl.h>
#include <unistd.h>
#include <sched.h>
#include <stdarg.h>
#include <dirent.h>

void pipe_handler (int sig) {
	printf("SIGPIPE");
}

int main(int argc, char **argv, char **envp)
{
	if (argc<2) {
		printf("Usage: vsyssh <vsys entry> [cmd]\n");
		exit(1);
	}
	else {
		int vfd0,vfd1;
		char *inf,*outf;
		struct timeval tv;

		signal(SIGPIPE,pipe_handler);
		inf=(char *)malloc(strlen(argv[1])+3);
		outf=(char *)malloc(strlen(argv[1])+4);
		strcpy(inf,argv[1]);
		strcpy(outf,argv[1]);
		strcat(inf,".in");
		strcat(outf,".out");

		vfd0 = open(outf,O_RDONLY|O_NONBLOCK);
		printf("Out file: %d\n",vfd0);
		vfd1 = open(inf,O_WRONLY);
		printf("In file: %d\n",vfd1);

		if (vfd0==-1 || vfd1 == -1) {
			printf("Error opening vsys entry %s (%s)\n", argv[1],strerror(errno));
			exit(1);
		}

		if (argc<3) {
			fd_set set;
			FD_ZERO(&set);
			FD_SET(0, &set);
			FD_SET(vfd0, &set);

			while (1)
			 {
				int ret;
				printf("vsys>");fflush(stdout);
				FD_SET(0, &set);
				FD_SET(vfd0, &set);
				ret = select(vfd0+1, &set, NULL, NULL, NULL);
				if (FD_ISSET(0,&set)) {
					char lineread[2048];
					int ret;
					ret=read(0,lineread,2048);
					lineread[ret]='\0';
					printf ("writing %s\n",lineread);
					write(vfd1,lineread,ret);
					FD_CLR(0,&set);
				} if (FD_ISSET(vfd0,&set)) {
					char lineread[2048];
					int ret;
					ret=read(vfd0,lineread,2048);
					write(1,lineread,ret);
					FD_CLR(vfd0,&set);
				}
			}

		}
		else {
			close(0);
			close(1);

			dup2(vfd0,0);
			dup2(vfd1,1);
			execve(argv[3],argv+3,envp);
		}
       }

       return;

}
