# Python 환경 helper 함수 (uv 기반)
#
# 대부분의 작업은 `uv run` 으로 활성화 없이 처리하는 것이 낫지만,
# 셸에서 직접 python/pytest 를 두드려야 할 때를 위해 활성화 helper를 둔다.

# 현재 위치에서 위로 올라가며 .venv 를 찾아 활성화
uvon() {
  local dir="${PWD}"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.venv/bin/activate" ]]; then
      source "$dir/.venv/bin/activate"
      echo "활성화: $dir/.venv  ($(python --version 2>&1))"
      return 0
    fi
    dir="${dir:h}"
  done

  echo "상위 경로에서 .venv를 찾지 못했습니다."
  echo "생성하려면: uv venv  (또는 uv sync)"
  return 1
}

# 가상환경 비활성화
uvoff() {
  if [[ -z "${VIRTUAL_ENV}" ]]; then
    echo "활성화된 가상환경이 없습니다."
    return 1
  fi
  local venv="${VIRTUAL_ENV}"
  deactivate
  echo "비활성화: ${venv}"
}

# 현재 Python 환경 상태를 한눈에 보기
uvinfo() {
  local py proj

  if command -v uv &>/dev/null; then
    echo "uv         : $(uv --version)"
  else
    echo "uv         : 미설치 (bash setEnv.sh -e uv)"
  fi

  echo "VIRTUAL_ENV: ${VIRTUAL_ENV:-(없음)}"

  # 가상환경이 없는 장비에는 python 없이 python3만 있을 수 있다
  py="$(command -v python 2>/dev/null || command -v python3 2>/dev/null)"
  if [[ -n "$py" ]]; then
    echo "python     : ${py}"
    echo "version    : $("$py" --version 2>&1)"
  else
    echo "python     : 없음"
  fi

  proj="$(up pyproject.toml 2>/dev/null)" && echo "project    : ${proj}"
}
