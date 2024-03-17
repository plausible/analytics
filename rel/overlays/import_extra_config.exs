import Config
import Plausible.ConfigHelpers

config_dir = System.get_env("CONFIG_DIR", "/run/secrets")

if extra_config_path = get_var_from_path_or_env(config_dir, "EXTRA_CONFIG_PATH") do
  import_config extra_config_path
end
