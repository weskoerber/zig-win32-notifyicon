const icon_uid: u32 = 69;

const WindowState = struct {
    shown: bool = true,
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

    const class_atom = win32.RegisterClassA(&wc);
    if (class_atom == 0) {
        logLastErr("failed to register class");
        return 1;
    }

    std.log.debug("sucessfully registered class name {s}: {d}", .{
        class_name,
        class_atom,
    });

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
    )) |h| h else {
        logLastErr("failed to create window");
        return 1;
    };

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

    if (uMsg == win32.WM_CREATE) {
        if (lParam > 0) {
            const p: *win32.CREATESTRUCTA = @ptrFromInt(@as(usize, @bitCast(lParam)));
            window_state = @ptrCast(p.lpCreateParams);
        }
        _ = win32.SetWindowLongPtrA(hwnd, win32.GWLP_USERDATA, @bitCast(@intFromPtr(window_state)));
    }

    const r: usize = @bitCast(win32.GetWindowLongPtrA(hwnd, win32.GWLP_USERDATA));
    if (r > 0) {
        window_state = @ptrFromInt(r);
    }

    switch (uMsg) {
        win32.WM_CREATE => {
            var icon = std.mem.zeroes(win32.NOTIFYICONDATAA);
            icon.cbSize = @sizeOf(win32.NOTIFYICONDATAA);
            icon.hWnd = hwnd;
            icon.uID = icon_uid;
            icon.uCallbackMessage = icon_uid;
            icon.uFlags = .{
                .TIP = 1,
                .MESSAGE = 1,
            };
            _ = std.fmt.bufPrintZ(&icon.szTip, "Zig Icon", .{}) catch @panic("OOM");

            if (win32.Shell_NotifyIconA(win32.NIM_ADD, &icon) == 0) {
                logLastErr("failed to create icon");
                return -1;
            }

            icon.Anonymous.uVersion = win32.NOTIFYICON_VERSION_4;
            if (win32.Shell_NotifyIconA(win32.NIM_SETVERSION, &icon) == 0) {
                logLastErr("failed to create icon");
                return -1;
            }
        },
        win32.WM_DESTROY => {
            var icon = std.mem.zeroes(win32.NOTIFYICONDATAA);
            icon.uID = icon_uid;
            _ = win32.Shell_NotifyIconA(win32.NIM_DELETE, &icon);
            win32.PostQuitMessage(0);
        },
        win32.WM_PAINT => {
            var ps = std.mem.zeroes(win32.PAINTSTRUCT);
            const hdc = win32.BeginPaint(hwnd, &ps);

            if (win32.FillRect(hdc, &ps.rcPaint, win32.GetSysColorBrush(@intFromEnum(win32.COLOR_WINDOW) + 1)) == 0) {
                logLastErr("FillRect failed");
            }
            _ = win32.EndPaint(hwnd, &ps);
        },
        icon_uid => {
            const icon_event: i16 = @truncate(lParam);
            // const icon_id: i16 = @truncate(lParam >> 16);
            // std.debug.print("icon_id: {d}\nicon_event: {d}\n", .{ icon_id, icon_event });

            // const x: u16 = @truncate(wParam);
            // const y: u16 = @truncate(wParam >> 16);
            // std.debug.print("x: {d}\ny: {d}\n", .{ x, y });

            switch (icon_event) {
                win32.NIN_SELECT => {
                    if (window_state) |w| {
                        w.shown = !w.shown;
                        _ = win32.ShowWindow(hwnd, .{ .SHOWNORMAL = @intFromBool(w.shown) });
                    }
                },
                else => {},
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

const std = @import("std");
const win32 = @import("win32").everything;
