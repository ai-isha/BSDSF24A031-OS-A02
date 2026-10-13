/*
* Programming Assignment 02: lsv1.2.0
* Adds: default multi-column output ("down then across"), terminal-width aware.
* Retains: -l long listing from v1.1.0.
* Usage:
*   $ ./bin/ls-v1.2.0
*   $ ./bin/ls-v1.2.0 -l
*   $ ./bin/ls-v1.2.0 /home
*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <pwd.h>
#include <grp.h>
#include <time.h>

extern int errno;

static int g_long = 0;

void do_ls(const char *dir, int long_format);
void list_long(const char *dir, const char *name);
void list_columns(const char *dir);
void format_perms(mode_t mode, char *buf);
void format_time(time_t t, char *buf);
int  get_terminal_width(void);

int main(int argc, char *argv[])
{
    int opt;
    while ((opt = getopt(argc, argv, "l")) != -1)
    {
        switch (opt)
        {
            case 'l':
                g_long = 1;
                break;
            default:
                fprintf(stderr, "Usage: %s [-l] [dir ...]\n", argv[0]);
                return 1;
        }
    }

    if (optind == argc)
    {
        if (g_long)
            do_ls(".", 1);
        else
            list_columns(".");
    }
    else
    {
        for (int i = optind; i < argc; i++)
        {
            if (argc - optind > 1)
                printf("%s:\n", argv[i]);

            if (g_long)
                do_ls(argv[i], 1);
            else
                list_columns(argv[i]);

            if (i < argc - 1)
                puts("");
        }
    }
    return 0;
}

/* ---------- Plain (single-line) listing, kept for -l path ---------- */
void do_ls(const char *dir, int long_format)
{
    struct dirent *entry;
    DIR *dp = opendir(dir);
    if (dp == NULL)
    {
        fprintf(stderr, "Cannot open directory : %s\n", dir);
        return;
    }

    errno = 0;
    while ((entry = readdir(dp)) != NULL)
    {
        if (entry->d_name[0] == '.')
            continue;
        if (long_format)
            list_long(dir, entry->d_name);
        else
            printf("%s\n", entry->d_name);
    }
    if (errno != 0)
        perror("readdir failed");
    closedir(dp);
}

/* ---------- Task 2: Column listing ---------- */
void list_columns(const char *dir)
{
    DIR *dp = opendir(dir);
    if (dp == NULL)
    {
        fprintf(stderr, "Cannot open directory : %s\n", dir);
        return;
    }

    /* 1. Dynamically collect filenames + track longest */
    size_t cap = 64, count = 0;
    size_t maxlen = 0;
    char **files = malloc(cap * sizeof(char *));
    if (!files) { perror("malloc"); closedir(dp); return; }

    struct dirent *entry;
    errno = 0;
    while ((entry = readdir(dp)) != NULL)
    {
        if (entry->d_name[0] == '.')
            continue;

        if (count == cap)
        {
            cap *= 2;
            char **tmp = realloc(files, cap * sizeof(char *));
            if (!tmp) { perror("realloc"); break; }
            files = tmp;
        }
        files[count] = strdup(entry->d_name);
        size_t l = strlen(entry->d_name);
        if (l > maxlen) maxlen = l;
        count++;
    }
    if (errno != 0) perror("readdir failed");
    closedir(dp);

    if (count == 0) { free(files); return; }

    /* 2. Task 3: calculate columns / rows */
    int term_w = get_terminal_width();
    int spacing = 2;                         /* min gap between columns */
    int col_width = (int)maxlen + spacing;   /* cell width */
    if (col_width <= 0) col_width = 1;

    int cols = term_w / col_width;
    if (cols < 1) cols = 1;
    if ((size_t)cols > count) cols = (int)count;

    int rows = (int)((count + cols - 1) / cols); /* ceil */

    /* 3. Task 4: down-then-across printing
     *    file at row r, col c = files[c * rows + r]
     */
    for (int r = 0; r < rows; r++)
    {
        for (int c = 0; c < cols; c++)
        {
            size_t idx = (size_t)c * rows + r;
            if (idx >= count) continue;

            int is_last = (c == cols - 1) || (idx + rows >= count);
            if (is_last)
                printf("%s", files[idx]);           /* last in row: no padding */
            else
                printf("%-*s", col_width, files[idx]); /* pad to col_width */
        }
        putchar('\n');
    }

    /* 4. Cleanup */
    for (size_t i = 0; i < count; i++) free(files[i]);
    free(files);
}

/* ---------- Long listing (from v1.1.0) ---------- */
void list_long(const char *dir, const char *name)
{
    char fullpath[4096];
    snprintf(fullpath, sizeof(fullpath), "%s/%s", dir, name);

    struct stat st;
    if (lstat(fullpath, &st) == -1) { perror("lstat"); return; }

    char perms[11];
    format_perms(st.st_mode, perms);

    struct passwd *pw = getpwuid(st.st_uid);
    const char *owner = pw ? pw->pw_name : "?";

    struct group *gr = getgrgid(st.st_gid);
    const char *group = gr ? gr->gr_name : "?";

    char timebuf[64];
    format_time(st.st_mtime, timebuf);

    printf("%s %3lu %-8s %-8s %8ld %s %s\n",
           perms, (unsigned long)st.st_nlink, owner, group,
           (long)st.st_size, timebuf, name);
}

void format_perms(mode_t mode, char *buf)
{
    if (S_ISDIR(mode))       buf[0] = 'd';
    else if (S_ISLNK(mode))  buf[0] = 'l';
    else if (S_ISCHR(mode))  buf[0] = 'c';
    else if (S_ISBLK(mode))  buf[0] = 'b';
    else if (S_ISFIFO(mode)) buf[0] = 'p';
    else if (S_ISSOCK(mode)) buf[0] = 's';
    else                     buf[0] = '-';

    buf[1] = (mode & S_IRUSR) ? 'r' : '-';
    buf[2] = (mode & S_IWUSR) ? 'w' : '-';
    buf[3] = (mode & S_ISUID) ? ((mode & S_IXUSR) ? 's' : 'S')
                              : ((mode & S_IXUSR) ? 'x' : '-');

    buf[4] = (mode & S_IRGRP) ? 'r' : '-';
    buf[5] = (mode & S_IWGRP) ? 'w' : '-';
    buf[6] = (mode & S_ISGID) ? ((mode & S_IXGRP) ? 's' : 'S')
                              : ((mode & S_IXGRP) ? 'x' : '-');

    buf[7] = (mode & S_IROTH) ? 'r' : '-';
    buf[8] = (mode & S_IWOTH) ? 'w' : '-';
    buf[9] = (mode & S_ISVTX) ? ((mode & S_IXOTH) ? 't' : 'T')
                              : ((mode & S_IXOTH) ? 'x' : '-');

    buf[10] = '\0';
}

void format_time(time_t t, char *buf)
{
    struct tm *tm_info = localtime(&t);
    strftime(buf, 64, "%b %e %H:%M", tm_info);
}

/* ---------- Task 3: terminal width via ioctl(TIOCGWINSZ) ---------- */
int get_terminal_width(void)
{
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0)
        return (int)ws.ws_col;
    return 80; /* fallback */
}
