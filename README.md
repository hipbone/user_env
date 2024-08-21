# user_env

새로운 PC 및 서버에서 빠르게 사용자 환경을 구성할 수 있도록 도와주는 도구

## 지원되는 배포판

* MacBook(검토 필요)
* CentOS(검토 필요)
* Ubuntu(final)

## 통합 환경 구성

다음을 실행하면 zsh 환경이 구성 됨
* 모든 배포판에서 동일하며, 현재 ubuntu만 검증했음

```bash
bash set_env.sh
```

### 도구 통합 중...

setEnv.sh CLI 툴로 통합 중이며, 별도의 인자값을 입력 받아 여러 환경을 구성

```bash
# 기본 환경 구성 : zsh
bash setEnv.sh -e default
# OpenTofu 설치 및 구성
bash setEnv.sh -e opentofu
```


### 개인키와 같은 환경변수를 설정하는 방법

~/.env_vars 파일에 환경변수를 설정한다.
.zshrc에서는 위 환경 변수 파일을 로드하게 되어 있기 때문에, 각 사용자별로 설정이 가능하다.

.zshrc
```bash
source ~/.zshrc
```

## MacBook

### 초기 세팅

``` bash
bash setting_mac.sh
```

## CentOS

## Vim 세팅

## Example

```bash
./set_env.sh
```

## 리눅스 환경에서 vim 세팅

```bash
./set_env_linux.sh
```

## 로케일 문제 시 설정 - 한글깨짐

```bash
./set_locales.sh
```
