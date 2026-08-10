#!/bin/bash

######################################################################
# Script Name  : setEnv.sh                                           #
# Description  : 개발 및 운영 환경을 구성하기 위한 스크립트          #
# Author       : hipbone                                             #
# Created Date : 2024-01-09                                          #
# Last Update  : 2026-08-10                                          #
# Version      : 2.0                                                 #
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
  echo "    dotfiles                    설정 파일을 홈에 심볼릭 링크 (tmux, vim, p10k)"
  echo ""
  echo "  [Windows 연동 - WSL 전용]"
  echo "    winpush                     저장소 설정을 Windows에 배포 (VS Code, Terminal)"
  echo "    winpull                     Windows 설정을 저장소로 회수"
  echo ""
  echo "  [도구 설치]"
  echo "    opentofu                    OpenTofu를 설치하고 구성"
  echo "    awscli                      aws cli를 설치"
  echo "    brew                        homebrew 설치"
  echo "    tccli                       Tencent Cloud CLI를 설치"
  echo "    coscli                      Tencent Cloud COS CLI를 설치"
  echo "    go                          Go(golang)를 설치"
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
  $PKG_MANAGER install -y wget curl git zsh bat unzip
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
  )

  local entry src dest
  for entry in "${links[@]}"; do
    src="${repo_dir}/${entry%%:*}"
    dest="${entry##*:}"

    if [ ! -e "${src}" ]; then
      echo "  건너뜀 (저장소에 파일 없음): ${src}"
      continue
    fi

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

## tccli(Tencent Cloud CLI) 설치 - pipx를 사용하여 격리된 환경에 설치
set_tccli() {
  echo "Tencent Cloud CLI(tccli)를 설치합니다..."

  # pipx 설치 확인 및 설치 (apt로 설치하여 PEP 668 문제 회피)
  if ! command -v pipx &> /dev/null; then
    echo "pipx가 설치되어 있지 않습니다. pipx를 설치합니다."
    $PKG_MANAGER install -y pipx
    # pipx ensurepath는 사용하지 않음
    # - ensurepath는 zshrc를 직접 수정하는데, zshrc는 git으로 관리되므로 부적합
    # - 대신 zshrc에서 ~/.local/bin을 조건부로 PATH에 추가하도록 설정함
    export PATH="$HOME/.local/bin:$PATH"
  fi

  # tccli 설치 (pipx를 통해 격리된 가상환경에 설치)
  pipx install tccli
  if [ $? -eq 0 ]; then
    echo "tccli 설치가 완료되었습니다."
    echo "tccli configure 명령으로 인증 정보를 설정하세요."
  else
    echo "tccli 설치에 실패했습니다."
    exit 1
  fi
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
