const icon_uid: u32 = 69;

const WindowState = struct {
    shown: bool = true,
};

// Keep this in sync with res/resources.h
const Resources = struct {
    pub const ICO_ZIG = 1;
    pub const MENU_TRAY = 2;
    pub const MENU_TRAY_POPUP = 3;
};

pub export fn wWinMain(
    hInstance: win32.HINSTANCE,
    hPrevInstance: ?win32.HINSTANCE,
    pCmdLine: win32.PWSTR,
    nCmdShow: i32,
) c_int {
    _ = hPrevInstance;
    _ = pCmdLine;
    _ = nCmdShow;

    const class_name = "Zig Class";

    var wc = std.mem.zeroes(win32.WNDCLASSA);
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = class_name;
    wc.hIcon = win32.LoadIconA(hInstance, @ptrFromInt(Resources.ICO_ZIG)) orelse panicWithLastErr("failed to load window class icon resource {d}", .{Resources.ICO_ZIG});

    if (win32.RegisterClassA(&wc) == 0) {
        panicWithLastErr("failed to register window class {s}", .{class_name});
    }

    var window_state: WindowState = .{};

    const window = if (win32.CreateWindowExA(
        .{},
        class_name,
        "Zig Window",
        win32.WS_OVERLAPPEDWINDOW,
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        1280,
        720,
        null,
        null,
        hInstance,
        &window_state,
    )) |h| h else panicWithLastErr("failed to create window", .{});

    _ = win32.ShowWindow(window, .{ .SHOWNORMAL = @intFromBool(window_state.shown) });

    var msg = std.mem.zeroes(win32.MSG);
    while (win32.GetMessageA(&msg, null, 0, 0) > 0) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageA(&msg);
    }

    return 0;
}

pub export fn WindowProc(hwnd: win32.HWND, uMsg: u32, wParam: usize, lParam: win32.LPARAM) isize {
    var window_state: ?*WindowState = null;
    var hinst: ?win32.HINSTANCE = null;
    var window_name: ?[*:0]const u8 = null;

    if (uMsg == win32.WM_CREATE) {
        if (lParam > 0) {
            const p: *win32.CREATESTRUCTA = @ptrFromInt(@as(usize, @bitCast(lParam)));
            window_state = @ptrCast(@alignCast(p.lpCreateParams));
            hinst = p.hInstance;
            window_name = p.lpszName;

            const new_long = @intFromPtr(window_state);
            if (win32.SetWindowLongPtrA(hwnd, win32.GWLP_USERDATA, @bitCast(new_long)) == 0) {
                if (win32.GetLastError() != .NO_ERROR) {
                    panicWithLastErr("failed to get window state", .{});
                }
            }

            std.log.debug("set window state", .{});
        }
    }

    window_state = switch (win32.GetWindowLongPtrA(hwnd, win32.GWLP_USERDATA)) {
        // WM_CREATE may not yet have been fired, so SetWindowLongPtr might not
        // have been called yet!
        0 => blk: {
            if (win32.GetLastError() != .NO_ERROR) {
                panicWithLastErr("failed to get window state", .{});
            }

            break :blk null;
        },
        else => |val| @ptrFromInt(@as(usize, @bitCast(val))),
    };

    switch (uMsg) {
        win32.WM_CREATE => {
            var icon = std.mem.zeroes(win32.NOTIFYICONDATAA);
            icon.cbSize = @sizeOf(win32.NOTIFYICONDATAA);
            icon.hWnd = hwnd;
            icon.uID = icon_uid;
            icon.uCallbackMessage = icon_uid;
            icon.uFlags = .{
                .ICON = 1,
                .MESSAGE = 1,
                .TIP = 1,
            };
            _ = std.fmt.bufPrintZ(&icon.szTip, "Zig Icon", .{}) catch @panic("OOM");

            icon.hIcon = win32.LoadIconA(hinst, @ptrFromInt(Resources.ICO_ZIG)) orelse panicWithLastErr("failed to load notify icon icon resource {d}", .{Resources.ICO_ZIG});

            if (win32.Shell_NotifyIconA(win32.NIM_ADD, &icon) == 0) {
                panicWithLastErr("failed to create notify icon", .{});
            }

            icon.Anonymous.uVersion = win32.NOTIFYICON_VERSION_4;
            if (win32.Shell_NotifyIconA(win32.NIM_SETVERSION, &icon) == 0) {
                panicWithLastErr("failed to set notify icon version", .{});
            }
        },
        win32.WM_DESTROY => {
            var icon = std.mem.zeroes(win32.NOTIFYICONDATAA);
            icon.uID = icon_uid;
            icon.hWnd = hwnd;
            if (win32.Shell_NotifyIconA(win32.NIM_DELETE, &icon) == 0) {
                panicWithLastErr("failed to delete notify icon", .{});
            }
            win32.PostQuitMessage(0);
        },
        win32.WM_PAINT => {
            var ps = std.mem.zeroes(win32.PAINTSTRUCT);
            const hdc = win32.BeginPaint(hwnd, &ps) orelse panicWithLastErr("BeginPaint failed", .{});
            const brush_idx = @intFromEnum(win32.COLOR_WINDOW) + 1;
            const hbrush = win32.GetSysColorBrush(brush_idx) orelse panicWithLastErr("failed to get color brush {d}", .{brush_idx});

            if (win32.FillRect(hdc, &ps.rcPaint, hbrush) == 0) {
                logLastErr("FillRect failed");
            }
            _ = win32.EndPaint(hwnd, &ps);
        },
        icon_uid => {
            const x: u16 = @truncate(wParam);
            const y: u16 = @truncate(wParam >> 16);

            const icon_event: i16 = @truncate(lParam);
            switch (icon_event) {
                win32.NIN_SELECT => {
                    std.debug.print("x: {d}\ny: {d}\n", .{ x, y });
                    window_state.?.shown = !window_state.?.shown;
                    _ = win32.ShowWindow(hwnd, .{ .SHOWNORMAL = @intFromBool(window_state.?.shown) });
                },
                win32.WM_CONTEXTMENU => {
                    const hmenu = win32.LoadMenuA(hinst, @ptrFromInt(Resources.MENU_TRAY)) orelse panicWithLastErr("failed to load notify icon menu resource {d}", .{Resources.MENU_TRAY});
                    const hsubmenu = win32.GetSubMenu(hmenu, 0) orelse panicWithLastErr("failed to load notify icon menu {d} submenu", .{Resources.MENU_TRAY});

                    if (win32.SetForegroundWindow(hwnd) == 0) {
                        panicWithLastErr("failed to set foreground window while configuring tray icon menu", .{});
                    }

                    const cmd = win32.TrackPopupMenu(hsubmenu, .{ .BOTTOMALIGN = 1, .RETURNCMD = 1 }, x, y, 0, hwnd, null);

                    if (win32.PostMessageA(hwnd, win32.WM_NULL, 0, 0) == 0) {
                        panicWithLastErr("failed to post null message after tracking popup menu", .{});
                    }

                    switch (cmd) {
                        3 => {
                            _ = win32.MessageBoxA(hwnd, "All your codebase are belong to us!", window_name orelse "Zig Window", win32.MB_ICONEXCLAMATION);
                        },
                        else => std.log.err("unhandled menu selection {d} for menu {d}", .{ cmd, 2 }),
                    }

                    if (win32.DestroyMenu(hmenu) == 0) {
                        panicWithLastErr("failed to destroy notify icon menu", .{});
                    }
                },
                win32.WM_MOUSEMOVE => {},
                else => {
                    // const icon_id: i16 = @truncate(lParam >> 16);
                    std.debug.print("icon_event: {d}\n", .{icon_event});
                },
            }
        },
        // else => std.log.warn("unhandled message: {d}", .{uMsg}),
        else => {},
    }

    return win32.DefWindowProcA(hwnd, uMsg, wParam, lParam);
}

fn logLastErr(msg: []const u8) void {
    const err = win32.GetLastError();
    var buf: [1024]u8 = undefined;

    const str = std.fmt.bufPrintZ(&buf, "{s}: {s} ({d})", .{ msg, @tagName(err), @intFromEnum(err) }) catch @panic("OOM");
    std.log.err("{s}", .{str});

    _ = win32.MessageBoxA(null, str.ptr, "GetLastError", .{});
}

fn panicWithLastErr(comptime fmt: []const u8, args: anytype) noreturn {
    @branchHint(.cold);

    const err = win32.GetLastError();
    const err_num = @intFromEnum(err);

    var win32_buf: [1024]u8 = undefined;
    const win32_msg_len = switch (win32.FormatMessageA(
        .{ .IGNORE_INSERTS = 1, .FROM_SYSTEM = 1 },
        null,
        err_num,
        0,
        @ptrCast(&win32_buf),
        win32_buf.len,
        null,
    )) {
        0 => panicWithLastErr("failed to format last message string", .{}),
        else => |len| len,
    };

    std.log.err("win32 error: {s}", .{win32_buf[0..win32_msg_len]});

    var buf: [1024:0]u8 = undefined;
    const panic_str = std.fmt.bufPrint(&buf, fmt, args) catch @panic("panic_str buffer too small");

    @panic(panic_str);
}

const std = @import("std");
const win32 = @import("win32").everything;
