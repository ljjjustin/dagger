#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>

int main(int argc, char *argv[])
{
    int i, rate;
    FILE *meminfo;
    unsigned char *pool, *mem_start, *mem_end;
    unsigned long memtotal, alloc_size, update_size;
    unsigned long busy, delta;
    struct timeval start, end;

    const int TIMES = 100;
    const int INTERVAL = (1000000/TIMES);

    rate = 100;
    if (argc != 2)
    {
        printf("usage: %s [rate]", argv[0]);
        printf("warning: rate was set to 100 MB/s");
    }
    else
    {
        rate = atoi(argv[1]);
        if (rate < 0)
        {
            printf("warning: rate should NOT be a negative integer");
            printf("warning: rate was set to 100 MB/s");
        }
    }

    /* get total memory capacity */
    meminfo = popen("cat /proc/meminfo | grep -i memtotal | awk '{print $2}'", "r");
    fscanf(meminfo, "%ld", &memtotal);
    pclose(meminfo);

    /* alloc half of total memory for write */
    alloc_size = (memtotal * 1024) / 2;
    pool = (unsigned char *)malloc(alloc_size);
    if (pool == NULL)
    {
        printf("warning: allocate memory failed, exiting ...");
        exit(-1);
    }
    update_size = (rate * 1024 * 1024) / TIMES;
    mem_start = pool; mem_end = pool + alloc_size;

    while (1)
    {
        gettimeofday(&start, NULL);
        /* write some random number to memory */
        if ((mem_start + update_size) >= mem_end)
        {
            mem_start = pool;
        }
        for (i = 0; i < update_size; i++)
            mem_start[i] = i % 256;
        mem_start += update_size;

        gettimeofday(&end, NULL);
        delta = 1000000 * (end.tv_sec - start.tv_sec)
            + (end.tv_usec - start.tv_usec);
        if (delta < INTERVAL)
            usleep(INTERVAL-delta);
    }
    free(pool);

    return 0;
}
