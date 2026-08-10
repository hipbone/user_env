# CLAUDE.md

이 저장소에서 작업할 때 Claude Code가 따라야 할 설계 원칙과 작업 지침입니다.

---

## 1. 프로젝트 목적

`user_env`는 **개인 작업 환경(dotfiles + 설치 자동화) 저장소**입니다.

1. **빠른 구성** — 회사/집의 새 PC·서버·컨테이너에서 최소한의 명령으로 작업 환경을 세팅한다.
2. **동일성 보장** — 어느 장비에서든 같은 설정, 같은 alias, 같은 프롬프트, 같은 키바인딩을 얻는다.
3. **장비 이식성** — Windows(WSL) / macOS / Linux 어디로 옮겨도 원래 쓰던 환경이 그대로 재현된다.

포함 범위: 터미널/셸 설정, 에디터 설정, 작업 도구(CLI) 설치 자동화, 자주 쓰는 alias 및 helper 함수 관리.

> git 설정은 **이 저장소에서 관리하지 않는다.** 별도 프로젝트로 분리되어 있으므로
> `gitconfig` 류 파일을 여기에 추가하지 말 것.

> **판단 기준**: 어떤 변경을 넣을지 말지 애매하면 *"새 장비에서 이게 없으면 불편한가?"* 로 판단한다.
> 특정 프로젝트에서만 필요한 설정은 이 저장소가 아니라 해당 프로젝트에 둔다.

---

## 2. 핵심 설계 원칙

이 원칙들은 이미 코드에 반영되어 있으며, 새 코드도 반드시 따라야 합니다.

### 2.1 심볼릭 링크 우선 (Symlink, not Copy)

설정 파일은 **저장소가 원본(Single Source of Truth)** 이고, 홈 디렉토리에는 링크만 건다.

```
repo/zshrc_ubuntu     →  ~/.zshrc
repo/alias/           →  ~/alias
repo/functions/       →  ~/functions
repo/config/tmux.conf →  ~/.tmux.conf
repo/config/vimrc     →  ~/.vimrc
repo/config/p10k.zsh  →  ~/.p10k.zsh
```

- 이유: `git pull` 한 번으로 모든 장비의 설정이 갱신된다.
- 링크는 `setEnv.sh` 의 `set_dotfiles()` 한 곳에서만 만든다. 다른 함수에 링크 코드를 흩뿌리지 말 것.
- 디렉토리를 링크할 때는 반드시 `ln -fsn` (`-n` 없으면 기존 링크 *안쪽*에 중첩 생성된다).
- 기존 실제 파일은 `backup_if_real_file()` 로 `.bak` 백업 후 교체한다.
- **예외 — Windows.** Windows 파일시스템(drvfs)에는 WSL 심볼릭 링크가 통하지 않는다.
  VS Code(Windows 사용자 설정)와 Windows Terminal은 **복사**로 동기화한다 (`winpush` / `winpull`).
  Windows 대상에 `ln -s` 를 쓰려고 시도하지 말 것.

### 2.2 멱등성 (Idempotent)

모든 스크립트는 **몇 번을 다시 실행해도 안전**해야 한다.

- 설치 전 존재 확인: `if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then ... fi`
- 링크는 항상 `ln -fs` / `ln -fsn` (강제 갱신)
- append 형태는 반드시 사전 확인: `sudo test -f /etc/sudoers.d/$USER || echo ... | sudo tee`

### 2.3 조건부 로드 (Fail-soft)

`.zshrc`와 alias는 **도구가 설치되지 않은 장비에서도 에러 없이** 로드되어야 한다.
장비마다 설치된 도구가 다르므로 이건 타협 불가 규칙이다.

```bash
# 좋음
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# 나쁨 — 도구가 없는 장비에서 매 셸 시작마다 에러
eval "$(direnv hook zsh)"
```

### 2.4 비밀값은 저장소 밖으로

- 토큰·API 키·개인 환경변수는 **`~/.env_vars`** 에 두고, `.zshrc`가 `test -f ... && source`로 읽는다.
- 머신 로컬 alias(사내 IP, 계정명 등)는 **`/etc/zsh/alias.sh`** 에 두고 조건부 로드한다.
- 이 저장소는 public 가능성을 전제로 한다. **credential, 개인키, 비밀번호를 절대 커밋하지 않는다.**

### 2.5 OS 분기는 한 곳에서

OS 판별은 `get_os()` (`/etc/os-release`의 `ID`/`VERSION_ID`, 없으면 `uname`) 한 군데에서만 하고,
그 결과 `${OS}`로 `case` 분기한다. 스크립트 여기저기서 `uname`을 다시 부르지 않는다.

- 리눅스 여부: `is_linux` (`if is_linux; then` 또는 `is_linux && ...`)
- WSL 여부: `is_wsl`
- 아키텍처: `get_arch` → `ARCH_ALIAS` (`amd64` / `arm64`)

지원하지 않는 OS를 만나면 조용히 실패하지 말고 `"지원하지 않는 배포판입니다. : ${OS}"` 를 출력한다.

### 2.6 실행 위치에 의존하지 않는다

경로는 `${PWD}` 가 아니라 스크립트 위치 기준 `${repo_dir}` 를 쓴다.

```bash
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

임시 파일은 `${tmp_dir}` (= `${repo_dir}/tmp`)에 만들고, `cd` 없이 절대 경로로 다룬 뒤 정리한다.
`cd` 후 상대 경로로 `rm -rf` 하는 패턴은 금지.

---

## 3. 저장소 구조

```
user_env/
├── setEnv.sh                     # 메인 진입점 (Ubuntu 검증 완료)
├── setting_mac.sh                # macOS 구성 (미검증)
├── set_locales.sh                # ko_KR.UTF-8 로케일
│
├── zshrc_ubuntu                  # → ~/.zshrc (Ubuntu / WSL)
├── zshrc_mac                     # → ~/.zshrc (macOS)
│
├── alias/                        # → ~/alias
│   ├── default/                  #   모든 OS 공통
│   └── ubuntu/                   #   Ubuntu 전용
├── functions/                    # → ~/functions (helper 함수)
│
├── config/
│   ├── p10k.zsh                  # → ~/.p10k.zsh   (프롬프트 동일성)
│   ├── tmux.conf                 # → ~/.tmux.conf
│   ├── vimrc                     # → ~/.vimrc      (플러그인 없는 최소 설정)
│   ├── vscode-settings.json      # → Windows (복사)
│   ├── wt-settings.json          # → Windows (복사)
│   └── puppet-lint.rc            #   참고용 (연동 대상 아님)
│
├── .editorconfig
├── README.md
├── history.md                    # 구조 변경 이력 (왜 그렇게 했는지)
└── CLAUDE.md
```

### 지원 플랫폼 현황

| 플랫폼 | 스크립트 | 상태 |
| --- | --- | --- |
| Ubuntu (Linux / WSL) | `setEnv.sh` | 검증 완료 — **기준 구현** |
| Windows (WSL 경유) | `setEnv.sh -e winpush/winpull` | 부분 지원 (VS Code, Terminal) |
| macOS | `setting_mac.sh` | 미검증 |

---

## 4. setEnv.sh

### 사용법

```bash
bash setEnv.sh -h              # 도움말

# 셸 환경
bash setEnv.sh -e default      # 전체 구성 (zsh + oh-my-zsh + p10k + 링크)
bash setEnv.sh -e dotfiles     # 홈 심볼릭 링크만 다시 걸기

# Windows 연동 (WSL 전용)
bash setEnv.sh -e winpush      # 저장소 → Windows
bash setEnv.sh -e winpull      # Windows → 저장소

# 도구 설치
bash setEnv.sh -e opentofu|awscli|brew|tccli|coscli|go
```

### 내부 구조 (파일 내 섹션 주석 유지)

```
1. 변수 선언  →  2. 함수 선언  →  3. 인자 파싱  →  4. Main
```

Main 흐름: `get_os` → `get_pkgmanager` → `configure_environment "$environment"`

> 필수 패키지 설치(`requirement_package`)는 `set_default` 안에서만 호출한다.
> 도구 설치만 하려는 사용자에게 apt 갱신을 강요하지 않기 위함이다.

### 새 도구(`-e` 항목) 추가 체크리스트

1. `set_<도구>()` 함수를 §2 "함수 선언" 영역에 추가
2. `configure_environment()`의 `case`에 분기 추가 (리눅스 전용이면 `is_linux && set_<도구>`)
3. `print_help()`에 한 줄 추가 (해당 카테고리 안에)
4. 아키텍처 의존 설치면 `get_arch` 호출 후 `${ARCH_ALIAS}` 사용
5. 설치 후 `command -v` 로 검증하고 성공/실패 메시지 출력
6. 필요하면 `zshrc_ubuntu`에 **조건부** PATH 설정 추가 (§2.3)
7. 필요하면 `alias/default/<도구>.alias` 추가
8. `README.md` 표 갱신
9. 파일 헤더의 `Last Update` / `Version` 갱신

### 새 설정 파일 연동 추가

- Linux/macOS 대상이면 `set_dotfiles()` 의 `links` 배열에 `"저장소경로:홈경로"` 한 줄 추가.
- Windows 대상이면 `build_win_pairs()` 에 추가하고, 부모 디렉토리 존재 확인으로 미설치를 건너뛸 것.
- `setting_mac.sh` 의 `set_link()` 에도 같은 대상을 반영한다 (두 파일이 갈라지지 않게).

---

## 5. alias / functions 관리 규칙

### 로드 경로

`.zshrc`가 다음 순서로 읽는다:

1. `~/alias/default/*` — 모든 환경
2. `~/alias/ubuntu/*` — Ubuntu 전용 (macOS는 로드 안 함)
3. `~/functions/*` — helper 함수
4. `/etc/zsh/alias.sh` — 저장소 밖, 머신 로컬 (있을 때만)

### alias vs functions

| 성격 | 위치 |
| --- | --- |
| 한 줄 치환으로 끝남 | `alias/` |
| 인자 처리·분기·다중 명령이 필요 | `functions/` |
| OS 무관, 모든 장비에서 유용 | `alias/default/` |
| Ubuntu/WSL 전용 (`sudo`, apt 등) | `alias/ubuntu/` |
| 특정 장비/사내망에서만 유효 | `/etc/zsh/alias.sh` (커밋 안 함) |

### 작성 규칙

- alias 파일명은 `<도구/주제>.alias`, functions 파일은 `<주제>.zsh`. 주제 하나에 파일 하나.
- 각 파일 상단에 주석으로 목적과 전제 조건을 적는다 (`alias/default/opshub.alias` 가 모범).
- 도구 존재 여부에 의존하면 가드를 건다:
  ```bash
  [ -x "$(which batcat)" ] && alias cat="batcat"
  command -v terraform &>/dev/null && alias tf='terraform'
  ```
- 접두어로 네임스페이스를 만든다 (`oh-` = ops-hub, `tc-` = tencent, `k` = kubectl).

> ⚠️ **현재 `alias/ubuntu/{puppet,traefik,hipbone}.alias` 에 사내 서버 IP와 계정명이 하드코딩되어 있고,
> `alias/default/tccli.alias` 에는 Tencent 계정 UIN이 들어 있다.**
> 새 alias를 추가할 때 이 패턴을 따라 하지 말 것. 조직 내부 정보는 `/etc/zsh/alias.sh` 로 분리한다.

---

## 6. 코딩 규칙

### Shell

- `#!/bin/bash` 셔뱅. 실행은 `bash <script>` 로 안내한다.
- 함수는 소문자 스네이크케이스: `set_default`, `get_pkgmanager`, `build_win_pairs`
- 전역 변수는 대문자(`OS`, `PKG_MANAGER`, `ARCH_ALIAS`), 스크립트 상수는 소문자(`repo_dir`, `tmp_dir`)
- 함수 지역 변수는 반드시 `local`
- 변수 확장은 항상 인용: `"${HOME}"/.zshrc`
- 다운로드는 `curl -fsSL` (`-f` 없으면 404를 파일로 저장한다) + `|| exit 1`
- 설치 후 검증하고 메시지 출력:
  ```bash
  if command -v coscli &>/dev/null; then
    echo "coscli 설치가 완료되었습니다."
  else
    echo "coscli 설치에 실패했습니다."; exit 1
  fi
  ```

### zsh 설정 파일

- `zshrc_ubuntu` 와 `zshrc_mac` 은 **같은 섹션 구조를 유지한다.** 한쪽만 고치지 말 것.
- 파일 상단에 "저장소 원본을 고칠 것" 안내 주석을 유지한다.
- 디렉토리 순회는 zsh glob 한정자 `(.N)` 을 쓴다 (빈 디렉토리에서 에러 없음).

### 주석·메시지

- **주석과 사용자 출력 메시지는 한국어로 작성한다.**
- 자명하지 않은 결정에는 *이유*를 남긴다. 예:
  ```bash
  # pipx ensurepath는 사용하지 않음
  # - ensurepath는 zshrc를 직접 수정하는데, zshrc는 git으로 관리되므로 부적합
  ```

### 들여쓰기

`.editorconfig` 기준: shell 2칸, Python 4칸, YAML/JSON 2칸.
수정 시에는 해당 파일의 기존 스타일을 따르고, 파일 전체를 재정렬하지 않는다.

### 검증

시스템을 바꾸지 않고 확인하는 방법:

```bash
bash -n setEnv.sh                  # bash 문법
zsh -n zshrc_ubuntu                # zsh 문법
zsh -i -c 'type mkcd; type k'      # 로드 결과 확인
```

### 커밋

- **메시지는 한국어로 작성한다.**
- Conventional Commits 접두어를 사용한다: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`
- 제목은 한 줄로 요약하고, 변경이 여러 갈래면 본문에 `-` 목록으로 근거를 적는다.

  ```
  feat: WSL/Ubuntu Go(golang) 설치 추가

  - setEnv.sh에 set_go 추가 (공식 바이너리를 /usr/local/go에 설치, 최신 버전 자동 조회)
  - zshrc_ubuntu에 Go PATH 설정 (/usr/local/go/bin, ~/go/bin)
  - README 환경 표에 go 항목 추가
  ```

- **커밋 메시지에 Claude / AI 관련 서명을 넣지 않는다.**
  `Co-Authored-By: Claude ...`, `Generated with Claude Code` 등 어떤 형태의 흔적도 남기지 않는다.
- 개인 저장소이므로 `main` 에 직접 커밋한다. 별도 브랜치나 PR을 만들지 않는다.
- 푸시는 **사용자가 명시적으로 요청할 때만** 한다. 커밋 요청에 푸시가 포함된 것으로 해석하지 않는다.

### history.md

구조를 바꾸는 작업(파일 삭제·이동, 스크립트 동작 변경, 연동 방식 변경)을 했다면
`history.md` 최상단에 `## YYYY-MM-DD — 제목` 섹션을 추가한다.

- **왜 그렇게 했는지**를 남긴다. 무엇을 바꿨는지는 `git diff` 로 알 수 있지만 이유는 알 수 없다.
- 삭제한 파일은 삭제 이유를 함께 적는다 (나중에 "이거 왜 없지?" 를 막기 위함).
- 검증한 내용과 **검증하지 않은 내용**을 구분해서 적는다.
- alias 한두 개 추가 같은 일상적인 변경은 기록하지 않는다. `git log` 로 충분하다.

---

## 7. 남은 과제

| 항목 | 내용 |
| --- | --- |
| macOS 미검증 | `setting_mac.sh` 가 `setEnv.sh` 로 통합되지 않았다. macOS 장비를 다시 쓰게 되면 검증 후 통합할 것 |
| `alias/mac/` 부재 | macOS 전용 alias가 필요해지면 `alias/mac/` 을 만들고 `zshrc_mac` 로드 목록에 추가 |
| 사내 정보 하드코딩 | §5 경고 참조. `/etc/zsh/alias.sh` 로 옮기는 정리가 필요 |
| `config/puppet-lint.rc` | 저장소에만 있고 연동되지 않는다. 필요해지면 `~/.puppet-lint.rc` 링크 추가 |

---

## 8. Claude 작업 시 유의사항

- **파괴적 명령 주의.** 이 저장소의 스크립트는 `chsh`, `sudoers` 수정, `sudo rm -rf /usr/local/go`,
  `~/.zshrc` 덮어쓰기, Windows 설정 덮어쓰기를 실제로 수행한다.
  검증 목적으로 설치 계열(`-e go`, `-e brew`, `-e winpush`)을 임의 실행하지 말 것.
  문법 확인은 §6의 검증 명령을 쓴다.
- **심볼릭 링크를 실수로 끊지 말 것.** `~/.zshrc`, `~/alias`, `~/functions`, `~/.vimrc`,
  `~/.tmux.conf`, `~/.p10k.zsh` 는 모두 이 저장소를 가리키는 링크다.
  홈 쪽 파일을 직접 편집하는 대신 저장소 원본을 편집한다.
- **`~/.env_vars`, `/etc/zsh/alias.sh` 를 읽거나 커밋하지 않는다.**
- **`config/p10k.zsh` 를 손으로 고치지 않는다.** `p10k configure` 로 생성되는 파일이므로
  프롬프트를 바꿨으면 `cp ~/.p10k.zsh config/p10k.zsh` 가 아니라 링크가 이미 걸려 있으니 그대로 커밋하면 된다.
- **문서 동기화.** `setEnv.sh`의 옵션이나 alias/config 구조를 바꾸면 `README.md`와 이 문서를 함께 갱신한다.
- **한국어로 응답·작성한다.**
