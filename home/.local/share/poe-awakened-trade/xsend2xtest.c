// xsend2xtest: LD_PRELOAD shim that turns synthetic X11 key events into XTEST input.
//
// Why: Awakened PoE Trade simulates keys (Ctrl+C to copy an item, Enter /
// Ctrl+V for chat commands) through uiohook-napi, whose X11 backend sends
// them with XSendEvent to the focused window. Path of Exile under Proton 10+
// (Wine) ignores such synthetic events, so every APT feature that needs a
// copied item silently fails ("[ClipboardPoller] No item text found").
// The same key sequence injected with XTEST works (verified 2026-11-18 on
// Proton 11 / Xwayland 24.1, zero delay between events). See
// docs/troubleshooting/awakened-poe-trade-sway.md in the dotfiles repo.
//
// What: XSendEvent calls carrying a KeyPress/KeyRelease become
// XTestFakeKeyEvent on the same display (the server then delivers a real key
// event to the focused client and updates the modifier state). Everything
// else, and every call when XTEST is unavailable, goes to the real XSendEvent.
// libXtst and the real XSendEvent are resolved at runtime, so preloading this
// into non-X11 processes (AppImage runtime, Chromium helpers) is harmless.
//
// Delay: XSEND2XTEST_DELAY_MS=N makes the X server hold the first key of a
// burst (no converted key in the previous 250 ms) for N ms. APT writes a
// marker to the clipboard right before its Ctrl+C; Wine imports that marker
// into the game's clipboard, and a Ctrl+C arriving meanwhile is lost. The
// server-side XTEST delay keeps APT's own thread (and its clipboard write)
// running while the keys wait.
//
// Environment: in the Electron main process (exe "awakened-poe-trade", no
// --type=) LD_PRELOAD is removed after loading, so programs APT launches (the
// browser for wiki/trade links) do not inherit the shim.
//
// Build (done by bin/poe-awakened-trade):
//   cc -O2 -Wall -Wextra -shared -fPIC -o xsend2xtest.so xsend2xtest.c -ldl
// Debug: XSEND2XTEST_DEBUG=1 logs every converted event to stderr.

#define _GNU_SOURCE
#include <X11/Xlib.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

typedef Status (*xsendevent_fn)(Display *, Window, Bool, long, XEvent *);
typedef int (*xtest_fake_key_fn)(Display *, unsigned int, Bool, unsigned long);

static xsendevent_fn real_xsendevent;
static xtest_fake_key_fn xtest_fake_key;
static int initialized;
static int debug;
static unsigned long delay_ms;
static double last_key_at;

static double now_s(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

// Electron main process: exe basename "awakened-poe-trade" and no "--type="
// argument (helpers have one). Read from /proc, as argv is not available here.
static int is_apt_main_process(void) {
  char exe[4096];
  ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
  if (n <= 0) return 0;
  exe[n] = '\0';
  const char *base = strrchr(exe, '/');
  if (strcmp(base ? base + 1 : exe, "awakened-poe-trade") != 0) return 0;
  FILE *f = fopen("/proc/self/cmdline", "r");
  if (!f) return 0;
  char buf[8192];
  size_t len = fread(buf, 1, sizeof buf - 1, f);
  fclose(f);
  buf[len] = '\0';
  for (size_t i = 0; i < len; i += strlen(buf + i) + 1)
    if (strncmp(buf + i, "--type=", 7) == 0) return 0;
  return 1;
}

__attribute__((constructor)) static void on_load(void) {
  if (is_apt_main_process()) unsetenv("LD_PRELOAD");
}

static void init(void) {
  if (initialized) return;
  initialized = 1;
  debug = getenv("XSEND2XTEST_DEBUG") != NULL;
  const char *d = getenv("XSEND2XTEST_DELAY_MS");
  if (d) delay_ms = strtoul(d, NULL, 10);
  real_xsendevent = (xsendevent_fn)dlsym(RTLD_NEXT, "XSendEvent");
  void *xtst = dlopen("libXtst.so.6", RTLD_NOW | RTLD_GLOBAL);
  if (xtst) xtest_fake_key = (xtest_fake_key_fn)dlsym(xtst, "XTestFakeKeyEvent");
  if (debug)
    fprintf(stderr, "xsend2xtest: real XSendEvent %p, XTestFakeKeyEvent %p, delay %lu ms\n",
            (void *)real_xsendevent, (void *)xtest_fake_key, delay_ms);
}

Status XSendEvent(Display *dpy, Window w, Bool propagate, long mask, XEvent *ev) {
  init();
  if (ev && xtest_fake_key && (ev->type == KeyPress || ev->type == KeyRelease)) {
    Bool press = ev->type == KeyPress;
    double t = now_s();
    unsigned long delay = (delay_ms && t - last_key_at > 0.25) ? delay_ms : 0;
    last_key_at = t;
    if (debug)
      fprintf(stderr, "xsend2xtest: keycode %u %s -> XTEST (delay %lu ms)\n",
              ev->xkey.keycode, press ? "down" : "up", delay);
    if (xtest_fake_key(dpy, ev->xkey.keycode, press, delay)) return 1;
  }
  return real_xsendevent ? real_xsendevent(dpy, w, propagate, mask, ev) : 0;
}
