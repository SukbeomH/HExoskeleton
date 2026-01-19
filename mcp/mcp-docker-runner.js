#!/usr/bin/env node
/**
 * MCP Docker Runner
 * Docker 컨테이너로 MCP 서버를 실행하고 stdio를 통해 JSON-RPC 통신을 중계합니다.
 *
 * 사용법:
 *   node mcp-docker-runner.js <container-name> [options]
 *
 * 옵션:
 *   --build    컨테이너 이미지를 먼저 빌드합니다
 *   --verbose  상세 로그를 출력합니다
 *
 * 예시:
 *   node mcp-docker-runner.js serena
 *   node mcp-docker-runner.js codanna --build
 *   node mcp-docker-runner.js shrimp --verbose
 *
 * 지원하는 컨테이너:
 *   - serena: 심볼 기반 코드 검색 및 편집
 *   - codanna: 시맨틱 코드 검색 및 분석
 *   - shrimp: 구조화된 작업 관리
 */

const { spawn, execSync } = require("child_process");
const path = require("path");

// 명령줄 인자 파싱
const args = process.argv.slice(2);
const flags = args.filter((arg) => arg.startsWith("--"));
const positionalArgs = args.filter((arg) => !arg.startsWith("--"));

// 옵션 추출
const shouldBuild = flags.includes("--build");
const verbose = flags.includes("--verbose");

// 컨테이너 이름 확인
const VALID_CONTAINERS = ["serena", "codanna", "shrimp", "context7"];
const containerName = positionalArgs[0];

if (!containerName) {
  console.error(
    "[Error] 컨테이너 이름이 필요합니다. (serena, codanna, shrimp)"
  );
  console.error("사용법: node mcp-docker-runner.js <container-name> [--build]");
  process.exit(1);
}

if (!VALID_CONTAINERS.includes(containerName)) {
  console.error(
    `[Error] 알 수 없는 컨테이너: ${containerName}`
  );
  console.error(`지원하는 컨테이너: ${VALID_CONTAINERS.join(", ")}`);
  process.exit(1);
}

// 경로 설정
const scriptDir = __dirname;
const composeFile = path.join(scriptDir, "docker-compose.mcp.yml");
const projectRoot = process.env.TARGET_PROJECT_PATH || process.cwd();

// 환경 변수 설정
const env = {
  ...process.env,
  TARGET_PROJECT_PATH: projectRoot,
};

/**
 * 로그 출력 (stderr로 출력하여 stdout 오염 방지)
 */
function log(message, level = "info") {
  if (!verbose && level === "debug") return;

  const prefix = {
    info: "[Info]",
    debug: "[Debug]",
    error: "[Error]",
    warn: "[Warn]",
  }[level] || "[Info]";

  console.error(`${prefix} ${message}`);
}

/**
 * Docker 이미지 빌드
 */
function buildImage() {
  log(`Building ${containerName} container...`);

  try {
    execSync(`docker-compose -f "${composeFile}" build ${containerName}`, {
      stdio: verbose ? "inherit" : "pipe",
      env,
    });
    log(`Build completed for ${containerName}`, "info");
  } catch (err) {
    console.error(`[Error] Build failed: ${err.message}`);
    process.exit(1);
  }
}

/**
 * Docker 컨테이너 실행 및 stdio 중계
 */
function runContainer() {
  log(`Starting ${containerName} container...`, "debug");
  log(`Project path: ${projectRoot}`, "debug");

  // docker-compose run 명령어 구성
  // -T: pseudo-TTY 비활성화 (stdio 통신용)
  // --rm: 종료 시 컨테이너 자동 삭제
  const dockerProc = spawn(
    "docker-compose",
    ["-f", composeFile, "run", "--rm", "-T", containerName],
    {
      env,
      stdio: ["pipe", "pipe", "pipe"],
    }
  );

  // stdin 중계 (Host → Container)
  process.stdin.pipe(dockerProc.stdin);

  // stdout 중계 (Container → Host)
  // JSON-RPC 메시지만 stdout으로, 나머지는 stderr로
  dockerProc.stdout.on("data", (data) => {
    const output = data.toString();

    output.split("\n").forEach((line) => {
      if (!line.trim()) return;

      // JSON-RPC 메시지 (중괄호로 시작) → stdout
      if (line.trim().startsWith("{")) {
        try {
          // JSON 유효성 검증
          JSON.parse(line.trim());
          process.stdout.write(line + "\n");
        } catch {
          // 유효하지 않은 JSON은 로그로 처리
          log(`[Container stdout]: ${line}`, "debug");
        }
      } else {
        // 일반 로그 → stderr
        log(`[Container]: ${line}`, "debug");
      }
    });
  });

  // stderr 중계 (Container stderr → Host stderr)
  dockerProc.stderr.on("data", (data) => {
    const output = data.toString();
    output.split("\n").forEach((line) => {
      if (line.trim()) {
        log(`[Container stderr]: ${line}`, "debug");
      }
    });
  });

  // 에러 핸들링
  dockerProc.on("error", (err) => {
    console.error(`[Docker Error] ${err.message}`);

    // Docker 관련 일반적인 에러 안내
    if (err.message.includes("ENOENT")) {
      console.error(
        "[Hint] Docker 또는 docker-compose가 설치되어 있는지 확인하세요."
      );
    }

    process.exit(1);
  });

  // 종료 핸들링
  dockerProc.on("close", (code, signal) => {
    if (signal) {
      log(`Container terminated by signal: ${signal}`, "debug");
    } else if (code !== 0) {
      log(`Container exited with code: ${code}`, "warn");
    }
    process.exit(code || 0);
  });

  // Graceful shutdown
  const cleanup = (signal) => {
    log(`Received ${signal}, stopping container...`, "debug");
    dockerProc.kill(signal);
  };

  process.on("SIGINT", () => cleanup("SIGINT"));
  process.on("SIGTERM", () => cleanup("SIGTERM"));

  // stdin 종료 시 컨테이너도 종료
  process.stdin.on("end", () => {
    log("stdin closed, stopping container...", "debug");
    dockerProc.stdin.end();
  });
}

// 메인 실행
if (shouldBuild) {
  buildImage();
}

runContainer();
