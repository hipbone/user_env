# user_env

새로운 PC 및 서버에서 빠르게 사용자 환경(shell, alias, vim 등)을 구성할 수 있도록 도와주는 도구 모음입니다.

macOS / Linux(WSL 포함)를 지원하며, zsh + oh-my-zsh + powerlevel10k 기반의 통합 환경을 구성합니다.

**저장소가 원본(Single Source of Truth)이고, 홈 디렉토리에는 심볼릭 링크만 겁니다.**
설정을 바꿀 때는 홈의 `~/.zshrc` 가 아니라 저장소 파일을 고치고 커밋하세요.

## 빠른 시작

```bash
git clone <이 저장소> ~/src/github/user_env
cd ~/src/github/user_env

bash setEnv.sh -e default     # zsh 환경 + 홈 심볼릭 링크까지 한 번에
```

WSL이라면 Windows 쪽 설정도 배포합니다.

```bash
bash setEnv.sh -e winpush     # VS Code / Windows Terminal 설정 배포
```

## 지원 플랫폼

| 플랫폼 | 상태 | 사용 스크립트 |
| --- | --- | --- |
| Ubuntu (Linux / WSL) | 검증 완료 | `setEnv.sh` |
| Windows (WSL 경유) | 부분 지원 — `winpush` / `winpull` | `setEnv.sh` |
| macOS | 검토 필요 | `setting_mac.sh` |

## setEnv.sh

`setEnv.sh`는 인자값으로 환경 종류를 받아 다양한 개발/운영 환경을 구성하는 CLI 도구입니다.
스크립트 위치를 기준으로 동작하므로 어느 디렉토리에서 실행해도 됩니다.

```bash
bash setEnv.sh -h             # 도움말
```

### 지원되는 환경 (`-e` / `--env`)

**셸 환경**

| 환경 | 설명 |
| --- | --- |
| `default` | 기본 환경 구성 (zsh, oh-my-zsh, powerlevel10k, 플러그인, 홈 심볼릭 링크) |
| `dotfiles` | 설정 파일만 홈에 다시 링크 (alias, functions, tmux, vim, p10k) |

**Windows 연동 (WSL 전용)**

| 환경 | 설명 |
| --- | --- |
| `winpush` | 저장소 설정을 Windows에 배포 (VS Code, Windows Terminal) |
| `winpull` | Windows 설정을 저장소로 회수 |

**도구 설치**

| 환경 | 설명 |
| --- | --- |
| `opentofu` | OpenTofu 설치 및 구성 |
| `awscli` | AWS CLI v2 설치 |
| `brew` | Homebrew 설치 |
| `tccli` | Tencent Cloud CLI 설치 (uv tool 기반 격리 환경) |
| `coscli` | Tencent Cloud COS CLI 설치 |
| `go` | Go(golang) 공식 바이너리 설치 (`/usr/local/go`) |
| `uv` | uv 설치 + zsh 자동완성 + 최신 Python 설치 |

`default` 실행 시 동작:

1. 패키지 업데이트 및 필수 패키지 설치 (`wget`, `curl`, `git`, `zsh`, `bat`, `unzip`, `jq`)
2. 현재 사용자에 대한 `NOPASSWD` sudoers 설정
3. 로그인 셸을 zsh로 변경
4. oh-my-zsh / powerlevel10k 테마 / zsh 플러그인 설치
   (`zsh-syntax-highlighting`, `zsh-autosuggestions`)
5. `zshrc_ubuntu` → `~/.zshrc` 링크
6. `dotfiles` 링크 (아래 표 참조)

> 참고: Python으로 만들어진 CLI(tccli)는 **uv tool** 로 격리 설치합니다. uv가 자체 Python을
> 쓰므로 시스템 `python3` / PEP 668 문제와 무관합니다. `~/.local/bin` 은 zshrc에서 조건부로
> PATH에 추가됩니다. 설치 후 `tccli configure` / `coscli config`로 인증 정보를 설정하세요.

## Python 환경 (uv)

Python 버전 관리, 가상환경, 의존성 관리를 [uv](https://docs.astral.sh/uv/) 하나로 처리합니다.
시스템 `python3`(apt)는 건드리지 않으며, uv가 관리하는 Python은 `~/.local/share/uv` 아래에 격리됩니다.

```bash
bash setEnv.sh -e uv
```

설치 시 함께 처리되는 것:

1. uv / uvx 설치 (`~/.local/bin`)
2. zsh 자동완성 생성 (`~/.zfunc/_uv`, `~/.zfunc/_uvx`)
3. uv가 관리하는 최신 Python 설치

이미 설치되어 있으면 `uv self update` 로 갱신합니다.

### 기본 사용

```bash
uv init myproject      # 새 프로젝트
uv add requests        # 의존성 추가
uv sync                # pyproject.toml/uv.lock 기준 환경 동기화
uv run python main.py  # 활성화 없이 프로젝트 환경에서 실행
uvx ruff check         # 설치 없이 일회성 도구 실행
uv python install 3.12 # 특정 Python 버전 설치
```

### 기존 venv 방식에서 옮기기

기존에 쓰던 방식을 그대로 유지하려면 명령어만 1:1로 바꾸면 됩니다.

| 기존 | uv |
| --- | --- |
| `python3.12 -m venv venv` | `uv venv --python 3.12` |
| `source venv/bin/activate` | `source .venv/bin/activate` |
| `pip install -r requirements.txt` | `uv pip install -r requirements.txt` |
| `pip install requests` | `uv pip install requests` |
| `pip freeze > requirements.txt` | `uv pip freeze > requirements.txt` |

주의할 점:

- **가상환경 디렉토리 이름이 `.venv` 가 기본입니다.** `uv venv venv` 로 옛 이름을 쓸 수도 있지만
  `.venv` 를 권장합니다. `uv run`, `uv pip`, `uvon` 이 모두 `.venv` 를 자동으로 찾습니다.
- **없는 Python 버전을 지정해도 uv가 자동으로 받아옵니다.** `uv venv --python 3.11` 을 하면
  시스템에 3.11이 없어도 uv가 내려받아 사용합니다. apt로 미리 설치해 둘 필요가 없습니다.
- **활성화가 사실상 필요 없습니다.** `uv pip install` 과 `uv run` 은 현재 디렉토리의 `.venv` 를
  자동으로 인식합니다.

  ```bash
  uv venv                              # 만들고
  uv pip install -r requirements.txt   # activate 없이 설치
  uv run python main.py                # activate 없이 실행
  ```

### 프로젝트 방식으로 전환 (권장)

본인이 관리하는 프로젝트라면 `requirements.txt` 대신 `pyproject.toml` + `uv.lock` 을 쓰는 편이 낫습니다.
`uv.lock` 은 전이 의존성까지 해시로 고정하므로, `requirements.txt` 의 `requests>=2.31` 처럼
장비마다 다른 버전이 깔리는 일이 없습니다.

```bash
# 기존 requirements.txt 를 옮기기
uv init .
uv add -r requirements.txt      # pyproject.toml + uv.lock 생성
rm requirements.txt

# 이후 사용
uv add requests                 # 의존성 추가
uv add --dev pytest ruff        # 개발 의존성
uv run python main.py           # 활성화 없이 실행
```

다른 장비에서 환경을 재현할 때는 한 줄이면 됩니다.
`uv sync` 가 가상환경 생성, Python 버전 확보, 의존성 설치를 모두 처리합니다.

```bash
uv sync
```

| 상황 | 권장 방식 |
| --- | --- |
| 남의 저장소, 스크립트 몇 개, 임시 환경 | 기존 방식 유지 (`uv venv` + `uv pip`) |
| 본인이 관리하고 여러 장비에서 재현해야 하는 프로젝트 | 프로젝트 방식 (`uv init` + `uv sync`) |

### helper 함수

셸에서 직접 `python` / `pytest` 를 두드려야 할 때만 씁니다. 평소에는 `uv run` 이 낫습니다.

| 함수 | 설명 |
| --- | --- |
| `uvon` | 상위 경로에서 `.venv` 를 찾아 활성화 |
| `uvoff` | 비활성화 |
| `uvinfo` | uv 버전, 활성 가상환경, python 경로·버전, 프로젝트 위치를 한눈에 |

alias는 `alias/default/uv.alias` 를 참고하세요 (`uvs`, `uva`, `uvr`, `uvpy` 등).

> uv 설치 스크립트는 기본적으로 `~/.zshrc` 에 PATH를 직접 추가하는데,
> zshrc는 git으로 관리되므로 `INSTALLER_NO_MODIFY_PATH=1` 로 이를 막습니다.
> `~/.local/bin` 은 zshrc에서 조건부로 PATH에 추가됩니다 (uv tool로 설치한 tccli도 같은 경로).

## Tencent Cloud 환경 (tccli)

```bash
bash setEnv.sh -e tccli     # uv tool 로 tccli 설치 (uv가 없으면 함께 설치)
bash setEnv.sh -e coscli    # COS 전용 CLI
```

설치 시 함께 처리되는 것:

1. `uv tool install tccli` — `~/.local/bin` 에 `tccli`, `tccli_completer` 노출
2. 과거 pipx로 설치한 tccli가 있으면 제거하고 uv tool 로 이전
3. zsh 자동완성 — tccli는 bash 형식 completer만 제공하므로 zshrc가 `bashcompinit` 로 연결

### 프로필 / 역할 전환 helper (`functions/tencent.zsh`)

| 함수 | 설명 |
| --- | --- |
| `tc-profiles` | `~/.tccli` 에 설정된 프로필 목록 (현재 프로필은 `*`) |
| `tc-use <프로필>` | 사용할 프로필 전환 (`TCCLI_PROFILE`), 인자 없으면 현재 프로필 |
| `tc-assume <별칭>` | AssumeRole 후 임시 자격증명을 `TENCENTCLOUD_*` 로 export |
| `tc-unassume` | 역할 전환 해제 + 원래 환경변수 자격증명 복구 |
| `tc-env` | 프로필·리전·지금 쓰이는 자격증명·역할 만료까지 남은 시간 |

역할 ARN에는 조직 UIN이 들어가므로 저장소에 두지 않고 `~/.env_vars` 에 별칭으로 정의합니다.

```bash
# ~/.env_vars
export TC_ROLE_HIVE_SANDBOX="qcs::cam::uin/<UIN>:roleName/<역할이름>"
export TC_ROLE_HIVE_TEST="qcs::cam::uin/<UIN>:roleName/<역할이름>"
```

```bash
tc-assume hive-sandbox        # = tc-hive-sandbox
tc-env                        # 만료까지 남은 시간 확인
tc-unassume                   # 원래 상태로 복귀
```

> **자격증명 우선순위 주의** (tccli 3.1.x)
> `--profile` 을 직접 붙인 명령 > `TENCENTCLOUD_SECRET_ID/KEY` 환경변수 > `TCCLI_PROFILE` 프로필 파일.
> 즉 `~/.env_vars` 에 정적 키가 export되어 있으면 `tc-use` 로 프로필만 바꿔도 키는 바뀌지 않습니다.
> 지금 무엇이 쓰이는지는 `tc-env` 가 알려줍니다.

조회 alias는 `alias/default/tccli.alias` 를 참고하세요 (`tc-cvm`, `tc-vpc`, `tc-clb`, `tc-regions` 등).

## 설정 파일 연동 방식

### 심볼릭 링크 (Linux / macOS)

`setEnv.sh -e dotfiles` 가 다음을 연결합니다. 기존 파일은 `.bak`으로 백업됩니다.

| 저장소 | 홈 |
| --- | --- |
| `zshrc_ubuntu` | `~/.zshrc` |
| `alias/` | `~/alias` |
| `functions/` | `~/functions` |
| `config/tmux.conf` | `~/.tmux.conf` |
| `config/vimrc` | `~/.vimrc` |
| `config/p10k.zsh` | `~/.p10k.zsh` |

### 복사 동기화 (Windows)

Windows 파일시스템에는 WSL 심볼릭 링크가 통하지 않으므로 **복사**로 동기화합니다.

| 저장소 | Windows |
| --- | --- |
| `config/vscode-settings.json` | `%USERPROFILE%\AppData\Roaming\Code\User\settings.json` |
| `config/wt-settings.json` | `%USERPROFILE%\AppData\Local\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json` |

```bash
bash setEnv.sh -e winpush    # 저장소 → Windows (기존 설정은 .bak 백업)
bash setEnv.sh -e winpull    # Windows → 저장소 (변경 후 git diff로 확인)
```

GUI에서 VS Code나 Windows Terminal 설정을 바꿨다면 `winpull` 로 회수한 뒤 커밋하세요.

## alias / functions 관리

`.zshrc`가 다음 순서로 로드합니다.

1. `~/alias/default/*` — 모든 환경 공통
2. `~/alias/ubuntu/*` — Ubuntu 전용 (macOS에서는 로드하지 않음)
3. `~/functions/*` — helper 함수
4. `/etc/zsh/alias.sh` — 저장소 밖의 머신 로컬 alias (있을 경우)

```
alias/
├── default/   # awscli, kubenetes, tccli, coscli, uv, opshub
└── ubuntu/    # sudo, terraform, terragrunt, puppet, traefik, hipbone

functions/
├── common.zsh  # mkcd, extract, path, up
├── python.zsh  # uvon, uvoff, uvinfo
└── tencent.zsh # tc-profiles, tc-use, tc-assume, tc-unassume, tc-env
```

- 한 줄 치환이면 `alias/`, 인자 처리나 분기가 필요하면 `functions/`
- 사내 서버 IP·계정처럼 공유하면 안 되는 것은 `/etc/zsh/alias.sh` (git 미관리)

## 개인키 등 환경변수 설정

`~/.env_vars` 파일에 사용자별 환경변수를 정의합니다.
`.zshrc`에서 이 파일을 자동으로 로드하므로 사용자별 비밀값을 git으로 관리하지 않고 분리할 수 있습니다.

```bash
# ~/.env_vars 작성 후
source ~/.zshrc
```

예: Tencent Cloud 역할 전환용 ARN (조직 UIN이 들어가므로 저장소에 두지 않습니다)

```bash
export TC_ROLE_HIVE_SANDBOX="qcs::cam::uin/<UIN>:roleName/<역할이름>"
```

## macOS

```bash
bash setting_mac.sh
```

Homebrew 기반으로 zsh, oh-my-zsh, powerlevel10k 테마, 플러그인, `bat`을 설치하고
`zshrc_mac` 및 `config/` 의 설정들을 심볼릭 링크로 연결합니다.
(사전에 Homebrew가 설치되어 있어야 합니다. 현재 미검증 상태입니다.)

## 로케일 설정 (한글 깨짐 해결)

```bash
bash set_locales.sh
```

`language-pack-ko` 설치 후 `ko_KR.UTF-8` 로케일을 생성합니다.
(`dpkg-reconfigure locales` GUI 화면에서 `ko_KR.UTF-8` 선택)

## 저장소 구조

```
user_env/
├── setEnv.sh                     # 메인 진입점
├── setting_mac.sh                # macOS 구성 (미검증)
├── set_locales.sh                # ko_KR.UTF-8 로케일
│
├── zshrc_ubuntu                  # → ~/.zshrc (Ubuntu / WSL)
├── zshrc_mac                     # → ~/.zshrc (macOS)
│
├── alias/                        # → ~/alias
│   ├── default/
│   └── ubuntu/
├── functions/                    # → ~/functions (common, python, tencent)
│
├── config/
│   ├── p10k.zsh                  # → ~/.p10k.zsh
│   ├── tmux.conf                 # → ~/.tmux.conf
│   ├── vimrc                     # → ~/.vimrc
│   ├── vscode-settings.json      # → Windows (복사)
│   ├── wt-settings.json          # → Windows (복사)
│   └── puppet-lint.rc            # 참고용
│
├── .editorconfig
├── README.md
├── history.md                    # 구조 변경 이력
└── CLAUDE.md                     # 설계 원칙 및 작업 지침
```
