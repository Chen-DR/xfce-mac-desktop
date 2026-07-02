#!/usr/bin/env python3
"""macOS-style fullscreen workspaces for xfwm4.

When a window enters fullscreen or gets maximized (like the green button
on macOS), a new workspace is appended and the window is moved there.
When it leaves that state (or closes), the window is moved back to its
original workspace, the extra workspace is removed, and the view returns
to that original workspace.
"""

import subprocess
import sys

from Xlib import X, display, error, Xatom

dpy = display.Display()
root = dpy.screen().root

NET_CLIENT_LIST = dpy.intern_atom('_NET_CLIENT_LIST')
NET_WM_STATE = dpy.intern_atom('_NET_WM_STATE')
NET_WM_STATE_FULLSCREEN = dpy.intern_atom('_NET_WM_STATE_FULLSCREEN')
NET_WM_STATE_MAX_VERT = dpy.intern_atom('_NET_WM_STATE_MAXIMIZED_VERT')
NET_WM_STATE_MAX_HORZ = dpy.intern_atom('_NET_WM_STATE_MAXIMIZED_HORZ')
NET_WM_DESKTOP = dpy.intern_atom('_NET_WM_DESKTOP')
NET_NUMBER_OF_DESKTOPS = dpy.intern_atom('_NET_NUMBER_OF_DESKTOPS')

STICKY = 0xFFFFFFFF


def wmctrl(*args):
    subprocess.run(['wmctrl', *args], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def get_desktop_count():
    prop = root.get_full_property(NET_NUMBER_OF_DESKTOPS, Xatom.CARDINAL)
    return prop.value[0] if prop else 1


def get_client_list():
    prop = root.get_full_property(NET_CLIENT_LIST, Xatom.WINDOW)
    return set(prop.value) if prop else set()


def is_fullscreen(win):
    """True if the window is fullscreen or fully maximized."""
    try:
        prop = win.get_full_property(NET_WM_STATE, Xatom.ATOM)
    except error.XError:
        return False
    if not prop:
        return False
    states = set(prop.value)
    return (NET_WM_STATE_FULLSCREEN in states
            or {NET_WM_STATE_MAX_VERT, NET_WM_STATE_MAX_HORZ} <= states)


def get_window_desktop(win):
    try:
        prop = win.get_full_property(NET_WM_DESKTOP, Xatom.CARDINAL)
    except error.XError:
        return None
    return prop.value[0] if prop else None


def get_app_name(win):
    """Human-readable label for the workspace: WM_CLASS, else title."""
    try:
        cls = win.get_wm_class()
        if cls and cls[1]:
            # reverse-domain classes like "com.follow.clash" -> "Clash"
            name = cls[1].split('.')[-1]
            return name[0].upper() + name[1:] if name else cls[1]
        title = win.get_wm_name()
        if isinstance(title, bytes):
            title = title.decode('utf-8', 'replace')
        if title:
            return title[:24]
    except error.XError:
        pass
    return '全屏'


def count_fullscreen_clients():
    n = 0
    for wid in get_client_list():
        win = dpy.create_resource_object('window', wid)
        if is_fullscreen(win):
            n += 1
    return n


# Base workspaces are whatever isn't occupied by a fullscreen window, so a
# daemon restart doesn't inflate the count.
BASE = max(1, get_desktop_count() - count_fullscreen_clients())

# wid -> {'orig': desktop, 'name': label}; insertion order = workspace order
fullscreen = {}
tracked = {}  # wid -> Window object


def set_workspace_names():
    names = [str(i + 1) for i in range(BASE)]
    names += [entry['name'] for entry in fullscreen.values()]
    cmd = ['xfconf-query', '-c', 'xfwm4', '-p', '/general/workspace_names',
           '--create', '--force-array']
    for name in names:
        cmd += ['-t', 'string', '-s', name]
    subprocess.run(cmd, check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def relayout():
    """Assign each fullscreen window its own workspace after the base ones."""
    wmctrl('-n', str(BASE + len(fullscreen)))
    for i, wid in enumerate(fullscreen):
        wmctrl('-i', '-r', hex(wid), '-t', str(BASE + i))
    set_workspace_names()


def on_enter_fullscreen(wid, win):
    orig = get_window_desktop(win)
    if orig is None or orig == STICKY:
        orig = 0
    fullscreen[wid] = {'orig': min(orig, BASE - 1), 'name': get_app_name(win)}
    relayout()
    wmctrl('-s', str(BASE + len(fullscreen) - 1))


def on_leave_fullscreen(wid, closed=False):
    orig = fullscreen.pop(wid)['orig']
    if not closed:
        wmctrl('-i', '-r', hex(wid), '-t', str(orig))
    relayout()
    wmctrl('-s', str(orig))
    if not closed:
        wmctrl('-i', '-a', hex(wid))


def watch(wid):
    win = dpy.create_resource_object('window', wid)
    try:
        win.change_attributes(event_mask=X.PropertyChangeMask)
    except error.XError:
        return
    tracked[wid] = win
    if is_fullscreen(win):
        on_enter_fullscreen(wid, win)


def sync_clients():
    current = get_client_list()
    for wid in current - tracked.keys():
        watch(wid)
    for wid in set(tracked) - current:
        tracked.pop(wid, None)
        if wid in fullscreen:
            on_leave_fullscreen(wid, closed=True)


def main():
    root.change_attributes(event_mask=X.PropertyChangeMask)
    sync_clients()
    while True:
        ev = dpy.next_event()
        if ev.type != X.PropertyNotify:
            continue
        if ev.window == root:
            if ev.atom == NET_CLIENT_LIST:
                sync_clients()
        elif ev.atom == NET_WM_STATE:
            wid = ev.window.id
            if wid not in tracked:
                continue
            fs = is_fullscreen(tracked[wid])
            if fs and wid not in fullscreen:
                on_enter_fullscreen(wid, tracked[wid])
            elif not fs and wid in fullscreen:
                on_leave_fullscreen(wid)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
