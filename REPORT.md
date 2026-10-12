
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
