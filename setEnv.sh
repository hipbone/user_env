#!/bin/bash

######################################################################
# Script Name  : setEnv.sh                                           #
# Description  : 개발 및 운영 환경을 구성하기 위한 스크립트          #
# Author       : hipbone                                             #
# Created Date : 2024-01-09                                          #
# Last Update  : 2026-11-12                                          #
# Version      : 2.7                                                 #
######################################################################

###################### 1. 변수 선언 - Start ##########################
## 스크립트 이름
script_name=$(basename "$0")
## 저장소 루트 (스크립트 위치 기준 - 어디서 실행해도 동작)
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
## 임시 디렉토리
tmp_dir="${repo_dir}/tmp"
## Windows Terminal 패키지 디렉토리 이름
wt_package="Microsoft.WindowsTerminal_8wekyb3d8bbwe"
###################### 1. 변수 선언 - End ############################

####################### 2. 함수 선언 - Start #########################
## 도움말 출력 함수
print_help() {
  echo "Usage: $script_name -e|--env ENVIRONMENT"
  echo "개발 및 운영 환경 구성 도구"
  echo ""
  echo "Options:"
  echo "  -h, --help                    도움말 보기"
  echo "  -e, --env ENVIRONMENT         세팅할 환경"
  echo ""
  echo ""
  echo "지원되는 ENVIRONMENT"
  echo "  [셸 환경]"
  echo "    default                     기본 환경을 구성(zsh, oh-my-zsh, alias, functions)"
  echo "    dotfiles                    설정 파일을 홈에 심볼릭 링크 (tmux, vim, p10k, herdr, claude)"
  echo ""
  echo "  [Windows 연동 - WSL 전용]"
  echo "    winpush                     저장소 설정을 Windows에 배포 (VS Code, Terminal)"
  echo "    winpull                     Windows 설정을 저장소로 회수"
  echo ""
  echo "  [도구 설치]"
  echo "    opentofu                    OpenTofu를 설치하고 구성"
  echo "    awscli                      aws cli를 설치"
  echo "    brew                        homebrew 설치"
  echo "    tccli                       Tencent Cloud CLI를 설치 (uv tool 기반)"
  echo "    coscli                      Tencent Cloud COS CLI를 설치"
  echo "    go                          Go(golang)를 설치"
  echo "    uv                          uv(Python 패키지·버전 관리자)를 설치"
  echo "    nvm                         nvm(Node 버전 관리자)과 LTS Node를 설치"
  echo "    claude                      Claude Code(Anthropic 공식 CLI)를 설치"
  echo "    codex                       Codex CLI(OpenAI 코딩 에이전트)를 설치"
  echo "    gitleaks                    gitleaks(git 비밀값 검사 도구)를 설치"
  echo "    herdr                       Herdr TUI(코딩 에이전트 멀티플렉서)를 설치하고 설정 연결"
}

## OS 정보 가져오기
get_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=${ID}
    VER=${VERSION_ID}
  else
    OS=$(uname -s)
    VER=$(uname -r)
  fi
}

## 리눅스인지 확인하기
is_linux() {
  if [[ "$(uname)" == "Linux" ]]; then
    return 0
  fi
  echo >&2 "Linux가 아닙니다."
  return 1
}

## WSL인지 확인하기
is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

## 패키지 관리자 가져오기
get_pkgmanager() {
  case ${OS} in
  ubuntu)
    PKG_MANAGER="sudo apt"
    ;;
  *)
    echo "지원하지 않는 배포판입니다. : ${OS}"
    ;;
  esac
}

## 현재 shell 가져오기
current_shell() {
  CURRENT_SHELL=$(echo $SHELL)
}

## shell 변경하기
change_zsh() {
  if [[ $CURRENT_SHELL == *"/bash" ]]; then
      echo "현재 셸은 bash입니다. zsh로 변경합니다."

      # zsh 설치 확인
      if ! command -v zsh &> /dev/null; then
          echo "zsh가 설치되어 있지 않습니다. zsh를 설치하세요."
          exit 1
      fi

      # 로그인 셸 변경
      chsh -s $(which zsh)
      echo "zsh로 셸이 변경되었습니다. 변경 사항을 적용하려면 로그아웃 후 다시 로그인하십시오."
  else
      echo "현재 셸은 bash가 아닙니다. 현재 셸: $CURRENT_SHELL"
  fi
}

# 필수 패키지 설치
requirement_package() {
  # jq: 클라우드 CLI 출력 파싱에 사용 (functions/tencent.zsh 의 tc-assume 등이 의존)
  $PKG_MANAGER install -y wget curl git zsh bat unzip jq
}

# 기존 파일을 백업 (심볼릭 링크는 그냥 덮어씀)
backup_if_real_file() {
  local target="$1"
  if [ -e "${target}" ] && [ ! -L "${target}" ]; then
    mv "${target}" "${target}.bak"
    echo "  기존 파일을 백업했습니다: ${target}.bak"
  fi
}

# zsh 환경 구성
set_zsh() {
  ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"

  # oh-my-zsh 설치
  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "oh-my-zsh은 이미 설치되었습니다."
  fi

  ## powerlevel10k theme 설치
  if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
  fi

  # zsh 플러그인 설치
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
  fi
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
  fi

  # zshrc symlink (나머지 홈 링크는 set_dotfiles가 담당)
  backup_if_real_file "${HOME}/.zshrc"
  ln -fs "${ZSH_FILE}" "${HOME}"/.zshrc
  echo "셸 설정을 연결했습니다: ~/.zshrc -> ${ZSH_FILE}"
}

## 설정 파일을 홈 디렉토리에 심볼릭 링크
## 저장소가 원본이므로 홈의 파일을 직접 고치지 말 것
set_dotfiles() {
  echo "설정 파일을 홈 디렉토리에 연결합니다..."

  # 링크할 대상 : "저장소 경로:홈 경로"
  local links=(
    "alias:${HOME}/alias"
    "functions:${HOME}/functions"
    "config/tmux.conf:${HOME}/.tmux.conf"
    "config/vimrc:${HOME}/.vimrc"
    "config/p10k.zsh:${HOME}/.p10k.zsh"
    "config/herdr.toml:${HOME}/.config/herdr/config.toml"
    # Claude Code 전역 지침·설정 (서명 제거, 민감 파일 읽기 차단)
    "config/claude/CLAUDE.md:${HOME}/.claude/CLAUDE.md"
    "config/claude/settings.json:${HOME}/.claude/settings.json"
    # 서브 에이전트 정의 (디렉토리째 링크 → /agents 로 새로 만든 것도 저장소에 바로 생긴다)
    "config/claude/agents:${HOME}/.claude/agents"
  )

  local entry src dest
  for entry in "${links[@]}"; do
    src="${repo_dir}/${entry%%:*}"
    dest="${entry##*:}"

    if [ ! -e "${src}" ]; then
      echo "  건너뜀 (저장소에 파일 없음): ${src}"
      continue
    fi

    # ~/.config/<도구>/ 처럼 부모 디렉토리가 아직 없는 대상을 위해
    mkdir -p "$(dirname "${dest}")"
    backup_if_real_file "${dest}"
    # -n : dest가 이미 디렉토리 심볼릭 링크일 때 그 안에 중첩 생성되는 것을 방지
    ln -fsn "${src}" "${dest}"
    echo "  연결: ${dest} -> ${src}"
  done

  echo "완료되었습니다."
  if is_wsl; then
    echo "VS Code / Windows Terminal 설정은 'setEnv.sh -e winpush' 로 배포하세요."
  fi
}

## Windows 사용자 홈 경로 가져오기 (WSL 전용)
get_win_home() {
  if ! is_wsl; then
    echo >&2 "WSL 환경이 아닙니다. Windows 연동은 WSL에서만 동작합니다."
    return 1
  fi

  # cmd.exe로 %USERPROFILE%을 물어보고, 실패하면 관례적 경로로 대체
  WIN_HOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null)
  if [ -z "${WIN_HOME}" ] || [ ! -d "${WIN_HOME}" ]; then
    WIN_HOME="/mnt/c/Users/$(whoami)"
  fi

  if [ ! -d "${WIN_HOME}" ]; then
    echo >&2 "Windows 사용자 디렉토리를 찾지 못했습니다: ${WIN_HOME}"
    return 1
  fi
  return 0
}

## Windows 쪽 설정 파일 경로 목록을 구성
## Windows 파일시스템(drvfs)에는 심볼릭 링크를 걸 수 없으므로 복사로 동기화한다.
build_win_pairs() {
  get_win_home || return 1

  WIN_PAIRS=()

  # VS Code (Windows 사용자 설정)
  local vscode_dest="${WIN_HOME}/AppData/Roaming/Code/User/settings.json"
  if [ -d "$(dirname "${vscode_dest}")" ]; then
    WIN_PAIRS+=("config/vscode-settings.json:${vscode_dest}")
  else
    echo "  건너뜀 (VS Code 미설치): ${vscode_dest}"
  fi

  # Windows Terminal
  local wt_dest="${WIN_HOME}/AppData/Local/Packages/${wt_package}/LocalState/settings.json"
  if [ -d "$(dirname "${wt_dest}")" ]; then
    WIN_PAIRS+=("config/wt-settings.json:${wt_dest}")
  else
    echo "  건너뜀 (Windows Terminal 미설치): ${wt_dest}"
  fi

  if [ ${#WIN_PAIRS[@]} -eq 0 ]; then
    echo "동기화할 대상이 없습니다."
    return 1
  fi
  return 0
}

## 저장소 설정을 Windows로 배포
set_winpush() {
  echo "저장소 설정을 Windows로 배포합니다..."
  build_win_pairs || return 1

  local entry src dest
  for entry in "${WIN_PAIRS[@]}"; do
    src="${repo_dir}/${entry%%:*}"
    dest="${entry#*:}"

    [ -f "${src}" ] || { echo "  건너뜀 (저장소에 파일 없음): ${src}"; continue; }

    # Windows 쪽 기존 설정을 덮어쓰므로 반드시 백업
    [ -f "${dest}" ] && cp "${dest}" "${dest}.bak"
    cp "${src}" "${dest}"
    echo "  배포: ${src} -> ${dest}"
  done
  echo "완료되었습니다. (기존 설정은 .bak으로 백업)"
}

## Windows 설정을 저장소로 회수
set_winpull() {
  echo "Windows 설정을 저장소로 회수합니다..."
  build_win_pairs || return 1

  local entry src dest
  for entry in "${WIN_PAIRS[@]}"; do
    src="${repo_dir}/${entry%%:*}"
    dest="${entry#*:}"

    [ -f "${dest}" ] || { echo "  건너뜀 (Windows에 파일 없음): ${dest}"; continue; }

    cp "${dest}" "${src}"
    echo "  회수: ${dest} -> ${src}"
  done
  echo "완료되었습니다. git diff로 변경 내용을 확인하고 커밋하세요."
}

## OpenTofu 설치 및 구성
set_opentofu() {
  echo "setting OpenTofu..."
  case ${OS} in
  ubuntu)
    echo "ubuntu 서버에 OpenTofu를 설치 및 구성합니다..."
    echo "제공되는 설치 스크립트를 이용해서 설치합니다."
    mkdir -p "$tmp_dir"
    curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o "${tmp_dir}/install-opentofu.sh" || exit
    chmod +x "${tmp_dir}/install-opentofu.sh"
    "${tmp_dir}/install-opentofu.sh" --install-method deb
    rm -rf "$tmp_dir"
    ;;
  *)
    echo "지원하지 않는 배포판입니다. : ${OS}"
    ;;
  esac
}

## awscli 설치
set_awscli() {
  echo "awscli를 설치합니다..."
  mkdir -p "$tmp_dir"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${tmp_dir}/awscliv2.zip" || exit 1
  unzip -q -o "${tmp_dir}/awscliv2.zip" -d "$tmp_dir"
  sudo "${tmp_dir}/aws/install" --update
  rm -rf "$tmp_dir"

  if command -v aws &> /dev/null; then
    echo "awscli 설치가 완료되었습니다: $(aws --version)"
  else
    echo "awscli 설치에 실패했습니다."
    exit 1
  fi
}

## 기본 환경 구성
set_default() {
  echo "기본 환경을 구성합니다..."
  case ${OS} in
  ubuntu)
    $PKG_MANAGER update -y
    requirement_package
    sudo test -f /etc/sudoers.d/$USER || echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/$USER
    current_shell
    change_zsh
    ZSH_FILE="${repo_dir}/zshrc_ubuntu"
    set_zsh
    set_dotfiles
    ;;
  *)
    echo "지원하지 않는 배포판입니다. : ${OS}"
    ;;
  esac
}

## brew 설치 및 설정
set_brew() {
  echo "brew를 설치합니다..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ $? -eq 0 ]; then
    echo "brew 설치가 완료되었습니다."
  else
    echo "brew 설치에 실패했습니다."
    exit 1
  fi
}

## tccli(Tencent Cloud CLI) 설치 - uv tool로 격리된 환경에 설치
## Python 도구 설치는 uv로 통일한다 (pipx를 별도로 유지하지 않기 위함).
## - uv가 자체 Python을 쓰므로 시스템 python3 / PEP 668 문제와 무관하다.
## - 실행 파일(tccli, tccli_completer)은 ~/.local/bin 에 노출된다.
set_tccli() {
  echo "Tencent Cloud CLI(tccli)를 설치합니다..."

  # uv가 없으면 먼저 설치한다 (tccli는 uv tool로 관리)
  if ! command -v uv &> /dev/null; then
    echo "uv가 설치되어 있지 않습니다. uv를 먼저 설치합니다."
    set_uv
  fi

  # 과거 pipx로 설치한 tccli가 있으면 제거한다.
  # ~/.local/bin/tccli 가 pipx 링크로 남아 있으면 uv tool install이 실패하기 때문.
  if command -v pipx &> /dev/null && pipx list --short 2>/dev/null | grep -q '^tccli '; then
    echo "pipx로 설치된 기존 tccli를 제거합니다. (uv tool로 이전)"
    pipx uninstall tccli
  fi

  if uv tool list 2>/dev/null | grep -q '^tccli '; then
    echo "tccli가 이미 설치되어 있습니다. 최신 버전으로 갱신합니다."
    uv tool upgrade tccli || exit 1
  else
    uv tool install tccli || exit 1
  fi

  if ! command -v tccli &> /dev/null; then
    echo "tccli 설치에 실패했습니다."
    exit 1
  fi

  # 자동완성은 tccli가 제공하는 tccli_completer(bash 형식)를 zshrc에서 연결한다.
  echo ""
  echo "tccli 설치가 완료되었습니다: $(tccli --version 2>&1 | head -n 1)"
  echo "  tccli configure --profile <이름>   프로필별 인증 정보 설정"
  echo "  tc-profiles                        프로필 목록 확인"
  echo "  tc-use <프로필>                    사용할 프로필 전환"
  echo "  tc-assume <역할별칭>               역할 전환(AssumeRole) 후 임시 자격증명 export"
  echo "  tc-env                             현재 프로필·리전·역할 상태 확인"
  echo "역할 별칭은 ~/.env_vars 에 TC_ROLE_<대문자별칭> 형태로 정의하세요."
  echo "자동완성은 새 셸을 열거나 'exec zsh' 후 적용됩니다."
}

## 아키텍처 확인 - amd64 / arm64 를 ARCH_ALIAS에 설정
get_arch() {
  local arch
  arch=$(uname -m)
  case $arch in
    x86_64)
      ARCH_ALIAS="amd64"
      ;;
    aarch64)
      ARCH_ALIAS="arm64"
      ;;
    *)
      echo "지원하지 않는 아키텍처입니다: $arch"
      exit 1
      ;;
  esac
}

## coscli(Tencent Cloud COS CLI) 설치
set_coscli() {
  echo "Tencent Cloud COS CLI(coscli)를 설치합니다..."
  get_arch
  mkdir -p "$tmp_dir"

  # coscli 다운로드 및 설치
  COSCLI_URL="https://cosbrowser.cloud.tencent.com/software/coscli/coscli-linux-${ARCH_ALIAS}"
  curl -fsSL "$COSCLI_URL" -o "${tmp_dir}/coscli" || exit 1
  chmod +x "${tmp_dir}/coscli"
  sudo mv "${tmp_dir}/coscli" /usr/local/bin/
  rm -rf "$tmp_dir"

  if command -v coscli &> /dev/null; then
    echo "coscli 설치가 완료되었습니다."
    echo "coscli config 명령으로 인증 정보를 설정하세요."
  else
    echo "coscli 설치에 실패했습니다."
    exit 1
  fi
}

## go(golang) 설치 - 공식 바이너리를 /usr/local/go에 설치
set_go() {
  echo "Go(golang)를 설치합니다..."
  get_arch

  # 최신 안정 버전 조회 (예: go1.22.0)
  GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -n 1)
  if [ -z "$GO_VERSION" ]; then
    echo "Go 최신 버전 정보를 가져오지 못했습니다."
    exit 1
  fi
  echo "설치할 버전: ${GO_VERSION} (${ARCH_ALIAS})"

  mkdir -p "$tmp_dir"

  # 공식 바이너리 다운로드 및 설치
  GO_TARBALL="${GO_VERSION}.linux-${ARCH_ALIAS}.tar.gz"
  curl -fsSL "https://go.dev/dl/${GO_TARBALL}" -o "${tmp_dir}/${GO_TARBALL}" || exit 1
  # 기존 설치를 제거한 뒤 새로 압축 해제 (공식 권장 방식)
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "${tmp_dir}/${GO_TARBALL}"
  rm -rf "$tmp_dir"

  if /usr/local/go/bin/go version &> /dev/null; then
    echo "Go 설치가 완료되었습니다: $(/usr/local/go/bin/go version)"
    echo "PATH에 /usr/local/go/bin이 포함되어야 합니다. (zshrc_ubuntu에서 자동 설정)"
  else
    echo "Go 설치에 실패했습니다."
    exit 1
  fi
}

## uv(Python 패키지·프로젝트 관리자) 설치
## Python 버전 설치, 가상환경, 의존성 관리를 uv 하나로 처리한다.
## 시스템 python3(apt)는 건드리지 않는다 - uv가 관리하는 Python은 ~/.local/share/uv 아래에 격리된다.
set_uv() {
  echo "uv를 설치합니다..."

  if command -v uv &> /dev/null; then
    echo "uv가 이미 설치되어 있습니다: $(uv --version)"
    echo "최신 버전으로 갱신합니다."
    uv self update
  else
    # INSTALLER_NO_MODIFY_PATH=1 로 설치 스크립트가 셸 프로필을 수정하지 못하게 막는다.
    # - 설치 스크립트는 ~/.zshrc에 PATH를 직접 추가하는데, zshrc는 git으로 관리되므로 부적합
    # - ~/.local/bin은 zshrc에서 조건부로 PATH에 추가하고 있음 (tccli/pipx와 동일한 방식)
    curl -fsSL https://astral.sh/uv/install.sh | env INSTALLER_NO_MODIFY_PATH=1 sh || exit 1
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if ! command -v uv &> /dev/null; then
    echo "uv 설치에 실패했습니다."
    exit 1
  fi

  # zsh 자동완성 생성 (~/.zfunc 는 zshrc에서 fpath에 추가됨)
  mkdir -p "${HOME}/.zfunc"
  uv generate-shell-completion zsh > "${HOME}/.zfunc/_uv"
  uvx --generate-shell-completion zsh > "${HOME}/.zfunc/_uvx"
  echo "zsh 자동완성을 생성했습니다: ~/.zfunc/_uv, ~/.zfunc/_uvx"

  # uv가 관리하는 최신 Python 설치
  echo "최신 Python을 설치합니다..."
  uv python install

  echo ""
  echo "uv 설치가 완료되었습니다: $(uv --version)"
  echo "  uv python list       설치된/설치 가능한 Python 확인"
  echo "  uv init <프로젝트>    새 프로젝트 생성"
  echo "  uv sync              pyproject.toml 기준으로 의존성 동기화"
  echo "  uvx <도구>            설치 없이 CLI 도구 실행"
  echo "자동완성은 새 셸을 열거나 'exec zsh' 후 적용됩니다."
}

## nvm(Node Version Manager) + LTS Node 설치
## Node 버전은 nvm으로 관리하고, 패키지는 각 Node 버전에 딸려오는 npm을 그대로 쓴다.
## - 공식 설치 스크립트는 ~/.zshrc 에 nvm 로드 블록을 직접 추가하는데, zshrc는 git으로 관리되므로
##   PROFILE=/dev/null 로 이를 막는다 (uv의 INSTALLER_NO_MODIFY_PATH=1 과 같은 이유).
##   nvm 로드는 zshrc_* 의 "개발 도구" 섹션이 조건부로 처리한다.
## - 설치 위치는 ~/.nvm 이고, 이미 있으면 설치 스크립트가 fetch/checkout으로 갱신한다(멱등).
set_nvm() {
  echo "nvm(Node Version Manager)을 설치합니다..."

  export NVM_DIR="${HOME}/.nvm"

  # 최신 릴리스 태그 조회
  # GitHub API 대신 git ls-remote 를 쓴다 (비인증 API의 rate limit을 타지 않기 위함)
  local nvm_version
  nvm_version=$(git ls-remote --tags --refs --sort=-v:refname https://github.com/nvm-sh/nvm.git 'v*' \
    | head -n 1 | sed 's|.*/||')
  if [ -z "${nvm_version}" ]; then
    echo "nvm 최신 버전 정보를 가져오지 못했습니다."
    exit 1
  fi
  echo "설치할 버전: ${nvm_version}"

  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" \
    | env PROFILE=/dev/null bash || exit 1

  if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
    echo "nvm 설치에 실패했습니다."
    exit 1
  fi

  # zshrc는 새 셸에서 로드되므로, 지금 셸에는 직접 읽어 들여 Node를 설치한다
  . "${NVM_DIR}/nvm.sh"

  echo "LTS Node를 설치합니다..."
  nvm install --lts || exit 1
  # 새 셸에서 쓸 기본 버전 지정 (지정하지 않으면 nvm use 를 매번 해야 한다)
  nvm alias default 'lts/*'

  echo ""
  echo "nvm 설치가 완료되었습니다: $(nvm --version)"
  echo "  node $(node --version) / npm $(npm --version)"
  echo "  nvm ls                     설치된 Node 버전 목록"
  echo "  nvm install <버전>          특정 버전 설치 (예: nvm install 22)"
  echo "  nvm use <버전>              현재 셸의 버전 전환"
  echo "  nvm alias default <버전>    새 셸의 기본 버전 지정"
  echo "nvm은 새 셸을 열거나 'exec zsh' 후 적용됩니다."
}

## Claude Code(Anthropic 공식 CLI) 설치
## 공식 네이티브 설치 스크립트를 사용한다.
## - 실행 파일은 ~/.local/bin/claude 에 설치된다 (~/.local/share/claude/versions/ 로의 심볼릭 링크).
##   ~/.local/bin 은 zshrc_ubuntu 가 조건부로 PATH에 추가하므로 별도 PATH 설정이 필요 없다.
## - 네이티브 설치는 셸 프로필을 수정하지 않고, 실행 중 백그라운드로 자동 업데이트된다.
## - npm(전역 설치)은 쓰지 않는다. Node 런타임 의존을 새 장비에 강요하게 되므로 uv/tccli와 같은 결로 맞춘다.
set_claude() {
  echo "Claude Code를 설치합니다..."

  if command -v claude &> /dev/null; then
    echo "Claude Code가 이미 설치되어 있습니다: $(claude --version 2>/dev/null)"
    echo "최신 버전으로 갱신합니다."
    claude update || exit 1
  else
    curl -fsSL https://claude.ai/install.sh | bash || exit 1
    export PATH="${HOME}/.local/bin:${PATH}"
  fi

  if ! command -v claude &> /dev/null; then
    echo "Claude Code 설치에 실패했습니다."
    exit 1
  fi

  # 전역 지침·설정·에이전트(~/.claude/CLAUDE.md, settings.json, agents/) 링크는 set_dotfiles 한 곳에서만 만든다
  set_dotfiles

  echo ""
  echo "Claude Code 설치가 완료되었습니다: $(claude --version 2>/dev/null)"
  echo "  claude              대화형 세션 시작 (첫 실행 시 브라우저 로그인)"
  echo "  claude update       수동 업데이트 (네이티브 설치는 평소 백그라운드 자동 업데이트)"
  echo "  claude doctor       설치 상태 점검"
  echo "PATH는 새 셸을 열거나 'exec zsh' 후 적용됩니다."
}

## Codex CLI(OpenAI 코딩 에이전트) 설치
## 공식 독립 설치 스크립트(chatgpt.com/codex/install.sh)를 사용한다.
## - 실행 파일은 ~/.local/bin/codex 에 설치된다 (~/.codex/packages/standalone/ 로의 심볼릭 링크).
## - 설치 스크립트는 ~/.local/bin 이 PATH에 없거나, npm/brew로 설치된 codex가 이미 있으면
##   ~/.zshrc 에 PATH 블록을 직접 추가한다. zshrc는 git으로 관리되므로
##   1) 실행 전에 ~/.local/bin 을 PATH에 넣고, 2) 다른 경로의 codex가 있으면 설치를 중단한다.
## - CODEX_NON_INTERACTIVE=1 로 "지금 실행할까요?" / "기존 codex 삭제?" 프롬프트를 건너뛴다.
## - npm 전역 설치는 쓰지 않는다 (Claude Code와 같은 이유: Node 런타임 의존을 강요하지 않음).
## - 다시 실행하면 최신 버전으로 갱신되므로 멱등하다.
set_codex() {
  echo "Codex CLI를 설치합니다..."

  export PATH="${HOME}/.local/bin:${PATH}"

  local existing_codex
  existing_codex="$(command -v codex 2>/dev/null)"
  if [ -n "${existing_codex}" ] && [ "${existing_codex}" != "${HOME}/.local/bin/codex" ]; then
    echo "다른 방식으로 설치된 codex가 있습니다: ${existing_codex}"
    echo "설치 스크립트가 ~/.zshrc 를 수정하게 되므로 먼저 제거한 뒤 다시 실행하세요."
    echo "  npm uninstall -g @openai/codex    (npm 설치)"
    echo "  brew uninstall --cask codex       (brew 설치)"
    exit 1
  fi

  if [ -n "${existing_codex}" ]; then
    echo "Codex CLI가 이미 설치되어 있습니다: $(codex --version 2>/dev/null)"
    echo "최신 버전으로 갱신합니다."
  fi

  curl -fsSL https://chatgpt.com/codex/install.sh | env CODEX_NON_INTERACTIVE=1 sh || exit 1

  if ! command -v codex &> /dev/null; then
    echo "Codex CLI 설치에 실패했습니다."
    exit 1
  fi

  # zsh 자동완성 (zshrc_* 가 fpath+=~/.zfunc 로 등록)
  mkdir -p "${HOME}/.zfunc"
  codex completion zsh > "${HOME}/.zfunc/_codex"

  echo ""
  echo "Codex CLI 설치가 완료되었습니다: $(codex --version 2>/dev/null)"
  echo "  codex               대화형 세션 시작 (첫 실행 시 'Sign in with ChatGPT' 선택)"
  echo "  codex exec \"...\"    비대화형 실행"
  echo "  bash setEnv.sh -e codex   최신 버전으로 갱신"
  echo "PATH와 자동완성은 새 셸을 열거나 'exec zsh' 후 적용됩니다."
}

## gitleaks(git 저장소 비밀값 검사 도구) 설치
## GitHub 릴리스의 공식 바이너리를 ~/.local/bin/gitleaks 에 설치한다.
## - 공식 설치 스크립트가 없고, apt 패키지는 버전이 많이 뒤처지므로 릴리스 바이너리를 쓴다.
## - sudo 없이 ~/.local/bin 에 둔다 (zshrc_ubuntu 가 조건부로 PATH에 추가).
## - 릴리스의 checksums.txt 로 SHA-256 을 검증한 뒤 설치한다.
## - 최신 태그는 GitHub API 대신 git ls-remote 로 조회한다 (비인증 API rate limit 회피, set_nvm 과 같은 방식).
## - 다시 실행하면 최신 버전으로 덮어쓰므로 멱등하다.
set_gitleaks() {
  echo "gitleaks를 설치합니다..."
  get_arch

  # 릴리스 파일명은 amd64 대신 x64 를 쓴다
  local gl_arch
  case "${ARCH_ALIAS}" in
    amd64) gl_arch="x64" ;;
    arm64) gl_arch="arm64" ;;
  esac

  # 정식 릴리스 태그만 고른다 (vX.Y.Z)
  local gl_tag
  gl_tag=$(git ls-remote --tags --refs --sort=-v:refname https://github.com/gitleaks/gitleaks.git 'v*' \
    | sed 's|.*/||' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)
  if [ -z "${gl_tag}" ]; then
    echo "gitleaks 최신 버전 정보를 가져오지 못했습니다."
    exit 1
  fi
  local gl_version="${gl_tag#v}"

  if command -v gitleaks &> /dev/null; then
    echo "gitleaks가 이미 설치되어 있습니다: $(gitleaks version 2>/dev/null)"
  fi
  echo "설치할 버전: ${gl_tag} (${gl_arch})"

  local gl_tarball="gitleaks_${gl_version}_linux_${gl_arch}.tar.gz"
  local gl_checksums="gitleaks_${gl_version}_checksums.txt"
  local gl_base="https://github.com/gitleaks/gitleaks/releases/download/${gl_tag}"
  local work_dir="${tmp_dir}/gitleaks"

  rm -rf "${work_dir}"
  mkdir -p "${work_dir}"
  curl -fsSL "${gl_base}/${gl_tarball}" -o "${work_dir}/${gl_tarball}" || exit 1
  curl -fsSL "${gl_base}/${gl_checksums}" -o "${work_dir}/${gl_checksums}" || exit 1

  # 체크섬 검증 (해당 파일 줄만 골라 sha256sum -c)
  if ! (cd "${work_dir}" && grep " ${gl_tarball}\$" "${gl_checksums}" | sha256sum -c --status -); then
    echo "gitleaks 체크섬 검증에 실패했습니다."
    rm -rf "${work_dir}"
    exit 1
  fi

  tar -xzf "${work_dir}/${gl_tarball}" -C "${work_dir}" gitleaks || exit 1
  mkdir -p "${HOME}/.local/bin"
  install -m 755 "${work_dir}/gitleaks" "${HOME}/.local/bin/gitleaks"
  rm -rf "${work_dir}"
  export PATH="${HOME}/.local/bin:${PATH}"

  if ! command -v gitleaks &> /dev/null; then
    echo "gitleaks 설치에 실패했습니다."
    exit 1
  fi

  # zsh 자동완성 (zshrc_* 가 fpath+=~/.zfunc 로 등록)
  mkdir -p "${HOME}/.zfunc"
  gitleaks completion zsh > "${HOME}/.zfunc/_gitleaks"

  echo ""
  echo "gitleaks 설치가 완료되었습니다: $(gitleaks version 2>/dev/null)"
  echo "  gitleaks git -v                  현재 저장소의 커밋 이력 전체 검사"
  echo "  gitleaks git --staged -v         커밋 전 staged 변경만 검사"
  echo "  gitleaks dir <경로> -v           git이 아닌 디렉토리 검사"
  echo "PATH와 자동완성은 새 셸을 열거나 'exec zsh' 후 적용됩니다."
}

## Herdr TUI(코딩 에이전트 멀티플렉서) 설치
## 공식 설치 스크립트를 사용한다.
## - 실행 파일 하나를 ~/.local/bin/herdr 에 넣는다. sudo 불필요, 셸 프로필 수정 없음
##   (PATH 안내만 출력하므로 억제 옵션이 필요 없다). 다운로드 파일은 SHA-256 으로 검증한다.
## - 다시 실행하면 최신 버전으로 덮어쓰므로 멱등하다. 실행 중인 서버는 기존 바이너리로 계속 돈다.
## - Herdr 앱 / herdr-core(hc)는 설치하지 않는다. TUI와 에이전트를 공유하지 않는 별도 제품이고,
##   아직 초기 버전이라 TUI만 쓴다.
## - 설정(config/herdr.toml)은 보안 기본값을 담고 있으며 set_dotfiles 가 링크한다.
set_herdr() {
  echo "Herdr TUI를 설치합니다..."

  if command -v herdr &> /dev/null; then
    echo "Herdr가 이미 설치되어 있습니다: $(herdr --version 2>/dev/null)"
    echo "최신 버전으로 갱신합니다."
  fi

  # 설치 스크립트는 HERDR_INSTALL_DIR 이 없어도 ~/.local/bin 에 설치하지만, 위치를 명시해 둔다.
  curl -fsSL https://herdr.dev/install.sh | env HERDR_INSTALL_DIR="${HOME}/.local/bin" sh || exit 1
  export PATH="${HOME}/.local/bin:${PATH}"

  if ! command -v herdr &> /dev/null; then
    echo "Herdr 설치에 실패했습니다."
    exit 1
  fi

  # 설정 파일 링크는 set_dotfiles 한 곳에서만 만든다 (전체 링크를 다시 걸어도 멱등)
  set_dotfiles

  echo ""
  echo "Herdr 설치가 완료되었습니다: $(herdr --version 2>/dev/null)"
  echo "  herdr               실행 (prefix 키 ctrl+b — tmux 안에서 실행하면 겹침)"
  echo "  herdr update        수동 업데이트"
  echo "  herdr --help        설정 파일 경로 확인"
  echo "설정: ~/.config/herdr/config.toml -> ${repo_dir}/config/herdr.toml"
  echo "  원격 감지 규칙 자동 갱신, 에이전트 자동 재개, 화면 기록 저장이 꺼져 있습니다."
  echo "  플러그인 마켓플레이스는 검토된 카탈로그가 아니므로 코드를 읽고 설치하세요."
  echo "PATH는 새 셸을 열거나 'exec zsh' 후 적용됩니다."
}

## 특정 환경을 구성하는 작업을 수행
configure_environment() {
  case "$1" in
  default)
    echo "기본 환경을 구성하는 중입니다..."
    set_default
    ;;
  dotfiles)
    is_linux && set_dotfiles
    ;;
  winpush)
    set_winpush
    ;;
  winpull)
    set_winpull
    ;;
  opentofu)
    echo "openTofu 개발 환경을 구성하는 중입니다..."
    set_opentofu
    ;;
  awscli)
    echo "AWS CLI를 설치하는 중입니다..."
    is_linux && set_awscli
    ;;
  brew)
    echo "Homebrew를 설치하는 중입니다..."
    is_linux && set_brew
    ;;
  tccli)
    echo "Tencent Cloud CLI를 설치하는 중입니다..."
    is_linux && set_tccli
    ;;
  coscli)
    echo "Tencent Cloud COS CLI를 설치하는 중입니다..."
    is_linux && set_coscli
    ;;
  go)
    echo "Go(golang)를 설치하는 중입니다..."
    is_linux && set_go
    ;;
  uv)
    echo "uv(Python 환경 관리자)를 설치하는 중입니다..."
    is_linux && set_uv
    ;;
  nvm)
    echo "nvm(Node 버전 관리자)을 설치하는 중입니다..."
    is_linux && set_nvm
    ;;
  claude)
    echo "Claude Code를 설치하는 중입니다..."
    is_linux && set_claude
    ;;
  codex)
    echo "Codex CLI를 설치하는 중입니다..."
    is_linux && set_codex
    ;;
  gitleaks)
    echo "gitleaks를 설치하는 중입니다..."
    is_linux && set_gitleaks
    ;;
  herdr)
    echo "Herdr TUI를 설치하는 중입니다..."
    is_linux && set_herdr
    ;;
  *)
    echo "알 수 없는 환경: $1"
    print_help
    exit 1
    ;;
  esac
}

####################### 2. 함수 선언 - End  ##########################

####################### 3. 스크립트 인자 파싱 - Start ################

## 인자가 없는지 확인
if [[ $# -eq 0 ]]; then
  print_help
  exit 1
fi

## 스크립트 인자 파싱
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    print_help
    exit 0
    ;;
  -e | --env)
    shift
    environment="$1"
    ;;
  *)
    echo "알수없는 옵션 : $1"
    print_help
    exit 1
    ;;
  esac
  shift
done

####################### 3. 스크립트 인자 파싱 - End ##################

####################### 4. Main #####################################
## 필수 옵션 확인
if [ -z "$environment" ]; then
  echo "-e 또는 --env 옵션을 사용하여 환경을 지정하십시오."
  print_help
  exit 1
fi

# 공통 정보 수집
get_os
get_pkgmanager

## 특정 환경 구성
configure_environment "$environment"
