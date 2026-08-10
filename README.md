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
| `tccli` | Tencent Cloud CLI 설치 (pipx 기반 격리 환경) |
| `coscli` | Tencent Cloud COS CLI 설치 |
| `go` | Go(golang) 공식 바이너리 설치 (`/usr/local/go`) |

`default` 실행 시 동작:

1. 패키지 업데이트 및 필수 패키지 설치 (`wget`, `curl`, `git`, `zsh`, `bat`, `unzip`)
2. 현재 사용자에 대한 `NOPASSWD` sudoers 설정
3. 로그인 셸을 zsh로 변경
4. oh-my-zsh / powerlevel10k 테마 / zsh 플러그인 설치
   (`zsh-syntax-highlighting`, `zsh-autosuggestions`)
5. `zshrc_ubuntu` → `~/.zshrc` 링크
6. `dotfiles` 링크 (아래 표 참조)

> 참고: tccli는 PEP 668 문제를 피하기 위해 pipx로 설치하며, `~/.local/bin`은
> zshrc에서 조건부로 PATH에 추가됩니다 (`pipx ensurepath`를 쓰지 않음).
> 설치 후 `tccli configure` / `coscli config`로 인증 정보를 설정하세요.

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
├── default/   # awscli, kubenetes, tccli, opshub
└── ubuntu/    # sudo, terraform, terragrunt, puppet, traefik, hipbone

functions/
└── common.zsh # mkcd, extract, path, up
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
├── functions/                    # → ~/functions
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
