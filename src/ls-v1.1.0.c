/*
* Programming Assignment 02: lsv1.1.0
* Adds: -l long listing format (permissions, links, owner, group, size, date, name)
* Usage:
*   $ ./bin/ls-v1.1.0
*   $ ./bin/ls-v1.1.0 -l
*   $ ./bin/ls-v1.1.0 -l /home
*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>
#include <time.h>

extern int errno;

static int g_long = 0;

void do_ls(const char *dir, int long_format);
void list_long(const char *dir, const char *name);
void format_perms(mode_t mode, char *buf);
void format_time(time_t t, char *buf);

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
        do_ls(".", g_long);
    }
    else
    {
        for (int i = optind; i < argc; i++)
        {
            if (argc - optind > 1)
                printf("%s:\n", argv[i]);
            do_ls(argv[i], g_long);
            if (i < argc - 1)
                puts("");
        }
    }
    return 0;
}

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

void list_long(const char *dir, const char *name)
{
    char fullpath[4096];
    snprintf(fullpath, sizeof(fullpath), "%s/%s", dir, name);

    struct stat st;
    if (lstat(fullpath, &st) == -1)
    {
        perror("lstat");
        return;
    }

    char perms[11];
    format_perms(st.st_mode, perms);

    struct passwd *pw = getpwuid(st.st_uid);
    const char *owner = pw ? pw->pw_name : "?";

    struct group *gr = getgrgid(st.st_gid);
    const char *group = gr ? gr->gr_name : "?";

    char timebuf[64];
    format_time(st.st_mtime, timebuf);

    printf("%s %3lu %-8s %-8s %8ld %s %s\n",
           perms,
           (unsigned long)st.st_nlink,
           owner,
           group,
           (long)st.st_size,
           timebuf,
           name);
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
    if (mode & S_ISUID)
        buf[3] = (mode & S_IXUSR) ? 's' : 'S';
    else
        buf[3] = (mode & S_IXUSR) ? 'x' : '-';

    buf[4] = (mode & S_IRGRP) ? 'r' : '-';
    buf[5] = (mode & S_IWGRP) ? 'w' : '-';
    if (mode & S_ISGID)
        buf[6] = (mode & S_IXGRP) ? 's' : 'S';
    else
        buf[6] = (mode & S_IXGRP) ? 'x' : '-';

    buf[7] = (mode & S_IROTH) ? 'r' : '-';
    buf[8] = (mode & S_IWOTH) ? 'w' : '-';
    if (mode & S_ISVTX)
        buf[9] = (mode & S_IXOTH) ? 't' : 'T';
    else
        buf[9] = (mode & S_IXOTH) ? 'x' : '-';

    buf[10] = '\0';
}

void format_time(time_t t, char *buf)
{
    struct tm *tm_info = localtime(&t);
    strftime(buf, 64, "%b %e %H:%M", tm_info);
}
