# 공통 지침

모든 프로젝트에 적용한다. 프로젝트 AGENTS.md(없으면 CLAUDE.md)에 더 구체적인 규칙이 있으면 그것을 함께 따른다.

<!-- 원본은 user_env 저장소의 config/codex/AGENTS.md 이고, ~/.codex/AGENTS.md 는 링크다. 저장소 원본을 고칠 것. -->
<!-- 공통 규칙(응답·커밋·민감 정보)은 config/claude/CLAUDE.md 와 같게 유지한다. 한쪽을 고치면 다른 쪽도 고칠 것. -->

## Codex 설정
- `~/.codex/AGENTS.md` 는 user_env 저장소 원본에 대한 심볼릭 링크다.
  지침을 바꿀 때는 저장소 파일을 고치고 커밋한다.
- 프로젝트에 AGENTS.md 가 없고 CLAUDE.md 만 있으면 그 CLAUDE.md 를 읽고 따른다.
  (CLAUDE.md 안의 Claude 전용 도구·설정 설명은 해당하는 Codex 기능으로 바꿔 이해한다.)

## 사용자
- 인프라 / DevOps / 시스템 / SRE / 플랫폼 엔지니어.
- 주 스택: Linux(Rocky), Puppet, Chef, Kubernetes, Terraform, AWS, GCP, Tencent Cloud.
- 자동화 도구와 운영 스크립트는 주로 Python으로 만들어 왔다.
- 프론트엔드(JS/TS, React, CSS 등)는 익숙하지 않다.
- 요즘은 코드를 직접 작성하지 않고 AI가 작성한 코드를 검토해서 쓴다. 언어·라이브러리 선호는 따로 없다.

## 환경
- 로컬: Windows + WSL2 Ubuntu, zsh.
- 대상 서버: Rocky Linux 기준 (dnf, systemd, SELinux, firewalld).
- 서버용 명령·설정을 제안할 때 Ubuntu(apt, ufw)와 섞지 말고, 어느 환경 기준인지 밝힌다.

## 응답
- 한국어로 응답한다. 코드 주석·변수명은 프로젝트 규칙을 따르고, 규칙이 없으면 영어로 쓴다.
- 인프라·Linux·클라우드 기본 개념은 설명을 생략하고 바로 핵심으로 간다.
- 프론트엔드 관련 작업은 왜 그렇게 하는지 이유까지 설명한다.
- Tencent Cloud는 자료가 적으니, 확실하지 않은 API·리소스·CLI 옵션 이름을 추측하지 말고 확인이 필요하다고 표시한다.

## 코드 작성
- 사용자가 직접 고치지 않고 검토만 하므로, 읽기 쉽고 단순한 코드를 우선한다.
- 라이브러리·도구는 업계 표준이고 유지보수가 쉬운 쪽을 고르고, 고른 이유를 한 줄로 남긴다.
- 작업을 마치면 무엇을 바꿨는지, 어떻게 검증했는지(또는 검증하지 못한 것)를 짧게 요약한다.
- 상태를 바꾸는 스크립트는 dry-run 옵션을 두고, 다시 실행해도 안전하게(멱등) 만든다.

## 인프라 작업 안전
- 실행 전에 반드시 확인받는다: `terraform apply/destroy`, `kubectl apply/delete`, `rm -rf`,
  패키지 삭제, 방화벽·SELinux 변경, Puppet/Chef 적용, `git push --force`.
- Terraform은 plan 결과를 먼저 보여주고, kubectl은 현재 context/namespace를 먼저 확인한다.

## 커밋 / PR
- 커밋 메시지와 PR 본문에 Codex·OpenAI·AI 관련 서명을 넣지 않는다.
  (`Co-authored-by: Codex ...`, `Generated with ...`, 세션 링크 등 어떤 형태도 금지)
- 푸시는 사용자가 명시적으로 요청할 때만 한다. 커밋 요청에 푸시가 포함된 것으로 해석하지 않는다.

## 민감 정보
- 아래 비밀값 파일은 어떤 방법으로도(`cat`, `grep`, `head`, `sed`, `env`/`printenv` 출력 등) 읽지 않는다.
  Codex에는 파일 단위 읽기 차단 설정이 없으므로 이 지침이 유일한 방어선이다.
  - `~/.env_vars`, `/etc/zsh/alias.sh`
  - `~/.ssh/`, `~/.aws/credentials`, `~/.tccli/`, `~/.codex/auth.json`, `~/.claude/.credentials.json`
  - `.env`, `.env.*`, `*.tfvars`, `*.tfstate`, `*.pem`, `*.key`, eyaml 키
- 값이 필요하면 직접 읽지 말고 사용자에게 존재 여부나 필요한 정보만 확인받는다.
- credential·개인키·비밀번호·토큰·사내 IP/계정명을 커밋하거나 외부 서비스로 보내지 않는다.
