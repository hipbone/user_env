#!/bin/bash

######################################################################
# Script Name  : setEnv.sh                                           #
# Description  : 개발 및 운영 환경을 구성하기 위한 스크립트          #
# Author       : hipbone                                             #
# Created Date : 2024-01-09                                          #
# Last Update  : 2024-01-09                                          #
# Version      : 1.0                                                 #
######################################################################

###################### 1. 변수 선언 - Start ##########################
## 스크립트 이름
script_name=$(basename "$0")
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

# 필수 패키지 설치
requirement_package() {
  $PKG_MANAGER install -y wget curl git zsh bat
}

# zsh 환경 구성
set_zsh() {
  ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
  ALIAS_DIR="${PWD}/alias"
  # oh-my-zsh 설치
  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    Yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "oh-my-zsh은 이미 설치되었습니다."
  fi
  
  ## powerlevel10k theme 설치
  if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
      git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
  fi

  # zsh 플러그인 설치
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ];then
      git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
  fi
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ];then
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
      curl --ptoto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
      chmod +x install-opentofu.sh
      ./install-opentofu.sh --install-method deb
      if [ $? -eq 0 ]
      then
	      rm -f install-opentofu.sh
      fi
      ;;
    *)
      echo "지원하지 않는 배포판입니다. : ${OS}"
      ;;
  esac
}

## 기본 환경 구성
set_default() {
  echo "기본 환경을 구성합니다..."
  case ${OS} in
    ubuntu)
      PKG_MANAGER="sudo apt"
      ZSH_FILE="${PWD}/zshrc_ubuntu"
      requirement_package "${PKG_MANAGER}"
      set_zsh "${ZSH_FILE}"
      ;;
    *)
      echo "지원하지 않는 배포판입니다. : ${OS}"
      ;;
  esac
}

## 특정 환경을 구성하는 작업을 수행
configure_environment() {
  case "$1" in
    opentofu)
      echo "openTofu 개발 환경을 구성하는 중입니다..."
      # OS 정보 가져오기
      get_os
      set_opentofu "${OS}"
      ;;
    default)
      echo "기본 환경을 구성하는 중입니다..."
      get_os
      set_default "${OS}"
      ;;
    production)
      echo "Configuring production environment..."
      # 여기에 운영 환경을 구성하는 작업 추가
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
    -h|--help)
      print_help
      exit 0
      ;;
    -e|--env)
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

## 특정 환경 구성
configure_environment "$environment"
