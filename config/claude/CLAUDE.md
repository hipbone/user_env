# 공통 지침

모든 프로젝트에 적용한다. 프로젝트 CLAUDE.md에 더 구체적인 규칙이 있으면 그것을 함께 따른다.

<!-- 원본은 user_env 저장소의 config/claude/CLAUDE.md 이고, ~/.claude/CLAUDE.md 는 링크다. 저장소 원본을 고칠 것. -->

## Claude Code 설정
- `~/.claude/settings.json` 과 이 파일은 user_env 저장소 원본에 대한 심볼릭 링크다.
  설정을 바꿀 때는 저장소 파일을 고치고 커밋한다.

## 응답
- 한국어로 응답한다.

## 커밋 / PR
- 커밋 메시지와 PR 본문에 Claude·AI 관련 서명을 넣지 않는다.
  (`Co-Authored-By: Claude ...`, `Generated with Claude Code`, 세션 링크 등 어떤 형태도 금지)
- 푸시는 사용자가 명시적으로 요청할 때만 한다. 커밋 요청에 푸시가 포함된 것으로 해석하지 않는다.

## 민감 정보
- 아래 비밀값 파일은 Read 도구뿐 아니라 Bash(`cat`, `grep`, `head`, `env`/`printenv` 출력 등)로도 읽지 않는다.
  - `~/.env_vars`, `/etc/zsh/alias.sh`
  - `~/.ssh/`, `~/.aws/credentials`, `~/.tccli/`, `~/.claude/.credentials.json`
  - `.env`, `.env.*`, `*.tfvars`, `*.tfstate`, `*.pem`, `*.key`, eyaml 키
- 값이 필요하면 직접 읽지 말고 사용자에게 존재 여부나 필요한 정보만 확인받는다.
- credential·개인키·비밀번호·토큰·사내 IP/계정명을 커밋하거나 외부 서비스로 보내지 않는다.
