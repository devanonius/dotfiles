# Validates one install config file. Prints one line per problem; prints
# nothing when the file is valid. Mirrors config/config.schema.json.

def names($path):
  if type != "array" then "\($path) must be a list of package names"
  else .[] | select(type != "string" or (test("^[A-Za-z0-9@_+][A-Za-z0-9@._+-]*$") | not))
       | "\($path): invalid package name \(tojson)"
  end;

def only_keys($path; $allowed):
  keys[] | select(IN($allowed[]) | not)
  | if $path == "" then "unknown key: \(.)" else "unknown key: \($path).\(.)" end;

if type != "object" then "the top level must be a JSON object"
else
  only_keys(""; ["$schema", "modules", "hardware", "nvidia_driver", "fonts", "greeter", "extra_packages", "flatpak"]),

  (select(has("greeter")) | .greeter
   | select(type != "string" or (test("^(keep|[a-z0-9][a-z0-9._+-]*)$") | not))
   | "greeter must be \"keep\" or a package name"),

  (select(has("hardware") and (.hardware | type) != "boolean") | "hardware must be true or false"),

  (select(has("nvidia_driver") and (.nvidia_driver | IN("auto", "open", "580xx", "none") | not))
   | "nvidia_driver must be \"auto\", \"open\", \"580xx\" or \"none\""),

  (select(has("fonts")) | .fonts
   | if type == "string" then (select(IN("ask", "all", "none") | not) | "fonts must be \"ask\", \"all\", \"none\" or a list of font packages")
     else names("fonts") end),

  (select(has("modules")) | .modules
   | if type != "object" then "modules must be an object"
     else to_entries[]
       | select((.value | type) != "boolean" and .value != "auto")
       | "modules.\(.key) must be true, false or \"auto\""
     end),

  (select(has("extra_packages")) | .extra_packages
   | if type != "object" then "extra_packages must be an object"
     else only_keys("extra_packages"; ["pacman", "aur", "flatpak"]),
          (to_entries[] | .key as $k | .value | names("extra_packages.\($k)"))
     end),

  (select(has("flatpak")) | .flatpak
   | if type != "object" then "flatpak must be an object"
     else only_keys("flatpak"; ["scope", "remote", "remote_url"]),
          (select(has("scope") and (.scope | IN("user", "system") | not))
           | "flatpak.scope must be \"user\" or \"system\""),
          (select(has("remote") and (.remote | type) != "string") | "flatpak.remote must be a string"),
          (select(has("remote_url") and (.remote_url | type) != "string") | "flatpak.remote_url must be a string")
     end)
end
