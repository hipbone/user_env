# 변경 이력

구조를 크게 바꾼 작업만 상세히 기록합니다.
alias 한두 개 추가 같은 일상적인 변경은 `git log` 로 충분하므로 여기 쓰지 않습니다.

---

## 2026-08-12 — tccli 운영 구성 정비 (pipx → uv tool, helper 함수, 역할 ARN 외부화)

### 배경

tccli는 설치 스크립트만 있고 운영에 필요한 나머지가 비어 있었습니다.
프로필이 6개(`default`, `hive-live`, `hive-sandbox`, `hive-test`, `iep-rnd` 등) 있는데 전환 수단이 없었고,
자동완성도 연결되어 있지 않았으며, alias는 역할 전환 두 개뿐이었습니다.

### 설치 방식: pipx → uv tool

pipx를 apt로 깔고 그 위에 tccli를 얹는 구조였습니다. uv 도입 시점(2026-08-11)에는
"이미 있는 pipx는 tccli 전용으로 유지"하기로 했지만, 그러면 Python 도구 설치 경로가 둘로 남습니다.

`uv tool install tccli` 로 통일했습니다.

- uv가 자체 Python을 쓰므로 시스템 `python3` 나 PEP 668과 무관해집니다 (pipx를 쓴 원래 이유가 사라짐).
- 관리 대상이 하나 줄고, 갱신도 `uv tool upgrade tccli` 로 uv 체계 안에서 처리됩니다.
- `set_tccli` 는 pipx로 설치된 기존 tccli를 감지하면 제거한 뒤 이전합니다.
  `~/.local/bin/tccli` 가 pipx 링크로 남아 있으면 `uv tool install` 이 실패하기 때문입니다.
- uv가 없으면 `set_uv` 를 먼저 호출합니다.

### 역할 ARN을 저장소 밖으로

`alias/default/tccli.alias` 의 `tc-hive-test` / `tc-hive-sandbox` 에 Tencent 계정 UIN이 박혀 있었습니다
(CLAUDE.md §7의 "사내 정보 하드코딩" 과제). ARN을 `~/.env_vars` 의 `TC_ROLE_<대문자별칭>` 으로 옮기고,
`tc-assume` 이 별칭을 그 환경변수로 해석하도록 했습니다. 기존 alias 두 개는 `tc-assume` 호출로 남겨
이름은 그대로 쓸 수 있게 했습니다.

**주의**: `~/.env_vars` 에 `TC_ROLE_HIVE_TEST` / `TC_ROLE_HIVE_SANDBOX` 를 정의하기 전까지
두 alias는 "역할 별칭을 찾을 수 없습니다" 안내를 출력합니다. 이전 ARN 값은 `git log -p` 로 확인할 수 있습니다.

### 자격증명 우선순위 (조사 결과)

tccli 3.1.39 소스(`services/*/[service]_client.py` 의 `parse_global_arg`)를 확인한 결과:

1. 명령에 `--profile` 을 직접 붙이면 그 프로필 파일만 사용 (환경변수 무시)
2. 그렇지 않고 `TENCENTCLOUD_SECRET_ID/KEY` 가 있으면 그것이 우선 — `TCCLI_PROFILE` 보다 위
3. 나머지는 `TCCLI_PROFILE`(기본 `default`) 프로필 파일

즉 `~/.env_vars` 에 정적 키가 export되어 있으면 프로필을 바꿔도 키는 바뀌지 않습니다.
이 함정 때문에 helper를 다음과 같이 설계했습니다.

- `tc-assume` 은 `--profile` 을 명시해 호출한다 (환경변수에 남은 키가 끼어들지 않도록).
- `tc-assume` 은 원래 있던 정적 키를 보관하고, `tc-unassume` 이 그것을 복구한다.
  `tc-unassume` 은 `tc-assume` 으로 전환한 경우에만 동작한다 — 그렇지 않으면 `~/.env_vars` 의
  정적 키를 실수로 날리게 된다.
- `tc-use` 는 정적 키가 남아 있으면 경고한다. `tc-env` 는 지금 실제로 무엇이 쓰이는지 표시한다.

### 그 외

- 자동완성: tccli는 zsh 완성 스크립트 없이 `tccli_completer`(bash 형식)만 제공하므로
  `~/.zfunc` 방식이 통하지 않습니다. `zshrc_ubuntu` / `zshrc_mac` 의 자동완성 섹션에서
  `bashcompinit` + `complete -C` 로 조건부 연결했습니다.
- `requirement_package` 에 `jq` 추가 — `tc-assume` 이 AssumeRole 응답 파싱에 씁니다.
- `alias/default/coscli.alias` 신규 (`cos-` 접두어).
- `zshrc_mac` 에 PATH 섹션 추가 — `~/.local/bin` 이 없어 uv/tccli가 잡히지 않는 상태였습니다.
- alias의 조회 명령은 `--filter`(JMESPath)로 컬럼을 추린 형태로 작성했습니다.
  응답 필드명은 SDK 모델(`tencentcloud/{cvm,vpc,clb}/v*/models.py`)에서 확인했습니다.

### 검증한 것 / 안 한 것

- 검증: `bash -n setEnv.sh`, `zsh -n` (zshrc 2종, tencent.zsh, alias 2종),
  `tc-profiles` / `tc-use` / `tc-env` / `tc-unassume` 실제 실행,
  `tc-assume` 은 tccli를 가짜 응답으로 대체해 파싱·복구·실패 경로 확인
- **검증 안 함**: `bash setEnv.sh -e tccli` 실제 실행(pipx → uv tool 이전),
  실제 API를 호출하는 `tc-assume` / 조회 alias, tccli 자동완성 동작, macOS 전반

## 2026-08-11 — Python 환경 관리 추가 (uv)

### 배경

Python 환경 관리 수단이 저장소에 전혀 없었습니다. 시스템 `python3`(apt 3.12.3)와
tccli 설치용 pipx만 있는 상태여서, 새 장비에서 Python 작업을 시작하려면 매번 수동 구성이 필요했습니다.

도구는 **uv**로 정했습니다. 버전 관리(pyenv) + 가상환경(venv) + 의존성(pip/poetry) +
일회성 도구 실행(pipx)을 하나로 대체할 수 있어, 관리 대상을 늘리지 않고 기능을 얻을 수 있습니다.

### 추가한 것

**`setEnv.sh -e uv`** — `set_uv()` 신규

1. uv / uvx 설치 (`~/.local/bin`). 이미 있으면 `uv self update` 로 갱신
2. zsh 자동완성 생성 → `~/.zfunc/_uv`, `~/.zfunc/_uvx`
   (`zshrc_ubuntu` 가 이미 `fpath+=~/.zfunc` 를 하고 있어 별도 설정 불필요.
   기존 `_ops-hub` 자동완성과 같은 방식)
3. uv가 관리하는 최신 Python 설치 (`uv python install`)

**핵심 결정 — 설치 스크립트의 셸 프로필 수정 차단**

uv 설치 스크립트는 기본적으로 `~/.zshrc` 에 PATH 줄을 직접 추가합니다.
`zshrc_ubuntu` 는 git으로 관리되는 심볼릭 링크 원본이므로 그대로 두면 저장소와 실제 설정이 갈라집니다.
`INSTALLER_NO_MODIFY_PATH=1` 로 막고, `~/.local/bin` 은 기존처럼 zshrc에서 조건부로 추가합니다.
tccli 설치 때 `pipx ensurepath` 를 쓰지 않은 것과 같은 이유이며, 이 방침을 `CLAUDE.md` 에
"언어 런타임 관리 방침" 으로 명문화했습니다.

**`alias/default/uv.alias`** — `command -v uv` 가드 안에 정의
`uvi`, `uvs`, `uvr`, `uva`, `uvad`, `uvrm`, `uvl`, `uvtree`, `uvpy`, `uvpyi`, `uvv`, `uvt`, `uvtl`

**`functions/python.zsh`** — 셸에서 직접 `python`/`pytest` 를 써야 할 때를 위한 helper

| 함수 | 설명 |
| --- | --- |
| `uvon` | 상위 경로를 거슬러 올라가며 `.venv` 를 찾아 활성화 |
| `uvoff` | 비활성화 (활성 환경이 없으면 그렇다고 알림) |
| `uvinfo` | uv 버전 / 활성 가상환경 / python 경로·버전 / 프로젝트 위치 |

평소에는 `uv run` 이 활성화 없이 동작하므로 그쪽이 낫습니다. helper는 보조 수단입니다.

### 방침

- **Python은 uv로 통일합니다.** pyenv, poetry, virtualenv 를 새로 들이지 않습니다.
- 기존 pipx 는 tccli 설치 전용으로만 유지합니다 (제거하지 않음).
- 시스템 `python3`(apt)는 건드리지 않습니다. OS 도구들이 의존하고 있습니다.
  uv가 설치하는 Python은 `~/.local/share/uv/python/` 아래에 격리됩니다.

### 검증 내역

- `bash setEnv.sh -e uv` **실제 실행** — uv 0.12.3 설치, CPython 3.14.7 설치, 자동완성 2개 생성 확인
- **셸 프로필 오염 없음 확인** — `git diff zshrc_ubuntu` 변화 없음,
  `~/.profile` 은 2024-08-20 mtime 그대로(Ubuntu 기본 `~/.local/bin` 블록이며 uv 흔적 없음)
- 실제 프로젝트로 `uv init` → `uv add requests` → `uvon` → `uvinfo` → `uvoff` 전 과정 확인
- alias 로드 확인 (`uvs`, `uva`, `uvpy`)

**작업 중 발견해 수정한 것**

- `uvinfo` 가 `python` 없이 `python3` 만 있는 장비에서 `command not found` 를 출력에 섞어 찍었습니다.
  `command -v` 로 먼저 찾은 뒤 그 경로로 `--version` 을 호출하도록 수정했습니다.
- `functions/common.zsh` 의 `up` 이 실패 메시지를 stdout으로 보내고 있어
  명령 치환으로 값을 받는 쪽이 오염됐습니다. stderr로 변경했습니다.

---

## 2026-08-10 — 저장소 구조 전면 정리

### 배경

프로젝트 목적을 다시 정리하면서(개인 작업 환경을 여러 장비에 빠르고 동일하게 재현) 현재 구조를
점검한 결과, 2019~2021년 macOS 시절 잔재가 상당량 남아 있고 목적 대비 빠진 부분이 있었습니다.
설계 원칙을 `CLAUDE.md` 로 문서화하면서 함께 정리했습니다.

### 1. 삭제한 파일

| 대상 | 삭제 이유 |
| --- | --- |
| `.vim/` 전체 | `.gitmodules` 없이 gitlink(mode 160000)만 8개 남아 있어 clone하면 빈 디렉토리만 생성됨. `.vim/.vim/.vim` 은 `/Users/hipbone/git_repo/user_env/.vim` 를 가리키는 깨진 심볼릭 링크(2021년 macOS 경로). `.netrwhist` 2개는 netrw 캐시로 애초에 커밋 대상이 아님 |
| `set_env.sh` | Ubuntu 경로는 `setEnv.sh` 로 대체 완료. 남은 CentOS/macOS 경로에 실제 버그가 있어 실행 자체가 불가능한 상태였음 — `yum install -y zshset_env.sh`(오타), `Yes \|`(대문자), `~/User_env`(대소문자 불일치), `brew install -y`(brew에 없는 플래그) |
| `zshrc_centos` | CentOS 미사용 (2020년 이후 변경 없음) |
| `bash_profile_mac` | bash 미사용 (2019년 이후 변경 없음) |
| `set_env_linux.sh` | Vundle 설치 스크립트. vim 플러그인 스택을 걷어내면서 함께 제거 |
| `vimrc.default` | `.vimrc` 와 내용이 갈라진 채 방치(플러그인 목록이 서로 달랐음). 하나로 통합 |
| `plugin/python_autopep8.vim`, `ftplugin/python.vim` | Vundle 스택 부속 파일 |
| `setEnv.sh` 의 `production)` 분기 | 내용 없는 stub |

> 모두 git 이력에 남아 있으므로 필요하면 복원 가능합니다.
> 예: `git show <이 커밋>^:set_env.sh > set_env.sh`

### 2. 디렉토리 재편

루트에 흩어져 있던 설정 파일을 `config/` 로 모았습니다.
`zshrc_ubuntu` 와 `alias/` 는 홈의 심볼릭 링크가 이미 가리키고 있어 **일부러 옮기지 않았습니다.**

| 이전 | 이후 |
| --- | --- |
| `tmux/tmux.conf` | `config/tmux.conf` |
| `vscode/settings.json` | `config/vscode-settings.json` |
| `wt/settings.json` | `config/wt-settings.json` |
| `puppet-lint.rc` | `config/puppet-lint.rc` |
| `.vimrc` | `config/vimrc` |
| (신규) | `config/p10k.zsh` |
| (신규) | `functions/common.zsh` |

`tmux/`, `vscode/`, `wt/`, `plugin/`, `ftplugin/`, `obsidian/`(빈 디렉토리) 는 제거되었습니다.

일부 파일(`puppet-lint.rc`, `tmux.conf`, `vscode-settings.json`)이 root 소유였던 것도
`hipbone` 소유로 정정했습니다. (sudo로 만들어졌던 것으로 보임)

### 3. p10k 설정을 저장소로 편입 — **가장 실질적인 개선**

기존에는 `~/.p10k.zsh`(95KB)가 버전 관리 밖에 있었습니다.
새 장비마다 `p10k configure` 를 다시 돌려야 했고 결과가 장비마다 달라졌습니다.
"어느 장비에서든 동일한 환경" 이라는 목적에 정면으로 어긋나는 부분이라 저장소로 가져왔습니다.

- `~/.p10k.zsh` → `config/p10k.zsh` 로 복사 후, `~/.p10k.zsh` 를 저장소로 향하는 심볼릭 링크로 교체
- 원본은 `~/.p10k.zsh.bak` 으로 백업 (내용 동일함을 diff로 확인)
- 토큰·경로 등 민감정보가 없는지 스캔 완료 (일반 주석만 존재)

이제 프롬프트를 바꾸면 `p10k configure` 실행 결과가 저장소 파일에 바로 반영되므로,
`git diff` 로 확인하고 커밋하면 다른 장비에도 그대로 전파됩니다.

### 4. 설정 파일 연동 방식 도입

이전에는 `tmux/`, `vscode/`, `wt/` 가 저장소에 파일만 있고 **어떤 스크립트도 연결하지 않았습니다.**
(실제 `~/.tmux.conf` 는 저장소와 무관한 16바이트 파일이었음)

두 갈래로 구현했습니다.

**(a) 심볼릭 링크 — Linux / macOS**

`setEnv.sh -e dotfiles` 로 아래를 연결합니다. 기존 실제 파일은 `.bak` 으로 백업됩니다.

```
alias/            → ~/alias
functions/        → ~/functions
config/tmux.conf  → ~/.tmux.conf
config/vimrc      → ~/.vimrc
config/p10k.zsh   → ~/.p10k.zsh
```

디렉토리 링크에는 `ln -fsn` 을 씁니다. `-n` 이 없으면 이미 링크가 있을 때
그 **안쪽에** 중첩 생성되는 문제가 있습니다(작업 중 실제로 발생하여 수정).

**(b) 복사 동기화 — Windows**

Windows 파일시스템(drvfs)에는 WSL 심볼릭 링크가 통하지 않습니다.
Windows Terminal이나 VS Code(Windows 앱)가 WSL 링크를 따라가지 못하므로 **복사**로 동기화합니다.

```bash
bash setEnv.sh -e winpush   # 저장소 → Windows (기존 설정은 .bak 백업)
bash setEnv.sh -e winpull   # Windows → 저장소 (GUI에서 바꾼 설정 회수)
```

- `%USERPROFILE%` 은 `cmd.exe /c echo %USERPROFILE%` + `wslpath` 로 조회하고,
  실패하면 `/mnt/c/Users/$(whoami)` 로 대체
- 대상: `AppData/Roaming/Code/User/settings.json`,
  `AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`
- 각 대상의 부모 디렉토리가 없으면(미설치) 건너뜁니다

### 5. setEnv.sh 버그 수정 (v1.3 → v2.0)

| 문제 | 수정 |
| --- | --- |
| `is_linux()` 가 성공 시 `exit 0` 을 호출 | `return 0/1` 로 변경. 호출부도 `if $(is_linux)`(서브셸) → `is_linux && ...` 로 정정. 기존 코드는 서브셸 안이라 우연히 동작하던 것 |
| `requirement_package` 가 항상 실행 | `set_default` 안으로 이동. `-e go` 처럼 셸 세팅과 무관한 작업에서 apt 갱신을 강요하지 않음 |
| `${PWD}` 의존 (저장소 루트에서만 실행 가능) | `repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` 로 변경. 어느 디렉토리에서 실행해도 동작 |
| `cd $tmp_dir` 후 `rm -rf ../$tmp_dir` | `cd` 없이 절대 경로로만 처리. `tmp_dir` 도 `${repo_dir}/tmp` 로 고정 |
| `curl` 에 `-f` 누락 | 전부 `curl -fsSL ... \|\| exit 1`. `-f` 가 없으면 404 응답 본문을 파일로 저장함 |
| `x86_64`/`aarch64` 분기가 `set_coscli`, `set_go` 에 중복 | `get_arch()` → `ARCH_ALIAS` 로 통합 |
| `set_awscli` 재실행 시 실패 | `./aws/install --update` 로 변경 + 설치 후 `command -v` 검증 추가 |
| 홈 파일을 백업 없이 덮어씀 | `backup_if_real_file()` 추가 (심볼릭 링크는 그냥 교체, 실제 파일만 `.bak`) |

`print_help` 도 카테고리(셸 환경 / Windows 연동 / 도구 설치)로 재구성했습니다.

### 6. zshrc 정리

**`zshrc_ubuntu`**

- `eval "$(direnv hook zsh)"` 가 무조건 실행되어 direnv 미설치 장비에서 셸 시작마다 에러가 나던 것을
  `command -v direnv` 가드로 감쌌습니다 (설계 원칙 "조건부 로드" 위반이었음)
- `~/functions/*` 로드 추가
- alias 로드 루프를 zsh glob 한정자 `(.N)` 기반으로 통합 (빈 디렉토리에서도 에러 없음)
- 섹션 주석으로 구조화 (oh-my-zsh / 환경변수 / alias·functions / 로케일 / 개발 도구 / PATH / 자동완성)
- 파일 상단에 "홈이 아니라 저장소 원본을 고칠 것" 안내 추가

**`zshrc_mac`**

- `export ZSH="/Users/hipbone/.oh-my-zsh"` 하드코딩 → `$HOME/.oh-my-zsh`
- **alias를 아예 로드하지 않던 문제 수정.** `alias/default/*` 와 `functions/*` 를 로드합니다
  (`alias/ubuntu/*` 는 제외)
- `~/.env_vars` 로드 추가
- `zshrc_ubuntu` 와 같은 섹션 구조로 맞춤

### 7. 신규 — functions/

alias로 표현하기 어려운(인자 처리·분기가 필요한) 것을 담을 자리를 만들었습니다.
`functions/common.zsh` 에 `mkcd`, `extract`, `path`, `up` 을 넣었습니다.

판단 기준: 한 줄 치환이면 `alias/`, 그 이상이면 `functions/`.

### 8. 기타

- `config/vimrc` 를 플러그인 매니저 없는 최소 설정으로 재작성.
  2019년 스택(Vundle, neocomplcache, solarized)을 되살리는 대신,
  "서버에서 잠깐 고칠 때 필요한 것만" 담는 방향으로 정리 (어떤 장비에 떨궈도 그대로 동작)
- `.gitignore`: 의미 없어진 `.vim/bundle/*` → `tmp/`, `*.bak`, `*.dist`
- `.editorconfig`: `*.sh` 의 `indent_size` 가 4인데 주석은 "2칸"이라고 적혀 있었음.
  실제 코드가 2칸이므로 값을 2로 정정
- `setting_mac.sh`: 사라진 `.vimrc`/`.vim` 참조 제거, `config/` 기준으로 갱신,
  `alias`/`functions`/`tmux.conf`/`p10k.zsh` 링크 추가

### 9. 문서

- `CLAUDE.md` 신규 작성 — 프로젝트 목적, 설계 원칙 6가지, 저장소 구조,
  확장 체크리스트, alias/functions 규칙, 코딩 규칙, 커밋 규칙, 남은 과제
- `README.md` 전면 갱신 — 새 구조, 연동 방식(링크 vs 복사) 반영
- `history.md` 신규 (이 문서)

### 검증 내역

- `bash -n` / `zsh -n` — 전 스크립트 통과
- `setEnv.sh -e dotfiles` 실제 실행 — 링크 6개 정상 생성, 재실행 멱등성 확인
- `zsh -i` — `mkcd`/`up` 함수, `oh`/`k` alias 로드 및 PATH(go, tccli, aws) 정상 확인
- Windows 경로 탐지 — 복사 없이 경로 해석만 확인 (VS Code, Terminal 둘 다 실제 경로 존재)
- `config/p10k.zsh` 와 `~/.p10k.zsh.bak` 내용 동일 확인

**미실행**: 시스템을 실제로 바꾸는 `-e go`, `-e brew`, `-e awscli`, `-e winpush` 는 실행하지 않았습니다.
특히 `winpush` 는 Windows 설정을 덮어쓰므로 직접 확인 후 실행하시기 바랍니다(기존 설정은 `.bak` 백업됨).

### 남은 과제

- `setting_mac.sh` 미검증. macOS 장비를 다시 쓰게 되면 검증 후 `setEnv.sh` 로 통합할 것
- `alias/ubuntu/{puppet,traefik,hipbone}.alias` 의 사내 서버 IP·계정명,
  `alias/default/tccli.alias` 의 Tencent 계정 UIN이 저장소에 그대로 있음.
  `/etc/zsh/alias.sh`(git 미관리) 로 옮기는 정리 필요
- `config/puppet-lint.rc` 는 저장소에만 있고 연동되지 않음
