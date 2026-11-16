#!/usr/bin/env python3
"""Stand-in for pywal16's `wal --theme FILE`, used by the tests.

Renders every template the way pywal does (Python str.format with color
objects that have .strip / .rgb / .red / .green / .blue), so a template
with an unescaped brace or an unknown variable fails here first.

  fake-wal.py --theme FILE [-q -n -e]   render ~/.config/wal/templates -> ~/.cache/wal
  fake-wal.py --check TEMPLATE_DIR THEME_FILE...   render to memory, report errors
"""
import json
import os
import sys


class Color(str):
    """A '#rrggbb' string with pywal's template attributes."""

    @property
    def strip(self):
        return self[1:]

    def _channel(self, i):
        return str(int(self[1 + 2 * i:3 + 2 * i], 16))

    @property
    def red(self):
        return self._channel(0)

    @property
    def green(self):
        return self._channel(1)

    @property
    def blue(self):
        return self._channel(2)

    @property
    def rgb(self):
        return f"{self.red},{self.green},{self.blue}"


def variables(theme_file):
    data = json.load(open(theme_file))
    out = {k: Color(v) for k, v in data["special"].items()}
    out.update({k: Color(v) for k, v in data["colors"].items()})
    missing = [k for k in ["background", "foreground", "cursor"] + [f"color{i}" for i in range(16)] if k not in out]
    if missing:
        raise SystemExit(f"{theme_file}: missing {', '.join(missing)}")
    for k, v in out.items():
        if len(v) != 7 or v[0] != "#" or any(c not in "0123456789abcdefABCDEF" for c in v[1:]):
            raise SystemExit(f"{theme_file}: {k} = {v!r} is not #rrggbb")
    out["wallpaper"] = "None"
    return out


def render(template_dir, theme_file):
    values = variables(theme_file)
    results, errors = {}, []
    for name in sorted(os.listdir(template_dir)):
        path = os.path.join(template_dir, name)
        try:
            results[name] = open(path).read().format(**values)
        except (KeyError, ValueError, IndexError, AttributeError) as err:
            errors.append(f"{name} with {os.path.basename(os.path.dirname(theme_file))}: {type(err).__name__}: {err}")
    return results, errors


def main(argv):
    if argv[:1] == ["--check"]:
        template_dir, themes = argv[1], argv[2:]
        failed = False
        for theme in themes:
            _, errors = render(template_dir, theme)
            for e in errors:
                print(e)
                failed = True
        return 1 if failed else 0

    theme = argv[argv.index("--theme") + 1]
    home = os.path.expanduser("~")
    templates = os.path.join(os.environ.get("XDG_CONFIG_HOME", home + "/.config"), "wal", "templates")
    cache = os.path.join(os.environ.get("XDG_CACHE_HOME", home + "/.cache"), "wal")
    os.makedirs(cache, exist_ok=True)
    results, errors = render(templates, theme) if os.path.isdir(templates) else ({}, [])
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    for name, text in results.items():
        open(os.path.join(cache, name), "w").write(text)
    data = json.load(open(theme))
    json.dump({"wallpaper": "None", "special": data["special"], "colors": data["colors"]},
              open(os.path.join(cache, "colors.json"), "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
