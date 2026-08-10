# 모든 환경 공통 helper 함수
#
# alias로 표현하기 어려운 것(인자 처리, 분기, 다중 명령)만 함수로 만든다.
# 한 줄 치환으로 끝나면 alias/ 로 간다.

# 디렉토리를 만들고 그 안으로 이동
mkcd() {
  [[ -z "$1" ]] && { echo "usage: mkcd <dir>"; return 1; }
  mkdir -p "$1" && cd "$1"
}

# 확장자에 상관없이 압축 해제
extract() {
  [[ -f "$1" ]] || { echo "파일이 없습니다: $1"; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.xz)         tar xJf "$1" ;;
    *.tar)            tar xf  "$1" ;;
    *.bz2)            bunzip2 "$1" ;;
    *.gz)             gunzip  "$1" ;;
    *.zip)            unzip   "$1" ;;
    *.7z)             7z x    "$1" ;;
    *)                echo "압축 형식을 모르겠습니다: $1"; return 1 ;;
  esac
}

# PATH를 한 줄에 하나씩 출력 (PATH 꼬였을 때 확인용)
path() {
  echo "${PATH}" | tr ':' '\n'
}

# 현재 디렉토리부터 위로 올라가며 파일 찾기 (.git, .envrc 등 추적용)
up() {
  [[ -z "$1" ]] && { echo "usage: up <filename>"; return 1; }
  local dir="${PWD}"
  while [[ "$dir" != "/" ]]; do
    [[ -e "$dir/$1" ]] && { echo "$dir/$1"; return 0; }
    dir="$(dirname "$dir")"
  done
  echo "찾지 못했습니다: $1"
  return 1
}
