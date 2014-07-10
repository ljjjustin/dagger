#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <ctype.h>

int main(int argc, char *argv[])
{
    int i, t, size;
    char outfile[32];
    char content[1024];
    FILE *fp = NULL;

    size = 1;
    if (argc != 2)
    {
        printf("usage: %s [size(KB)]\n", argv[0]);
        printf("warning: size = 1KB\n");
    }
    else
    {
        size = atoi(argv[1]);
        if (size < 0 || size > 65535)
            size = 1;
    }

    snprintf(outfile, sizeof(outfile), "%dK.html", size);

    fp = fopen(outfile, "w");
    if (fp == NULL)
    {
        printf("failed on open '%s'\n", outfile);
    }

    srand(time(NULL));
    while (size > 0)
    {
        for (i = 0; i < 1024;)
        {
            t = rand() % 256;
            if (isalnum(t))
                content[i++] = t;
        }
        fwrite(content, 1024, 1, fp);
        size--;
    }
    fclose(fp);

    return 0;
}
