#!/bin/bash

######################################################################
# Script Name  : setEnv.sh                                           #
# Description  : 개발 및 운영 환경을 구성하기 위한 스크립트          #
# Author       : hipbone                                             #
# Created Date : 2024-01-09                                          #
# Last Update  : 2025-07-27                                          #
# Version      : 1.2                                                 #
######################################################################

###################### 1. 변수 선언 - Start ##########################
## 스크립트 이름
script_name=$(basename "$0")
## 임시 디렉토리
tmp_dir="tmp"
###################### 1. 변수 선언 - End ############################

####################### 2. 함수 선언 - Start #########################
## 도움말 출력 함수
print_help() {
  echo "Usage: $script_name -e|--env ENVIRONMENT"
  echo "개발 및 운영 환경 구성 도구"
  echo ""
  echo "Options:"
  echo "  -h, --help    		도움말 보기"
  echo "  -e, --env ENVIRONMENT		세팅할 환경"
  echo ""
  echo ""
  echo "지원되는 ENVIRONMENT"
  echo "  default                       기본 환경을 구성(zsh)"
  echo "  opentofu                      OpenTofu를 설치하고 구성"
  echo "  awscli                        aws cli를 설치"
  echo "  brew                          homebrew 설치"
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
    exit 0
  else
    echo >&2 "Linux가 아닙니다."
  fi

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

# zsh 환경 구성
set_zsh() {
  ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
  ALIAS_DIR="${PWD}/alias"
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

  # zsh symlink
  ln -fs "${ZSH_FILE}" "${HOME}"/.zshrc
  ln -fs "${ALIAS_DIR}" "${HOME}"/alias

  # Profile 로드
  source "${HOME}"/.zshrc
}

## OpenTofu 설치 및 구성
set_opentofu() {
  echo "setting OpenTofu..."
  case ${OS} in
  ubuntu)
    echo "ubuntu 서버에 OpenTofu를 설치 및 구성합니다..."
    echo "제공되는 설치 스크립트를 이용해서 설치합니다."
    curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh || exit
    chmod +x install-opentofu.sh
    ./install-opentofu.sh --install-method deb
    if [ $? -eq 0 ]; then
      rm -f install-opentofu.sh
    fi
    ;;
  *)
    echo "지원하지 않는 배포판입니다. : ${OS}"
    ;;
  esac
}

## awscli 설치
set_awscli() {
  echo "awscli를 설치합니다..."
  mkdir $tmp_dir
  cd $tmp_dir || exit
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  rm -rf ../$tmp_dir
}

## 기본 환경 구성
set_default() {
  echo "기본 환경을 구성합니다..."
  case ${OS} in
  ubuntu)
    $PKG_MANAGER update -y
    sudo test -f /etc/sudoers.d/$USER || echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/$USER
    current_shell
    change_zsh
    ZSH_FILE="${PWD}/zshrc_ubuntu"
    set_zsh "${ZSH_FILE}"
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

## 특정 환경을 구성하는 작업을 수행
configure_environment() {
  case "$1" in
  opentofu)
    echo "openTofu 개발 환경을 구성하는 중입니다..."
    set_opentofu "${OS}"
    ;;
  default)
    echo "기본 환경을 구성하는 중입니다..."
    set_default "${OS}"
    ;;
  production)
    echo "Configuring production environment..."
    # 여기에 운영 환경을 구성하는 작업 추가
    ;;
  awscli)
    echo "AWS CLI를 설치하는 중입니다..."
    # 플랫폼 확인
    if $(is_linux); then
      set_awscli
    fi
    ;;
  brew)
    echo "Homebrew를 설치하는 중입니다..."
    if $(is_linux); then
      set_brew
    fi
    ;;
  *)
    echo "알 수 없는 환경: $1"
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

# 공통 함수 실행
get_os
get_pkgmanager
requirement_package "${PKG_MANAGER}"

## 특정 환경 구성
configure_environment "$environment"
