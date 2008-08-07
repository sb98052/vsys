#include <stdio.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

int main()
{
  FILE *fp = NULL, *fp_in = NULL;
  FILE *out_fp = NULL, *diff_fp = NULL;
  const char* topcmd = "fe/test.out";
  const char* top_in_file = "fe/test.in";
  char buf[4096];
  int fd_in = -1, fd_out;
  int res;
  int flag,flag2;
  int count = 1;
  struct timeval tv={.tv_sec=5,.tv_usec=0};

  while (count < 1000000) {
    fd_set readSet;
    int res;
    int nlines=0;

    //usleep(200);
    printf("(%d)", count);fflush(stdout);
    if ((fd_out = open(topcmd, O_RDONLY | O_NONBLOCK)) < 0) {
      fprintf(stderr, "error executing top\n");
      exit(-1);
    }

    //printf("((0))");fflush(stdout);
    while ((fd_in = open(top_in_file, O_WRONLY| O_NONBLOCK)) < 0) {
      fprintf(stderr, "Waiting for %s (%s)\n", top_in_file,strerror(errno));
     	usleep (50); 
    }

    //printf("(1)");
    if ((flag = fcntl(fd_out, F_GETFL)) == -1) {
      printf("fcntl get failed\n");
      exit(-1);
    }
    //printf("(2)");

    //printf("(3)");
	if ((flag2 = fcntl(fd_in, F_GETFL)) == -1) {
      printf("fcntl get failed\n");
      exit(-1);
    }
    //printf("(4)");


    while (1) {
	    FD_ZERO(&readSet);
	    FD_SET(fd_out, &readSet);

    //printf("(5)");
	    res = select(fd_out + 1, &readSet, NULL, NULL, NULL);
    //printf("(6)");
	    if (res < 0) {
		    if (errno == EINTR || errno == EAGAIN) {
			    printf(".");
			    continue;
		    }
		    fprintf(stderr,"select failed errno=%d errstr=%s\n", errno, strerror(errno));
		    exit(-1);
	    }
	    break; /* we're done */
    }

    //printf("(7)");
    if (fcntl(fd_out, F_SETFL, flag & ~O_NONBLOCK) == -1) {
      printf("fcntl set failed\n");
      exit(-1);
    }
    //printf("(8)");

    //printf("(9)");
    if ((flag = fcntl(fd_out, F_GETFL)) == -1) {
      printf("fcntl get failed\n");
      exit(-1);
    }
    //printf("(10)");


    //printf("(11)");
    if (fcntl(fd_in, F_SETFL, flag2 & ~O_NONBLOCK) == -1) {
      printf("fcntl set failed\n");
      exit(-1);
    }

    //printf("(11)");
    if ((flag2 = fcntl(fd_in, F_GETFL)) == -1) {
      printf("fcntl get failed\n");
      exit(-1);
    }
    //printf("(12)");

    if (flag & O_NONBLOCK == 0) {
      printf("fd_out still nonblocking\n");
      exit(-1);
    }

    if (flag & O_NONBLOCK == 0) {
      printf("fd_in still nonblocking\n");
      exit(-1);
    }
    if ((fp = fdopen(fd_out, "r")) == NULL) {
      printf("fdopen failed\n");
      exit(-1);
    }

    while (fgets(buf, sizeof(buf), fp) != NULL) {
	    nlines++;
    }

    if (nlines<5) {
	    printf("Test returned different results - run again to verify\n");
	    exit(-1);
    }

    fclose(fp);
    close(fd_in);
    close(fd_out);
    count++;
  }
  printf("test successful.\n");
  exit(0);

}
