
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
(mode & S_IWUSR) ? 'w' : '-'
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
