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
		vfd1 = open(inf,O_WRONLY);

		if (vfd0==-1 || vfd1 == -1) {
			printf("Error opening vsys entry %s (%s)\n", argv[1],strerror(errno));
			exit(1);
		}

		if (fcntl(vfd0, F_SETFL, O_RDONLY) == -1) {
			printf("Error making pipe blocking: %m\n");
			exit(1);
		}

		if (argc<3) {
			fd_set set;
			char do_input = 1, do_output = 1;

			while (1)
			{
				int ret;
				printf("vsys>");fflush(stdout);
				FD_ZERO(&set);
				if (do_input)
					FD_SET(0, &set);
				if (do_output)
					FD_SET(vfd0, &set);
				ret = select(vfd0+1, &set, NULL, NULL, NULL);
				if (FD_ISSET(0,&set)) {
					char lineread[2048];
					int ret;
					ret=read(0,lineread,2048);
					if (ret == 0)
						do_input = 0;
					lineread[ret]='\0';
					printf ("writing %s\n",lineread);
					write(vfd1,lineread,ret);
				}
				if (FD_ISSET(vfd0,&set)) {
					char lineread[2048];
					int ret;
					ret = read(vfd0,lineread,2048);
					if (ret == 0)
						break;
					write(1,lineread,ret);
				}
			}

		}
		else {
			close(0);
			close(1);

			dup2(vfd0,0);
			dup2(vfd1,1);
			execve(argv[2],argv+2,envp);
		}
       }

       return -1;

}
