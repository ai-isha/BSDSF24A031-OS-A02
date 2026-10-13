/*
* Programming Assignment 02: lsv1.6.0
* Adds: recursive listing with -R option
* Retains: -l (v1.1.0), default columns (v1.2.0), -x horizontal (v1.3.0),
*          alphabetical sort (v1.4.0), colored output (v1.5.0)
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

#define C_RESET   "\033[0m"
#define C_BLUE    "\033[0;34m"
#define C_GREEN   "\033[0;32m"
#define C_RED     "\033[0;31m"
#define C_MAGENTA "\033[0;35m"
#define C_REVERSE "\033[7m"

enum display_mode {
    MODE_COLUMN,
    MODE_LONG,
    MODE_HORIZONTAL
};

static enum display_mode g_mode = MODE_COLUMN;
static int g_color = 1;
static int g_recursive = 0;
static int g_first_dir_printed = 0;

void do_ls(const char *dir);
void do_ls_long(const char *dir);
void list_long(const char *dir, const char *name);
void list_columns(const char *dir);
void list_horizontal(const char *dir);
void format_perms(mode_t mode, char *buf);
void format_time(time_t t, char *buf);
int  get_terminal_width(void);
int  cmp_filenames(const void *a, const void *b);
const char *color_for(mode_t mode, const char *name);
int  has_archive_ext(const char *name);

/* Forward-declare helpers used by list_* that need color */
static char **collect_files_sorted(const char *dir, size_t *count_out, size_t *maxlen_out);

int main(int argc, char *argv[])
{
    int opt;
    while ((opt = getopt(argc, argv, "lxR")) != -1)
    {
        switch (opt)
        {
            case 'l': g_mode = MODE_LONG;       break;
            case 'x': g_mode = MODE_HORIZONTAL; break;
            case 'R': g_recursive = 1;          break;
            default:
                fprintf(stderr, "Usage: %s [-l] [-x] [-R] [dir ...]\n", argv[0]);
                return 1;
        }
    }

    if (optind == argc)
    {
        do_ls(".");
    }
    else
    {
        for (int i = optind; i < argc; i++)
        {
            do_ls(argv[i]);
        }
    }
    return 0;
}

/* ---------- qsort comparator ---------- */
int cmp_filenames(const void *a, const void *b)
{
    const char *sa = *(const char * const *)a;
    const char *sb = *(const char * const *)b;
    return strcmp(sa, sb);
}

/* ---------- Archive extension check ---------- */
int has_archive_ext(const char *name)
{
    const char *exts[] = { ".tar", ".gz", ".zip", ".tgz", ".bz2", ".xz", ".7z", ".rar", NULL };
    size_t nlen = strlen(name);
    for (int i = 0; exts[i]; i++)
    {
        size_t elen = strlen(exts[i]);
        if (nlen >= elen && strcmp(name + nlen - elen, exts[i]) == 0)
            return 1;
    }
    return 0;
}

/* ---------- Color selection ---------- */
const char *color_for(mode_t mode, const char *name)
{
    if (!g_color) return "";

    if (S_ISLNK(mode))  return C_MAGENTA;
    if (S_ISDIR(mode))  return C_BLUE;
    if (S_ISCHR(mode) || S_ISBLK(mode) || S_ISFIFO(mode) || S_ISSOCK(mode))
        return C_REVERSE;
    if (S_ISREG(mode))
    {
        if (mode & (S_IXUSR | S_IXGRP | S_IXOTH))
            return C_GREEN;
        if (has_archive_ext(name))
            return C_RED;
    }
    return "";
}

/* ---------- Collect + sort ---------- */
static char **collect_files_sorted(const char *dir, size_t *count_out, size_t *maxlen_out)
{
    DIR *dp = opendir(dir);
    if (dp == NULL)
    {
        fprintf(stderr, "Cannot open directory : %s\n", dir);
        *count_out = 0;
        return NULL;
    }

    size_t cap = 64, count = 0, maxlen = 0;
    char **files = malloc(cap * sizeof(char *));
    if (!files) { perror("malloc"); closedir(dp); *count_out = 0; return NULL; }

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

    if (count > 0)
        qsort(files, count, sizeof(char *), cmp_filenames);

    *count_out = count;
    *maxlen_out = maxlen;
    return files;
}

/* ---------- Header printing helper ---------- */
static void print_dir_header(const char *dir)
{
    if (!g_first_dir_printed)
    {
        printf("%s:\n", dir);
        g_first_dir_printed = 1;
    }
    else
    {
        printf("\n%s:\n", dir);
    }
}

/* ---------- do_ls: master dispatcher (recursive) ---------- */
void do_ls(const char *dir)
{
    print_dir_header(dir);

    switch (g_mode)
    {
        case MODE_LONG:       do_ls_long(dir);       break;
        case MODE_HORIZONTAL: list_horizontal(dir);  break;
        default:              list_columns(dir);     break;
    }

    if (!g_recursive) return;

    /* Now recurse into subdirectories */
    size_t count = 0, maxlen = 0;
    char **files = collect_files_sorted(dir, &count, &maxlen);
    if (!files) return;

    for (size_t i = 0; i < count; i++)
    {
        char fullpath[4096];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", dir, files[i]);

        struct stat st;
        if (lstat(fullpath, &st) == -1)
        {
            free(files[i]);
            continue;
        }

        if (S_ISDIR(st.st_mode))
        {
            /* Recurse before freeing */
            char *subdir = strdup(fullpath);
            free(files[i]);
            do_ls(subdir);
            free(subdir);
        }
        else
        {
            free(files[i]);
        }
    }
    free(files);
}

/* ---------- Long listing driver ---------- */
void do_ls_long(const char *dir)
{
    size_t count = 0, maxlen = 0;
    char **files = collect_files_sorted(dir, &count, &maxlen);
    if (!files) return;

    for (size_t i = 0; i < count; i++)
    {
        list_long(dir, files[i]);
        free(files[i]);
    }
    free(files);
}

/* ---------- Default: down-then-across ---------- */
void list_columns(const char *dir)
{
    size_t count = 0, maxlen = 0;
    char **files = collect_files_sorted(dir, &count, &maxlen);
    if (!files || count == 0) { free(files); return; }

    int term_w = get_terminal_width();
    int spacing = 2;
    int col_width = (int)maxlen + spacing;
    if (col_width <= 0) col_width = 1;

    int cols = term_w / col_width;
    if (cols < 1) cols = 1;
    if ((size_t)cols > count) cols = (int)count;

    int rows = (int)((count + cols - 1) / cols);

    for (int r = 0; r < rows; r++)
    {
        for (int c = 0; c < cols; c++)
        {
            size_t idx = (size_t)c * rows + r;
            if (idx >= count) continue;

            char fullpath[4096];
            snprintf(fullpath, sizeof(fullpath), "%s/%s", dir, files[idx]);
            struct stat st;
            mode_t mode = 0;
            if (lstat(fullpath, &st) == 0) mode = st.st_mode;

            const char *col = color_for(mode, files[idx]);
            int is_last = (c == cols - 1) || (idx + rows >= count);

            if (col[0])
                printf("%s%s%s", col, files[idx], C_RESET);
            else
                printf("%s", files[idx]);

            if (!is_last)
            {
                int namelen = (int)strlen(files[idx]);
                int color_extra = (int)(strlen(col) + strlen(C_RESET));
                int total_len = namelen + (col[0] ? color_extra : 0);
                for (int k = total_len; k < col_width; k++) putchar(' ');
            }
        }
        putchar('\n');
    }

    for (size_t i = 0; i < count; i++) free(files[i]);
    free(files);
}

/* ---------- Horizontal ---------- */
void list_horizontal(const char *dir)
{
    size_t count = 0, maxlen = 0;
    char **files = collect_files_sorted(dir, &count, &maxlen);
    if (!files || count == 0) { free(files); return; }

    int term_w = get_terminal_width();
    int spacing = 2;
    int col_width = (int)maxlen + spacing;
    if (col_width <= 0) col_width = 1;

    int pos = 0;
    for (size_t i = 0; i < count; i++)
    {
        char fullpath[4096];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", dir, files[i]);
        struct stat st;
        mode_t mode = 0;
        if (lstat(fullpath, &st) == 0) mode = st.st_mode;

        const char *col = color_for(mode, files[i]);
        int is_last = (i == count - 1);

        if (!is_last && (pos + col_width > term_w))
        {
            putchar('\n');
            pos = 0;
        }

        if (col[0])
            printf("%s%s%s", col, files[i], C_RESET);
        else
            printf("%s", files[i]);

        if (!is_last)
        {
            int namelen = (int)strlen(files[i]);
            int color_extra = (int)(strlen(col) + strlen(C_RESET));
            int total_len = namelen + (col[0] ? color_extra : 0);
            for (int k = total_len; k < col_width; k++) putchar(' ');
            pos += col_width;
        }
        else
        {
            pos += (int)strlen(files[i]);
        }
    }
    putchar('\n');

    for (size_t i = 0; i < count; i++) free(files[i]);
    free(files);
}

/* ---------- Long listing per file ---------- */
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

    const char *col = color_for(st.st_mode, name);

    printf("%s %3lu %-8s %-8s %8ld %s ",
           perms, (unsigned long)st.st_nlink, owner, group,
           (long)st.st_size, timebuf);

    if (col[0])
        printf("%s%s%s\n", col, name, C_RESET);
    else
        printf("%s\n", name);
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

int get_terminal_width(void)
{
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0)
        return (int)ws.ws_col;
    return 80;
}
