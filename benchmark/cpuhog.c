#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>

const int INTERVAL = 100000;

int main(int argc, char *argv[])
{
    unsigned long i, j, p = 100;
    unsigned long busy, delta;
    struct timeval start, end;

    if (argc != 2)
    {
        printf("usage: %s [percentage]", argv[0]);
        printf("warning: percentage was set to 100");
    }
    else
    {
        p = atoi(argv[1]);
        if (p < 0 || p > 100)
            p = 100;
    }

    srand(time(NULL));

    while (1)
    {
        busy = p * 1000;
        gettimeofday(&start, NULL);
        while (1) {
            for (j = 0; j < 32768; j++)
                i += j;
            i = i ^ rand();
            gettimeofday(&end, NULL);
            delta = 1000000 * (end.tv_sec - start.tv_sec)
                + (end.tv_usec - start.tv_usec);
            if (delta >= busy) break;
        }
        if (delta < INTERVAL)
            usleep(INTERVAL-delta);
    }

    return 0;
}
