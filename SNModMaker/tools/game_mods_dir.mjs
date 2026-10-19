import fs from 'node:fs';
import path from 'node:path';

const PLATFORM_TARGETS = { win32: 'windows', darwin: 'macos' };

/**
 * Resolve the directory the export menu deploys packaged mods into.
 *
 * Precedence:
 * 1. `SNMODMAKER_GAME_MODS_DIR` (explicit target, e.g. another game install).
 * 2. An exported release build: the current platform's `dist/build/<target>/`
 *    first, then any other exported target.
 * 3. `dist/build/<platform>/mods`, so the first deploy prepares the layout the
 *    release archive expects (exe next to `mods/` and `config/`).
 */
export function resolveGameModsDir(root, options = {}) {
  const env = options.env || process.env;
  const platform = options.platform || process.platform;
  const exists = options.exists || fs.existsSync;
  if (env.SNMODMAKER_GAME_MODS_DIR) {
    return path.resolve(env.SNMODMAKER_GAME_MODS_DIR);
  }
  const preferred = PLATFORM_TARGETS[platform] || 'linux';
  const buildRoot = path.join(root, '..', 'dist', 'build');
  const targets = [...new Set([preferred, 'windows', 'linux', 'macos'])];
  for (const target of targets) {
    if (exists(path.join(buildRoot, target))) {
      return path.join(buildRoot, target, 'mods');
    }
  }
  return path.join(buildRoot, preferred, 'mods');
}
