# 공통 지침

모든 프로젝트에 적용한다. 프로젝트 AGENTS.md(없으면 CLAUDE.md)에 더 구체적인 규칙이 있으면 그것을 함께 따른다.

<!-- 원본은 user_env 저장소의 config/codex/AGENTS.md 이고, ~/.codex/AGENTS.md 는 링크다. 저장소 원본을 고칠 것. -->
<!-- 공통 규칙(응답·커밋·민감 정보)은 config/claude/CLAUDE.md 와 같게 유지한다. 한쪽을 고치면 다른 쪽도 고칠 것. -->

## Codex 설정
- `~/.codex/AGENTS.md` 는 user_env 저장소 원본에 대한 심볼릭 링크다.
  지침을 바꿀 때는 저장소 파일을 고치고 커밋한다.
- 프로젝트에 AGENTS.md 가 없고 CLAUDE.md 만 있으면 그 CLAUDE.md 를 읽고 따른다.
  (CLAUDE.md 안의 Claude 전용 도구·설정 설명은 해당하는 Codex 기능으로 바꿔 이해한다.)

## 응답
- 한국어로 응답한다.

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
