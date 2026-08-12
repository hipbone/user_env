# Tencent Cloud helper 함수 (tccli 기반)
#
# 전제: tccli 가 PATH에 있어야 함 (bash setEnv.sh -e tccli), JSON 파싱에 jq 사용
#
#   프로필    ~/.tccli/<이름>.credential + <이름>.configure
#             전환은 TCCLI_PROFILE 환경변수 (tccli가 직접 읽는다) → tc-use
#   역할 전환 AssumeRole 결과를 TENCENTCLOUD_SECRET_ID/KEY/TOKEN 으로 export → tc-assume
#             tccli / terraform / SDK 가 모두 이 환경변수를 사용한다.
#
# tccli 자격증명 우선순위 (tccli 3.1.x 기준):
#   1. 명령에 --profile 을 직접 붙인 경우  → 해당 프로필 파일 (환경변수 무시)
#   2. TENCENTCLOUD_SECRET_ID/KEY 환경변수 → TCCLI_PROFILE 로 고른 프로필보다 우선
#   3. TCCLI_PROFILE(없으면 default) 프로필 파일
# 즉 환경변수에 정적 키가 남아 있으면 tc-use 로 프로필을 바꿔도 자격증명은 바뀌지 않는다.
# tc-env 가 지금 어느 것이 쓰이는지 보여준다.
#
# 역할(Role) ARN에는 조직의 UIN이 들어가므로 저장소에 두지 않는다.
# ~/.env_vars (git 미관리)에 별칭 형태로 정의해서 쓴다:
#
#   export TC_ROLE_HIVE_SANDBOX="qcs::cam::uin/<UIN>:roleName/<역할이름>"
#   → tc-assume hive-sandbox
#
# 전체 ARN을 인자로 직접 넘겨도 동작한다: tc-assume qcs::cam::uin/...

# 프로필의 기본 리전 조회 (내부용)
_tc_region() {
  local f="${HOME}/.tccli/${1:-default}.configure"
  [[ -f "$f" ]] || return 1
  command -v jq &>/dev/null || return 1
  jq -r '._sys_param.region // empty' "$f" 2>/dev/null
}

# 설정된 프로필 목록 (현재 프로필은 * 표시)
tc-profiles() {
  local dir="${HOME}/.tccli" current="${TCCLI_PROFILE:-default}" f name

  if [[ ! -d "$dir" ]]; then
    echo "~/.tccli 가 없습니다. 먼저 프로필을 만드세요: tccli configure --profile <이름>"
    return 1
  fi

  for f in "$dir"/*.credential(.N); do
    name="${${f:t}%.credential}"
    if [[ "$name" == "$current" ]]; then
      echo "* ${name}  (region: $(_tc_region "$name"))"
    else
      echo "  ${name}  (region: $(_tc_region "$name"))"
    fi
  done
}

# 사용할 프로필 전환 (인자 없으면 현재 프로필 출력, `-` 면 default로 복귀)
tc-use() {
  local name="$1"

  if [[ -z "$name" ]]; then
    echo "현재 프로필: ${TCCLI_PROFILE:-default}"
    echo "사용법: tc-use <프로필>   (목록: tc-profiles)"
    return 0
  fi

  if [[ "$name" == "-" || "$name" == "default" ]]; then
    unset TCCLI_PROFILE
    echo "프로필: default  (region: $(_tc_region default))"
    return 0
  fi

  if [[ ! -f "${HOME}/.tccli/${name}.credential" ]]; then
    echo "프로필을 찾을 수 없습니다: ${name}"
    echo "목록 확인: tc-profiles / 새로 만들기: tccli configure --profile ${name}"
    return 1
  fi

  export TCCLI_PROFILE="$name"
  echo "프로필: ${name}  (region: $(_tc_region "$name"))"

  # 환경변수 자격증명이 프로필보다 우선하므로, 남아 있으면 프로필 전환이 무의미해진다.
  if [[ -n "${TENCENTCLOUD_SECRET_ID}" ]]; then
    if [[ -n "${TC_ASSUMED_ROLE}" ]]; then
      echo "주의: 역할 전환 상태입니다(${TC_ASSUMED_ROLE}). 프로필 자격증명은 쓰이지 않습니다."
      echo "      프로필 자격증명으로 돌아가려면: tc-unassume"
    else
      echo "주의: TENCENTCLOUD_SECRET_ID 환경변수가 설정되어 있어 프로필의 키 대신 이 값이 쓰입니다."
      echo "      프로필 키를 쓰려면 명령에 --profile ${name} 을 붙이세요."
    fi
  fi
}

# 역할 전환 - AssumeRole 후 임시 자격증명을 현재 셸에 export
# 사용법: tc-assume <별칭|RoleArn> [세션명]
# 유효시간은 TC_ASSUME_DURATION(초, 기본 3600)으로 조절한다.
tc-assume() {
  local target="$1" session="${2:-${USER}-$(date +%H%M%S)}"
  local arn var json rc

  if [[ -z "$target" ]]; then
    echo "사용법: tc-assume <별칭|RoleArn> [세션명]"
    echo "  별칭은 ~/.env_vars 에 TC_ROLE_<대문자별칭> 으로 정의한다."
    echo "  예: export TC_ROLE_HIVE_SANDBOX=\"qcs::cam::uin/<UIN>:roleName/<역할이름>\""
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "jq가 필요합니다: sudo apt install -y jq"
    return 1
  fi

  if [[ "$target" == qcs::cam:* ]]; then
    arn="$target"
  else
    # hive-sandbox → TC_ROLE_HIVE_SANDBOX
    var="TC_ROLE_${${target:u}//-/_}"
    arn="${(P)var}"
    if [[ -z "$arn" ]]; then
      echo "역할 별칭을 찾을 수 없습니다: ${target}  (${var} 미정의)"
      echo "~/.env_vars 에 다음을 추가하세요:"
      echo "  export ${var}=\"qcs::cam::uin/<UIN>:roleName/<역할이름>\""
      return 1
    fi
  fi

  # --profile 을 명시해서 프로필 파일의 키로 호출한다.
  # (명시하지 않으면 이미 export된 임시/정적 환경변수 자격증명이 우선 적용된다)
  json=$(tccli sts AssumeRole \
    --profile "${TCCLI_PROFILE:-default}" \
    --RoleArn "$arn" \
    --RoleSessionName "$session" \
    --DurationSeconds "${TC_ASSUME_DURATION:-3600}" 2>&1)
  rc=$?

  # tccli 버전에 따라 응답이 Response 로 한 번 감싸일 수 있어 둘 다 받아둔다.
  local -a fields
  fields=("${(@f)$(print -r -- "$json" | jq -r '(.Response // .)
    | [.Credentials.TmpSecretId, .Credentials.TmpSecretKey, .Credentials.Token, (.ExpiredTime|tostring)]
    | .[]' 2>/dev/null)}")

  if [[ $rc -ne 0 || ${#fields} -ne 4 || -z "${fields[1]}" || "${fields[1]}" == "null" ]]; then
    echo "AssumeRole에 실패했습니다. (role: ${arn}, profile: ${TCCLI_PROFILE:-default})"
    print -r -- "$json"
    return 1
  fi

  # 원래 환경변수에 있던 정적 자격증명은 보관했다가 tc-unassume 에서 되돌린다.
  # (export 하지 않는다 - 자식 프로세스에는 임시 자격증명만 보이게)
  if [[ -z "${TC_ASSUMED_ROLE}" ]]; then
    TC_PREV_SECRET_ID="${TENCENTCLOUD_SECRET_ID}"
    TC_PREV_SECRET_KEY="${TENCENTCLOUD_SECRET_KEY}"
    TC_PREV_TOKEN="${TENCENTCLOUD_TOKEN}"
  fi

  export TENCENTCLOUD_SECRET_ID="${fields[1]}"
  export TENCENTCLOUD_SECRET_KEY="${fields[2]}"
  export TENCENTCLOUD_TOKEN="${fields[3]}"
  export TC_ASSUMED_ROLE="$arn"
  export TC_ASSUMED_EXPIRE="${fields[4]}"

  echo "역할 전환: ${arn}"
  echo "세션명   : ${session}"
  echo "만료     : $(date -d "@${TC_ASSUMED_EXPIRE}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "${TC_ASSUMED_EXPIRE}")"
  echo "해제     : tc-unassume"
}

# 역할 전환 해제 - 임시 자격증명을 지우고 전환 전 상태로 복귀
# tc-assume 로 전환한 경우에만 동작한다 (~/.env_vars 의 정적 키를 실수로 날리지 않도록).
tc-unassume() {
  if [[ -z "${TC_ASSUMED_ROLE}" ]]; then
    echo "tc-assume 로 전환한 역할이 없습니다."
    return 1
  fi

  unset TENCENTCLOUD_SECRET_ID TENCENTCLOUD_SECRET_KEY TENCENTCLOUD_TOKEN
  unset TC_ASSUMED_ROLE TC_ASSUMED_EXPIRE

  if [[ -n "${TC_PREV_SECRET_ID}" ]]; then
    export TENCENTCLOUD_SECRET_ID="${TC_PREV_SECRET_ID}"
    export TENCENTCLOUD_SECRET_KEY="${TC_PREV_SECRET_KEY}"
    [[ -n "${TC_PREV_TOKEN}" ]] && export TENCENTCLOUD_TOKEN="${TC_PREV_TOKEN}"
    echo "역할 전환을 해제하고 원래 환경변수 자격증명을 복구했습니다."
  else
    echo "역할 전환을 해제했습니다. (프로필 자격증명으로 복귀)"
  fi

  unset TC_PREV_SECRET_ID TC_PREV_SECRET_KEY TC_PREV_TOKEN
}

# 현재 Tencent Cloud 환경 상태를 한눈에 보기
tc-env() {
  local profile="${TCCLI_PROFILE:-default}" region left

  if command -v tccli &>/dev/null; then
    echo "tccli      : $(tccli --version 2>&1 | head -n 1)"
  else
    echo "tccli      : 미설치 (bash setEnv.sh -e tccli)"
  fi

  echo "profile    : ${profile}"
  region="$(_tc_region "$profile")"
  echo "region     : ${region:-(미설정)}${TENCENTCLOUD_REGION:+  ← TENCENTCLOUD_REGION=${TENCENTCLOUD_REGION} 우선}"

  # 실제로 어떤 자격증명이 쓰이는지 (--profile 을 붙이지 않은 명령 기준)
  if [[ -n "${TC_ASSUMED_ROLE}" ]]; then
    echo "자격증명   : 역할 전환 임시 키 (환경변수)"
  elif [[ -n "${TENCENTCLOUD_SECRET_ID}" ]]; then
    echo "자격증명   : 환경변수 정적 키 (프로필 ${profile} 의 키보다 우선)"
  else
    echo "자격증명   : 프로필 파일 (~/.tccli/${profile}.credential)"
  fi

  if [[ -n "${TC_ASSUMED_ROLE}" ]]; then
    echo "역할 전환  : ${TC_ASSUMED_ROLE}"
    if [[ -n "${TC_ASSUMED_EXPIRE}" ]]; then
      left=$(( TC_ASSUMED_EXPIRE - $(date +%s) ))
      if (( left > 0 )); then
        printf '만료까지   : %d분 %d초\n' $(( left / 60 )) $(( left % 60 ))
      else
        echo "만료까지   : 만료됨 (tc-assume 재실행 필요)"
      fi
    fi
  else
    echo "역할 전환  : (없음)"
  fi
}
