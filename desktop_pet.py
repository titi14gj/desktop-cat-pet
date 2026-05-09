import json
import math
import os
import sys
import time

os.environ.setdefault("TK_SILENCE_DEPRECATION", "1")

import tkinter as tk
from tkinter import ttk


APP_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(APP_DIR, "assets")
CONFIG_PATH = os.path.join(APP_DIR, "pet_config.json")
GIF_PATH = os.path.join(ASSETS_DIR, "cat.gif")

DEFAULT_CONFIG = {
    "size": 220,
    "duration_minutes": 0,
    "always_on_top": True,
    "click_through": False,
    "x": 80,
    "y": 180,
}


class Config:
    def __init__(self):
        self.data = DEFAULT_CONFIG.copy()
        self.load()

    def load(self):
        if not os.path.exists(CONFIG_PATH):
            return
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                loaded = json.load(f)
            for key in DEFAULT_CONFIG:
                if key in loaded:
                    self.data[key] = loaded[key]
        except (OSError, json.JSONDecodeError):
            pass

    def save(self):
        try:
            with open(CONFIG_PATH, "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=2)
        except OSError:
            pass

    def __getitem__(self, key):
        return self.data[key]

    def __setitem__(self, key, value):
        self.data[key] = value
        self.save()


class DesktopPet:
    def __init__(self):
        self.config = Config()
        self.solid_mode = "--solid" in sys.argv
        self.root = tk.Tk()
        self.root.title("Desktop Cat Pet")
        self.root.overrideredirect(True)
        self.transparent_bg = self.setup_window_background()
        self.root.wm_attributes("-topmost", bool(self.config["always_on_top"]))

        self.size = int(self.config["size"])
        self.start_time = time.time()
        self.drag_offset = (0, 0)
        self.gif_frames = []
        self.gif_index = 0
        self.settings_window = None
        self.phase = 0

        self.canvas = tk.Canvas(
            self.root,
            width=self.size,
            height=self.size,
            bg=self.transparent_bg,
            highlightthickness=0,
            bd=0,
        )
        self.canvas.pack(fill="both", expand=True)

        self.menu = tk.Menu(self.root, tearoff=0)
        self.menu.add_command(label="Settings", command=self.open_settings)
        self.menu.add_command(label="Quit", command=self.quit)

        self.root.bind("<ButtonPress-1>", self.start_drag)
        self.root.bind("<B1-Motion>", self.drag)
        self.root.bind("<ButtonRelease-1>", self.end_drag)
        self.root.bind("<Button-2>", self.show_menu)
        self.root.bind("<Button-3>", self.show_menu)
        self.root.bind("<Escape>", lambda _event: self.quit())
        self.root.bind("<s>", lambda _event: self.open_settings())
        self.root.bind("<S>", lambda _event: self.open_settings())

        self.load_gif()
        self.apply_geometry()
        self.animate()
        self.check_duration()

    def setup_window_background(self):
        if self.solid_mode:
            bg = "#f7f7f7"
            self.root.configure(bg=bg)
            return bg

        bg = "magenta"
        self.root.configure(bg=bg)
        try:
            self.root.wm_attributes("-transparentcolor", bg)
            return bg
        except tk.TclError:
            pass

        try:
            bg = "systemTransparent"
            self.root.configure(bg=bg)
            self.root.wm_attributes("-transparent", True)
            return bg
        except tk.TclError:
            bg = "#f7f7f7"
            self.root.configure(bg=bg)
            return bg

    def apply_geometry(self):
        x = int(self.config["x"])
        y = int(self.config["y"])
        try:
            screen_w = self.root.winfo_screenwidth()
            screen_h = self.root.winfo_screenheight()
            if x < 0 or y < 0 or x > screen_w - 48 or y > screen_h - 48:
                x, y = 80, 180
                self.config["x"] = x
                self.config["y"] = y
        except tk.TclError:
            pass
        self.root.geometry(f"{self.size}x{self.size}+{x}+{y}")
        self.canvas.configure(width=self.size, height=self.size)

    def load_gif(self):
        self.gif_frames.clear()
        if not os.path.exists(GIF_PATH):
            return

        frame = 0
        while True:
            try:
                image = tk.PhotoImage(file=GIF_PATH, format=f"gif -index {frame}")
            except tk.TclError:
                break
            self.gif_frames.append(image)
            frame += 1

    def start_drag(self, event):
        self.drag_offset = (event.x_root - self.root.winfo_x(), event.y_root - self.root.winfo_y())

    def drag(self, event):
        x = event.x_root - self.drag_offset[0]
        y = event.y_root - self.drag_offset[1]
        self.root.geometry(f"+{x}+{y}")

    def end_drag(self, _event):
        self.config["x"] = self.root.winfo_x()
        self.config["y"] = self.root.winfo_y()

    def show_menu(self, event):
        self.menu.tk_popup(event.x_root, event.y_root)

    def animate(self):
        self.canvas.delete("all")
        if self.gif_frames:
            self.draw_gif_frame()
            delay = 90
        else:
            self.draw_fallback_cat()
            delay = 55
        self.root.after(delay, self.animate)

    def draw_gif_frame(self):
        frame = self.gif_frames[self.gif_index]
        self.gif_index = (self.gif_index + 1) % len(self.gif_frames)
        max_side = max(frame.width(), frame.height())
        scale = max(1, math.ceil(max_side / max(1, self.size)))
        display = frame.subsample(scale, scale)
        self.canvas.image_ref = display
        self.canvas.create_image(self.size // 2, self.size // 2, image=display)

    def draw_fallback_cat(self):
        self.phase += 0.22
        s = self.size
        cx = s * 0.5
        bounce = math.sin(self.phase * 2) * s * 0.035
        sway = math.sin(self.phase) * s * 0.045
        head_y = s * 0.32 + bounce
        body_y = s * 0.56 + bounce
        tail_wave = math.sin(self.phase + 0.8) * s * 0.08
        paw_lift = math.sin(self.phase * 2.3) * s * 0.06

        shadow_w = s * (0.42 + 0.04 * math.sin(self.phase))
        self.canvas.create_oval(
            cx - shadow_w,
            s * 0.83,
            cx + shadow_w,
            s * 0.9,
            fill="#000000",
            outline="",
            stipple="gray25",
        )

        self.canvas.create_line(
            cx + s * 0.22,
            body_y,
            cx + s * 0.43,
            body_y - s * 0.08 + tail_wave,
            cx + s * 0.34,
            body_y - s * 0.18,
            width=max(6, int(s * 0.045)),
            fill="#f2a76f",
            smooth=True,
            capstyle=tk.ROUND,
        )
        self.canvas.create_oval(
            cx - s * 0.23 + sway,
            body_y - s * 0.18,
            cx + s * 0.23 + sway,
            body_y + s * 0.25,
            fill="#f7b982",
            outline="#5b3728",
            width=max(2, int(s * 0.012)),
        )
        self.canvas.create_polygon(
            cx - s * 0.22 + sway,
            head_y - s * 0.1,
            cx - s * 0.12 + sway,
            head_y - s * 0.31,
            cx - s * 0.02 + sway,
            head_y - s * 0.08,
            fill="#f7b982",
            outline="#5b3728",
            width=max(2, int(s * 0.01)),
        )
        self.canvas.create_polygon(
            cx + s * 0.22 + sway,
            head_y - s * 0.1,
            cx + s * 0.12 + sway,
            head_y - s * 0.31,
            cx + s * 0.02 + sway,
            head_y - s * 0.08,
            fill="#f7b982",
            outline="#5b3728",
            width=max(2, int(s * 0.01)),
        )
        self.canvas.create_oval(
            cx - s * 0.25 + sway,
            head_y - s * 0.2,
            cx + s * 0.25 + sway,
            head_y + s * 0.18,
            fill="#ffc58e",
            outline="#5b3728",
            width=max(2, int(s * 0.012)),
        )

        eye_y = head_y - s * 0.03
        for side in (-1, 1):
            self.canvas.create_oval(
                cx + side * s * 0.08 + sway - s * 0.018,
                eye_y - s * 0.018,
                cx + side * s * 0.08 + sway + s * 0.018,
                eye_y + s * 0.018,
                fill="#2b201a",
                outline="",
            )
        self.canvas.create_polygon(
            cx - s * 0.025 + sway,
            head_y + s * 0.035,
            cx + s * 0.025 + sway,
            head_y + s * 0.035,
            cx + sway,
            head_y + s * 0.07,
            fill="#dd6f7a",
            outline="",
        )
        self.canvas.create_arc(
            cx - s * 0.065 + sway,
            head_y + s * 0.045,
            cx + sway,
            head_y + s * 0.12,
            start=200,
            extent=120,
            outline="#5b3728",
            width=max(1, int(s * 0.008)),
            style=tk.ARC,
        )
        self.canvas.create_arc(
            cx + sway,
            head_y + s * 0.045,
            cx + s * 0.065 + sway,
            head_y + s * 0.12,
            start=220,
            extent=120,
            outline="#5b3728",
            width=max(1, int(s * 0.008)),
            style=tk.ARC,
        )

        for side in (-1, 1):
            foot_y = body_y + s * 0.26 + (paw_lift if side < 0 else -paw_lift)
            self.canvas.create_oval(
                cx + side * s * 0.12 + sway - s * 0.06,
                foot_y - s * 0.025,
                cx + side * s * 0.12 + sway + s * 0.06,
                foot_y + s * 0.035,
                fill="#ffd0a2",
                outline="#5b3728",
                width=max(1, int(s * 0.008)),
            )
        for side in (-1, 1):
            arm_y = body_y - s * 0.02 + (-paw_lift if side < 0 else paw_lift)
            self.canvas.create_line(
                cx + side * s * 0.16 + sway,
                body_y - s * 0.06,
                cx + side * s * 0.31 + sway,
                arm_y,
                width=max(5, int(s * 0.035)),
                fill="#ffc58e",
                capstyle=tk.ROUND,
            )

    def check_duration(self):
        minutes = float(self.config["duration_minutes"])
        if minutes > 0 and time.time() - self.start_time >= minutes * 60:
            self.quit()
            return
        self.root.after(1000, self.check_duration)

    def open_settings(self):
        if self.settings_window and self.settings_window.winfo_exists():
            self.settings_window.lift()
            return

        win = tk.Toplevel(self.root)
        self.settings_window = win
        win.title("Desktop Cat Settings")
        win.resizable(False, False)
        win.attributes("-topmost", True)

        frame = ttk.Frame(win, padding=14)
        frame.grid(row=0, column=0, sticky="nsew")

        size_var = tk.IntVar(value=int(self.config["size"]))
        duration_var = tk.DoubleVar(value=float(self.config["duration_minutes"]))
        top_var = tk.BooleanVar(value=bool(self.config["always_on_top"]))
        click_var = tk.BooleanVar(value=bool(self.config["click_through"]))

        ttk.Label(frame, text="Pet size").grid(row=0, column=0, sticky="w")
        size_scale = ttk.Scale(frame, from_=96, to=420, variable=size_var, command=lambda _v: self.update_size(size_var.get()))
        size_scale.grid(row=1, column=0, sticky="ew", pady=(4, 10))
        size_label = ttk.Label(frame, textvariable=size_var)
        size_label.grid(row=1, column=1, padx=(10, 0))

        ttk.Label(frame, text="Run time, minutes (0 = always)").grid(row=2, column=0, sticky="w")
        duration_entry = ttk.Entry(frame, textvariable=duration_var, width=8)
        duration_entry.grid(row=3, column=0, sticky="w", pady=(4, 10))

        ttk.Checkbutton(frame, text="Always on top", variable=top_var, command=lambda: self.update_topmost(top_var.get())).grid(
            row=4, column=0, sticky="w", pady=(0, 6)
        )
        ttk.Checkbutton(frame, text="Click through (disabled on macOS Tk)", variable=click_var, state="disabled").grid(row=5, column=0, sticky="w", pady=(0, 10))

        ttk.Button(frame, text="Apply duration", command=lambda: self.update_duration(duration_var.get())).grid(row=6, column=0, sticky="ew")
        ttk.Button(frame, text="Quit pet", command=self.quit).grid(row=7, column=0, sticky="ew", pady=(8, 0))
        frame.columnconfigure(0, minsize=240)

    def update_size(self, value):
        self.size = int(value)
        self.config["size"] = self.size
        self.apply_geometry()

    def update_duration(self, value):
        try:
            self.config["duration_minutes"] = max(0, float(value))
        except (TypeError, ValueError):
            self.config["duration_minutes"] = 0

    def update_topmost(self, value):
        self.config["always_on_top"] = bool(value)
        self.root.wm_attributes("-topmost", bool(value))

    def update_click_through(self, value):
        self.config["click_through"] = bool(value)

    def quit(self):
        self.config["x"] = self.root.winfo_x()
        self.config["y"] = self.root.winfo_y()
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    os.makedirs(ASSETS_DIR, exist_ok=True)
    try:
        DesktopPet().run()
    except KeyboardInterrupt:
        sys.exit(0)
