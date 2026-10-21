import { definePlugin } from "@deepseek-ai/cordis";
import { existsSync, mkdirSync, copyFileSync, readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const here = dirname(fileURLToPath(import.meta.url));
const pkgRoot = join(here, "..");
const VERSION = JSON.parse(readFileSync(join(pkgRoot, "package.json"), "utf8")).version;

/** 数据家：DSH_HOME 优先，回退 ~/.dsh（与官方 resolveDshHome 同序） */
const dshHome = () => (process.env.DSH_HOME && process.env.DSH_HOME.trim()) || join(homedir(), ".dsh");

/** 幂等地把攻略 skill 安装进本实例数据家的 skills 目录（版本一致则跳过）。 */
function installSkill() {
  const src = join(pkgRoot, "skill", "twin-memory");
  const dst = join(dshHome(), "skills", "twin-memory");
  const stamp = join(dst, ".twin-memory.version");
  try {
    if (existsSync(stamp) && readFileSync(stamp, "utf8").trim() === VERSION) return;
    mkdirSync(dst, { recursive: true });
    const f = join(src, "SKILL.md");
    copyFileSync(f, join(dst, "SKILL.md"));
    writeFileSync(stamp, VERSION);
  } catch (e) {
    // 攻略装不上不致命：插件本体仍可作为载体被读到
    console.warn("[twin-memory] skill install skipped:", e?.message ?? e);
  }
}

export default definePlugin({
  name: "dsh-twin-memory",
  version: VERSION,
  /**
   * 双子记忆 · 载体插件
   * 本体刻意做薄：不注册工具、不碰提示词、不动网关契约（零地雷面）。
   * 价值全部承载在随包分发的 SKILL.md（攻略）、templates/（身份卡模板）
   * 与 scripts/check.ps1（双实例体检）—— 由 AI 读取执行，由官方 AGENTS.md
   * 通道完成身份注入。
   */
  async activate(ctx) {
    installSkill();
    ctx.logger?.info?.(`[twin-memory] v${VERSION} · 攻略与模板就位，等待认亲`);
  },
});
