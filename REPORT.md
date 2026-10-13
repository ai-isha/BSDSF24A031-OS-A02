
## Feature 2: Long Listing (v1.1.0)

**Q1: stat() vs lstat()**

`stat()` symlink ko follow karta hai aur link ke target ki metadata return karta hai. `lstat()` symlink ko follow nahi karta — ye link khud ki metadata return karta hai. `ls` mein `lstat()` use hota hai jab directory contents list kar rahe hon, taake symlink apne asli roop mein dikhe.

**Q2: st_mode se file type aur permissions**

```c
if ((st.st_mode & S_IFMT) == S_IFDIR)      /* directory */
else if ((st.st_mode & S_IFMT) == S_IFREG) /* regular file */
```

Permissions:
```c
(mode & S_IRUSR) ? 'r' : '-'

## Feature 5: Alphabetical Sort — v1.4.0

**Q1: Why is it necessary to read all directory entries into memory before you can sort them? What are the potential drawbacks of this approach for directories containing millions of files?**

Sorting requires seeing the entire data set before deciding the final order. Unlike printing (which can stream one entry at a time as soon as it is read from readdir), sorting is inherently a global operation: an element may have to move arbitrarily far in the output depending on how the rest of the data compares to it. qsort(), like every comparison sort, must examine pairs of elements in an order determined by their values — you cannot decide the final position of any element without knowing about the others. Additionally, readdir() returns entries in an unspecified order that depends on the underlying filesystem implementation, so the raw stream has no useful ordering we can exploit. Therefore the only option is to buffer the entire directory contents into a dynamic array (via malloc/realloc/strdup), sort the array in-place with qsort(), and only after that begin printing.

Drawbacks for very large directories (millions of entries):

1. Memory: each filename is stored twice (once in the kernel dirent buffer transiently, once as a heap-allocated strdup in our array). For N = 10 million entries with average filename length around 30 bytes, that is roughly 300 MB of string data plus about 80 MB of pointers on 64-bit systems — easily hundreds of megabytes of RAM for a single ls invocation.

2. Latency: no output appears until readdir() finishes and qsort() completes. On a directory with millions of entries, the user sees nothing for several seconds and cannot start reading results, unlike the streaming default which prints as it goes.

3. Swap pressure: if the array does not fit in physical RAM, the OS begins to swap, which can make the whole machine sluggish.

4. Time: qsort() is O(N log N) comparisons, each involving strcmp() over the filename. For 10 million entries this is over 200 million string comparisons, adding seconds to the runtime.

5. Signal-safety: buffering holds a lot of state in the middle of the operation, so interrupt and cleanup handling has to free everything correctly.

Real ls mitigates these issues with optimizations such as lazy allocation, streaming into an intermediate buffer, or using a lower-memory representation, but the fundamental tradeoff (memory and latency versus sorted output) remains.

---

**Q2: Explain the purpose and signature of the comparison function required by qsort(). How does it work, and why must it take const void * arguments?**

The comparison function tells qsort() how to order two elements. Its signature is:

    int cmp(const void *a, const void *b);

Purpose: qsort() is a generic algorithm that does not know the type of the elements it is sorting. The function receives two pointers to elements (in the form of const void *) and returns:

- a negative int if the first element should come before the second,
- zero if they are considered equal,
- a positive int if the first element should come after the second.

qsort() calls this function repeatedly during the sort and rearranges elements based on the sign of the returned value. In our code:

    int cmp_filenames(const void *a, const void *b) {
        const char *sa = *(const char * const *)a;
        const char *sb = *(const char * const *)b;
        return strcmp(sa, sb);
    }

The array we pass to qsort is a char ** (an array of pointers to strings). Each element is therefore a char *. The function receives a pointer to an element, i.e., a char **. We cast the void * back to char **, then dereference it once to recover the char * (the actual filename string), and finally pass both strings to strcmp(). strcmp() itself happens to return the exact negative / zero / positive convention qsort() wants, so its return value is used directly.

Why const void *? Two reasons:

1. void * — because qsort() must work for arrays of ANY type (int, double, struct, char *). Using void * hides the type from qsort and lets the caller supply a comparator that knows the real type.

2. const — because the comparator must not modify the elements it is looking at. qsort() moves elements around, but the comparison step must be side-effect free. The const qualifier lets the compiler enforce that we only read through the pointer, never write. This also allows the caller to pass pointers to const data safely.

The C standard specifies this exact signature for the qsort comparator, so any deviation (for example, dropping const) results in undefined behavior or at least compiler warnings.(mode & S_IWUSR) ? 'w' : '-'
(mode & S_IXUSR) ? 'x' : '-'
```

Special bits:
```c
(mode & S_ISUID)  /* setuid */
(mode & S_ISGID)  /* setgid */
(mode & S_ISVTX)  /* sticky */
```

## Feature 3: Column Display (Down Then Across) — v1.2.0

**Q1: Explain the general logic for printing items in a "down then across" columnar format. Why is a simple single loop through the list of filenames insufficient for this task?**

`ls` default output is organized so that files fill the **first column top-to-bottom, then move to the next column**. This is called "down then across". If there are N files, C columns and R rows, then R = ceil(N / C) and the file at visual position (row r, column c) is at index c * R + r in the array.

A single left-to-right loop over the filenames would print them "across then down", which is the wrong visual order. To get "down then across" we need a two-level loop:

    for r in 0..R-1:
        for c in 0..C-1:
            idx = c * R + r
            if idx < N:
                print files[idx] with padding
        print newline

Each row contains one file from each column, and the last row may have fewer items. Additionally, the number of columns depends on the terminal width and the longest filename, so the loop can only be constructed after all filenames are collected and the maximum length is known — which is why a single streaming loop cannot work.

---

**Q2: What is the purpose of the ioctl system call in this context? What would be the limitations of your program if you only used a fixed-width fallback (e.g., 80 columns) instead of detecting the terminal size?**

ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) retrieves the current terminal's dimensions into a struct winsize (fields ws_row and ws_col). We use ws.ws_col as the terminal width to compute how many columns of filenames can fit:

    col_width = max_filename_length + spacing
    cols = terminal_width / col_width

Without ioctl, the program has no way of knowing how wide the terminal actually is.

Limitations of using a fixed-width fallback of 80:

1. On a narrow terminal (e.g., 40 columns), the program would still try to fit 80-column worth of files, causing lines to wrap awkwardly and destroying the alignment.

2. On a wide terminal (e.g., 200 columns), the program would only use 80 columns and waste most of the screen.

3. Terminal size changes at runtime (when the user resizes the window), so a fixed value can never be correct for all users.

4. Different users have different default terminal sizes — a fixed fallback forces one layout for everyone.

The correct approach is to query ioctl(TIOCGWINSZ) and only fall back to a safe constant (80) when the call fails, e.g., when stdout is a pipe or a file with no terminal attached.

## Feature 4: Horizontal Column Display (-x) — v1.3.0

**Q1: Compare the implementation complexity of the "down then across" (vertical) printing logic versus the "across" (horizontal) printing logic. Which one requires more pre-calculation and why?**

The down-then-across (vertical) logic requires more pre-calculation.

For down-then-across we must know:
1. The total number of files N.
2. The longest filename length L (to compute column width = L + spacing).
3. The terminal width W (via ioctl(TIOCGWINSZ)).
4. The number of columns C = W / column_width.
5. The number of rows R = ceil(N / C).

Only after all five values are known can we print anything, because the file at visual position (row r, column c) is at index c * R + r in the array. This is a column-major mapping. The entire layout has to be computed before the first character is written, and files must be collected into memory first (dynamic array via malloc/realloc/strdup).

The across (horizontal) logic is simpler: walk the array left to right, printing each name padded to column width, and count the current horizontal position. When pos + col_width > W, emit a newline and reset pos = 0. No need to know total count N or row count R. The algorithm is a single streaming loop using O(1) extra state.

So: down-then-across is more complex because it needs a global picture of the data before printing; across is local and streaming.

---

**Q2: Describe the strategy you used in your code to manage the different display modes (-l, -x, and default). How did your program decide which function to call for printing?**

I used a single global enum and a dispatch switch in main:

    enum display_mode { MODE_COLUMN, MODE_LONG, MODE_HORIZONTAL };
    static enum display_mode g_mode = MODE_COLUMN;

During argument parsing, the getopt loop in main updates g_mode whenever a relevant flag is seen:

    while ((opt = getopt(argc, argv, "lx")) != -1) {
        switch (opt) {
            case 'l': g_mode = MODE_LONG;       break;
            case 'x': g_mode = MODE_HORIZONTAL; break;
        }
    }

This means if both -l and -x are given, the last one wins, which mirrors the behavior of real ls.

After parsing, main iterates over the directory arguments and dispatches to the right function via a nested switch:

    switch (g_mode) {
        case MODE_LONG:       do_ls_long(dir);      break;
        case MODE_HORIZONTAL: list_horizontal(dir); break;
        default:              list_columns(dir);    break;
    }

Each mode has its own dedicated function that shares common helpers (format_perms, format_time, collect_files, get_terminal_width). This keeps mode-selection logic in one place (main), printing logic in small focused functions, and avoids scattering flag checks. Adding a new mode in future only requires a new enum value, a new getopt letter, and a new case in the dispatch switch.
