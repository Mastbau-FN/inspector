const assert = require("node:assert/strict");
const { execFile } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { promisify } = require("node:util");

const run = promisify(execFile);

const restart = async (context, failure = "") => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "inspector-restart-"));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  const backend = path.join(directory, "backend");
  const bin = path.join(directory, "bin");
  const log = path.join(directory, "commands.log");
  await fs.mkdir(backend);
  await fs.mkdir(bin);
  await fs.copyFile(path.join(__dirname, "restart.sh"), path.join(backend, "restart.sh"));
  const command = `#!/bin/sh
name="$(basename "$0")"
printf '%s|%s %s\\n' "$PWD" "$name" "$*" >> "$RESTART_COMMAND_LOG"
case "$name $*" in
  "$RESTART_FAIL_COMMAND") exit 42 ;;
esac
`;
  for (const name of ["git", "sysctl", "docker-compose", "docker"]) {
    await fs.writeFile(path.join(bin, name), command, { mode: 0o755 });
  }
  let code = 0;
  try {
    await run("bash", [path.join(backend, "restart.sh")], {
      cwd: directory,
      env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, RESTART_COMMAND_LOG: log, RESTART_FAIL_COMMAND: failure },
    });
  } catch (error) {
    code = error.code;
  }
  const commands = (await fs.readFile(log, "utf8")).trim().split("\n");
  return { code, backend, commands: commands.map((line) => {
    const separator = line.indexOf("|");
    return { cwd: line.slice(0, separator), command: line.slice(separator + 1) };
  }) };
};

test("failed checkout prevents pull and service changes", async (context) => {
  const result = await restart(context, "git checkout staging");
  assert.equal(result.code, 42);
  assert.deepEqual(result.commands.map((item) => item.command), ["git checkout staging"]);
});

test("failed pull prevents stopping or restarting services", async (context) => {
  const result = await restart(context, "git pull --ff-only");
  assert.equal(result.code, 42);
  assert.deepEqual(result.commands.map((item) => item.command), ["git checkout staging", "git pull --ff-only"]);
});

test("invalid compose configuration prevents stopping services", async (context) => {
  const result = await restart(context, "docker-compose config --quiet");
  assert.equal(result.code, 42);
  assert.deepEqual(result.commands.map((item) => item.command), [
    "git checkout staging", "git pull --ff-only", "docker-compose config --quiet",
  ]);
});

test("restart validates prerequisites before service changes from its own directory", async (context) => {
  const result = await restart(context);
  assert.equal(result.code, 0);
  assert.deepEqual(result.commands.map((item) => item.command), [
    "git checkout staging", "git pull --ff-only", "docker-compose config --quiet",
    "sysctl -w net.ipv4.ip_unprivileged_port_start=442", "docker-compose down",
    "docker-compose up -d", "docker logs -f backend_node-api-server_1",
  ]);
  assert.ok(result.commands.every((item) => item.cwd === result.backend));
});
