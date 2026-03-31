/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

/*
 * Minimal FUSE daemon for INC_EPOCH readdir-cache invalidation test.
 *
 * Layout:  /dir/{a.txt}  (+ hidden b.txt, toggled by "add" command)
 *
 * Config:  FUSE_CAP_NO_OPENDIR_SUPPORT, FUSE_CAP_READDIRPLUS,
 *          no AUTO_INVAL_DATA, infinite TTL on all caches.
 *
 * stdin commands:  add | reset | inc_epoch | quit
 *
 * Build:  cc -o testfs main.c $(pkg-config --cflags --libs fuse3) -lpthread
 * Usage:  ./testfs <mountpoint>
 *
 * @noautodeps
 */

#define FUSE_USE_VERSION 34
#include <errno.h>
#include <fuse_lowlevel.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define ROOT_INO 1
#define DIR_INO 2
#define A_INO 3
#define B_INO 4

#define TTL 2147483647.0

static struct fuse_session* se;
static volatile int show_b;
static unsigned int proto_minor;

#define LOG(fmt, ...) fprintf(stderr, "\033[33m" fmt "\033[0m\n", ##__VA_ARGS__)

static struct stat make_stat(fuse_ino_t ino, int is_dir) {
  struct stat st = {.st_ino = ino, .st_uid = getuid(), .st_gid = getgid()};
  if (is_dir) {
    st.st_mode = S_IFDIR | 0755;
    st.st_nlink = 2;
  } else {
    st.st_mode = S_IFREG | 0644;
    st.st_nlink = 1;
    st.st_size = 5;
  }
  return st;
}

static void ll_init(void* ud, struct fuse_conn_info* c) {
  proto_minor = c->proto_minor;
  if (c->capable & FUSE_CAP_NO_OPENDIR_SUPPORT)
    c->want |= FUSE_CAP_NO_OPENDIR_SUPPORT;
  c->want &= ~FUSE_CAP_AUTO_INVAL_DATA;
  LOG("[init] proto=%u.%u no_opendir=%s readdirplus=%s",
      c->proto_major,
      c->proto_minor,
      (c->want & FUSE_CAP_NO_OPENDIR_SUPPORT) ? "yes" : "no",
      (c->want & FUSE_CAP_READDIRPLUS) ? "yes" : "no");
}

static void ll_lookup(fuse_req_t req, fuse_ino_t parent, const char* name) {
  LOG("[LOOKUP] parent=%lu name=%s", parent, name);
  fuse_ino_t ino = 0;
  if (parent == ROOT_INO && !strcmp(name, "dir"))
    ino = DIR_INO;
  else if (parent == DIR_INO) {
    if (!strcmp(name, "a.txt"))
      ino = A_INO;
    else if (!strcmp(name, "b.txt") && show_b)
      ino = B_INO;
  }
  if (!ino) {
    struct fuse_entry_param e = {.ino = 0, .entry_timeout = TTL};
    fuse_reply_entry(req, &e);
    return;
  }
  struct fuse_entry_param e = {
      .ino = ino,
      .attr = make_stat(ino, ino == DIR_INO),
      .attr_timeout = TTL,
      .entry_timeout = TTL};
  fuse_reply_entry(req, &e);
}

static void
ll_getattr(fuse_req_t req, fuse_ino_t ino, struct fuse_file_info* fi) {
  LOG("[GETATTR] ino=%lu", ino);
  int is_dir = (ino == ROOT_INO || ino == DIR_INO);
  struct stat st = make_stat(ino, is_dir);
  fuse_reply_attr(req, &st, TTL);
}

static void
ll_opendir(fuse_req_t req, fuse_ino_t ino, struct fuse_file_info* fi) {
  LOG("[OPENDIR] ino=%lu", ino);
  fi->cache_readdir = 1;
  fi->keep_cache = 1;
  fuse_reply_open(req, fi);
}

static void ll_readdirplus(
    fuse_req_t req,
    fuse_ino_t ino,
    size_t size,
    off_t off,
    struct fuse_file_info* fi) {
  LOG("[READDIRPLUS] ino=%lu off=%ld", ino, off);
  struct {
    const char* name;
    fuse_ino_t ino;
    int is_dir;
  } entries[16];
  int n = 0;

  if (ino == ROOT_INO) {
    entries[n++] = (typeof(entries[0])){".", ROOT_INO, 1};
    entries[n++] = (typeof(entries[0])){"..", ROOT_INO, 1};
    entries[n++] = (typeof(entries[0])){"dir", DIR_INO, 1};
  } else if (ino == DIR_INO) {
    entries[n++] = (typeof(entries[0])){".", DIR_INO, 1};
    entries[n++] = (typeof(entries[0])){"..", ROOT_INO, 1};
    entries[n++] = (typeof(entries[0])){"a.txt", A_INO, 0};
    if (show_b)
      entries[n++] = (typeof(entries[0])){"b.txt", B_INO, 0};
  } else {
    fuse_reply_err(req, ENOTDIR);
    return;
  }

  if (off >= n) {
    fuse_reply_buf(req, NULL, 0);
    return;
  }

  char buf[8192];
  size_t total = 0;
  for (int i = off; i < n; i++) {
    struct fuse_entry_param e = {
        .ino = entries[i].ino,
        .attr = make_stat(entries[i].ino, entries[i].is_dir),
        .attr_timeout = TTL,
        .entry_timeout = TTL};
    size_t es = fuse_add_direntry_plus(
        req, buf + total, sizeof(buf) - total, entries[i].name, &e, i + 1);
    if (total + es > size)
      break;
    total += es;
  }
  fuse_reply_buf(req, buf, total);
}

static void ll_forget(fuse_req_t req, fuse_ino_t ino, uint64_t nl) {
  fuse_reply_none(req);
}

static void send_inc_epoch(void) {
  if (proto_minor < 44) {
    LOG("[send] INC_EPOCH -> ENOSYS (proto_minor=%u < 44)", proto_minor);
    return;
  }
  struct {
    uint32_t len;
    int32_t code;
    uint64_t unique;
  } msg = {sizeof(msg), 8 /* FUSE_NOTIFY_INC_EPOCH */, 0};
  ssize_t n = write(fuse_session_fd(se), &msg, sizeof(msg));
  LOG("[send] INC_EPOCH -> %s",
      n == (ssize_t)sizeof(msg) ? "ok" : strerror(errno));
}

static void* cmd_thread(void* arg) {
  char line[256];
  while (fgets(line, sizeof(line), stdin)) {
    line[strcspn(line, "\n")] = 0;
    if (!*line)
      continue;
    if (!strcmp(line, "add")) {
      show_b = 1;
      LOG("[cmd] b.txt visible");
    } else if (!strcmp(line, "reset")) {
      show_b = 0;
      LOG("[cmd] reset");
    } else if (!strcmp(line, "inc_epoch")) {
      send_inc_epoch();
    } else if (!strcmp(line, "quit")) {
      fuse_session_exit(se);
      break;
    } else {
      LOG("unknown: %s", line);
    }
  }
  return NULL;
}

static const struct fuse_lowlevel_ops ops = {
    .init = ll_init,
    .lookup = ll_lookup,
    .getattr = ll_getattr,
    .opendir = ll_opendir,
    .readdirplus = ll_readdirplus,
    .forget = ll_forget,
};

int main(int argc, char* argv[]) {
  struct fuse_args args = FUSE_ARGS_INIT(argc, argv);
  struct fuse_cmdline_opts opts = {0};
  if (fuse_parse_cmdline(&args, &opts) || !opts.mountpoint) {
    fprintf(stderr, "Usage: %s <mountpoint>\n", argv[0]);
    return 1;
  }
  se = fuse_session_new(&args, &ops, sizeof(ops), NULL);
  if (!se || fuse_set_signal_handlers(se) ||
      fuse_session_mount(se, opts.mountpoint)) {
    if (se)
      fuse_session_destroy(se);
    free(opts.mountpoint);
    return 1;
  }
  pthread_t tid;
  pthread_create(&tid, NULL, cmd_thread, NULL);
  int ret = fuse_session_loop(se);
  fuse_session_unmount(se);
  fuse_remove_signal_handlers(se);
  fuse_session_destroy(se);
  free(opts.mountpoint);
  return ret;
}
