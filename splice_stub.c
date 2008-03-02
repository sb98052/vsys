/* This module allows data between vsys clients and servers to be copied in kernel -
 * and some of these copies to be eliminated through page rewrites */

#define SPLICE_SYSCALL	313
#define TEE_SYSCALL	315
#define SPLICE_F_NONBLOCK 0x02

#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <sys/syscall.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/signals.h>

CAMLprim value stub_splice(value fd_in, value fd_out, value len)
{
        CAMLparam3(fd_in, fd_out, len);
	long ret;
        ret = syscall(SPLICE_SYSCALL, Int_val(fd_in), NULL, Int_val(fd_out),NULL, Int_val(len), SPLICE_F_NONBLOCK);
        if (ret == -1) {
		printf ("Splice error: %s\n", strerror(errno));
                caml_failwith("Splice system call returned -1");
	}
        CAMLreturn(Val_int(ret));
}

CAMLprim value stub_tee(value fd_in, value fd_out, value len)
{
        CAMLparam3(fd_in, fd_out, len);
	long ret;
        ret = syscall(TEE_SYSCALL,Int_val(fd_in), Int_val(fd_out), Int_val(len), SPLICE_F_NONBLOCK);
        if (ret == -1) {
		printf ("Sendfile error: %s\n", strerror(errno));
                caml_failwith("Splice system call returned -1");
	}
        CAMLreturn(Val_int(ret));
}
