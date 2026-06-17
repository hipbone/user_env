# user_env

새로운 PC 및 서버에서 빠르게 사용자 환경(shell, alias, vim 등)을 구성할 수 있도록 도와주는 도구 모음입니다.

macOS / Linux(WSL 포함)를 지원하며, zsh + oh-my-zsh + powerlevel10k 기반의 통합 환경을 구성합니다.

## 지원 플랫폼

| 플랫폼 | 상태 | 사용 스크립트 |
| --- | --- | --- |
| Ubuntu (Linux / WSL) | 검증 완료 | `setEnv.sh` |
| macOS | 검토 필요 | `setting_mac.sh` |
| CentOS | 검토 필요 | `set_env.sh` |

## setEnv.sh (메인 도구)

`setEnv.sh`는 인자값으로 환경 종류를 받아 다양한 개발/운영 환경을 구성하는 CLI 도구입니다. (현재 Ubuntu 기준으로 검증)

```bash
# 도움말
bash setEnv.sh -h

# 기본 환경 구성 (zsh + oh-my-zsh + powerlevel10k + 플러그인 + alias)
bash setEnv.sh -e default
```

### 지원되는 환경 (`-e` / `--env`)

| 환경 | 설명 |
| --- | --- |
| `default` | 기본 환경 구성 (zsh, oh-my-zsh, powerlevel10k 테마, 플러그인, alias 심볼릭 링크) |
| `opentofu` | OpenTofu 설치 및 구성 |
| `awscli` | AWS CLI v2 설치 |
| `brew` | Homebrew 설치 |
| `tccli` | Tencent Cloud CLI 설치 (pipx 기반 격리 환경) |
| `coscli` | Tencent Cloud COS CLI 설치 |
| `go` | Go(golang) 공식 바이너리 설치 (`/usr/local/go`) |

```bash
# 예시
bash setEnv.sh -e opentofu
bash setEnv.sh -e awscli
bash setEnv.sh -e tccli
```

`default` 실행 시 동작:

1. 패키지 업데이트 및 필수 패키지 설치 (`wget`, `curl`, `git`, `zsh`, `bat`, `unzip`)
2. 현재 사용자에 대한 `NOPASSWD` sudoers 설정
3. 로그인 셸을 zsh로 변경
4. oh-my-zsh / powerlevel10k 테마 / zsh 플러그인 설치
   (`zsh-syntax-highlighting`, `zsh-autosuggestions`)
5. `zshrc_ubuntu` → `~/.zshrc`, `alias/` → `~/alias` 심볼릭 링크 생성

> 참고: tccli는 PEP 668 문제를 피하기 위해 pipx로 설치하며, `~/.local/bin`은
> zshrc에서 조건부로 PATH에 추가됩니다 (`pipx ensurepath`를 쓰지 않음).
> 설치 후 `tccli configure` / `coscli config`로 인증 정보를 설정하세요.

## macOS

```bash
bash setting_mac.sh
```

Homebrew 기반으로 zsh, oh-my-zsh, powerlevel10k 테마, 플러그인, `bat`을 설치하고
`zshrc_mac`, `.vimrc`, `.vim`을 심볼릭 링크로 연결합니다.
(사전에 Homebrew가 설치되어 있어야 합니다.)

## CentOS / 공통 (레거시)

`set_env.sh`는 OS를 자동 감지(CentOS / macOS / Ubuntu)하여 zsh 환경을 구성하는
기존 스크립트입니다. 신규 구성은 가급적 `setEnv.sh` 사용을 권장합니다.

```bash
bash set_env.sh
```

## Vim 세팅 (Linux)

Vundle 설치 및 기본 vim 설정(`vimrc.default`, `plugin/`, `ftplugin/`)을 적용합니다.

```bash
bash set_env_linux.sh
```

## 로케일 설정 (한글 깨짐 해결)

```bash
bash set_locales.sh
```

`language-pack-ko` 설치 후 `ko_KR.UTF-8` 로케일을 생성합니다.
(`dpkg-reconfigure locales` GUI 화면에서 `ko_KR.UTF-8` 선택)

## 개인키 등 환경변수 설정

`~/.env_vars` 파일에 사용자별 환경변수를 정의합니다.
`.zshrc`에서 이 파일을 자동으로 로드하므로 사용자별 비밀값을 git으로 관리하지 않고 분리할 수 있습니다.

```bash
# ~/.env_vars 작성 후
source ~/.zshrc
```

## alias 관리

alias 파일은 `alias/` 디렉토리에서 관리되며, `~/alias`로 심볼릭 링크된 뒤
`.zshrc`에서 자동으로 로드됩니다.

```
alias/
├── default/   # 모든 환경 공통 (awscli, kubenetes, tccli)
└── ubuntu/    # Ubuntu 전용 (sudo, terraform, terragrunt, puppet, traefik, hipbone)
```

- `alias/default/*` : 모든 환경에서 로드
- `alias/ubuntu/*` : Ubuntu 환경에서 로드
- `/etc/zsh/alias.sh` : 저장소 외부의 머신 로컬 alias (있을 경우 로드)

## 기타 포함 설정

| 경로 | 설명 |
| --- | --- |
| `zshrc_ubuntu`, `zshrc_mac`, `zshrc_centos` | OS별 zsh 설정 |
| `bash_profile_mac` | macOS bash 프로필 |
| `.vimrc`, `vimrc.default`, `.vim/`, `plugin/`, `ftplugin/` | vim 설정 |
| `tmux/tmux.conf` | tmux 설정 |
| `vscode/settings.json` | VS Code 설정 |
| `wt/settings.json` | Windows Terminal 설정 |
| `.editorconfig`, `puppet-lint.rc` | 에디터/린터 설정 |
