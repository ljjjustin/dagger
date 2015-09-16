#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <time.h>
#include <linux/fs.h>

void set_append_only(const char *logfile)
{
    int  logfd;
    long flags;

    logfd = open(logfile, O_RDONLY|O_NONBLOCK);
    if (logfd < 0) {
            exit(-1);
        }

    ioctl(logfd, FS_IOC_GETFLAGS, &flags);
    flags |= FS_APPEND_FL;
    ioctl(logfd, FS_IOC_SETFLAGS, &flags);

    close(logfd);
}

int main(int argc, char *argv[])
{
    char *logfile;

    if (argc < 1) {
            exit(-1);
        }

    logfile = argv[1];
    set_append_only(logfile);

    return 0;
}
