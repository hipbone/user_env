# AWS helper 함수 (aws-vault 기반)
#
# 전제: aws-vault 가 PATH에 있어야 함 (brew install aws-vault), JSON 파싱에 jq 사용
#       프로필 정의는 ~/.aws/config, 정적 키는 aws-vault 키스토어(~/.awsvault/keys)에 있다.
#
# 문제
#   aws-vault 를 명령마다 붙이면 길어진다.
#     aws-vault --backend=file exec terraform -- terraform plan
#   게다가 file 백엔드는 exec 할 때마다 패스프레이즈를 묻고,
#   MFA가 걸린 역할 프로필은 매번 토큰까지 묻는다.
#
# 해결
#   `aws-vault export` 로 임시 자격증명을 한 번만 받아 현재 셸에 export 한다.
#   그 뒤로는 terraform / terragrunt / aws CLI 를 원래 명령 그대로 쓰면 된다.
#     av-on terraform   →   tf plan
#
#   AWS SDK 는 환경변수 자격증명을 가장 먼저 보므로 도구 쪽 설정은 손댈 게 없다.
#   대신 셸에 임시 키가 남아 있는 상태이므로, 일이 끝나면 av-off 로 지운다.
#
# 백엔드(--backend=file)는 zshrc 의 AWS_VAULT_BACKEND 로 지정하므로 인자에 쓰지 않는다.
#
#   av-profiles          프로필 목록 (현재 활성 프로필은 * 표시)
#   av-on <프로필>       임시 자격증명을 현재 셸에 export
#   av-off               자격증명 해제 (av-on 이전 상태로 복구)
#   av-env               지금 어떤 자격증명이 쓰이는지 / 만료까지 얼마나 남았는지
#
# 한 번만 실행할 명령은 굳이 av-on 하지 말고 avx(=aws-vault exec)를 쓴다:
#   avx hive-live -- aws s3 ls

# ~/.aws/config 에서 프로필의 설정값 하나 읽기 (내부용)
#   사용법: _av_cfg <프로필> <키>
_av_cfg() {
  local profile="$1" key="$2" cfg="${HOME}/.aws/config" header

  [[ -f "$cfg" ]] || return 1
  # default 만 [profile default] 가 아니라 [default] 로 적는다 (AWS 규약)
  if [[ "$profile" == "default" ]]; then
    header="[default]"
  else
    header="[profile ${profile}]"
  fi

  awk -v h="$header" -v k="$key" '
    { line = $0; sub(/[[:space:]]+$/, "", line) }
    line == h { found = 1; next }
    line ~ /^\[/ { found = 0 }
    found && line ~ "^[[:space:]]*" k "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "", line); print line; exit
    }
  ' "$cfg"
}

# 프로필의 리전 (없으면 source_profile 을 따라 올라간다) (내부용)
_av_region() {
  local profile="$1" depth="${2:-0}" region src

  (( depth > 5 )) && return 1   # 설정이 순환 참조여도 멈추도록

  region="$(_av_cfg "$profile" region)"
  if [[ -z "$region" ]]; then
    src="$(_av_cfg "$profile" source_profile)"
    [[ -n "$src" ]] && region="$(_av_region "$src" $(( depth + 1 )))"
  fi

  print -r -- "$region"
}

# 설정된 프로필 목록 (av-on 으로 활성화한 프로필은 * 표시)
av-profiles() {
  local cfg="${HOME}/.aws/config" current="${AV_PROFILE}" name role mark
  local -a names

  if [[ ! -f "$cfg" ]]; then
    echo "~/.aws/config 가 없습니다. 먼저 프로필을 정의하세요."
    return 1
  fi

  names=("${(@f)$(awk '
    /^\[profile /  { gsub(/^\[profile[[:space:]]*|\][[:space:]]*$/, ""); print }
    /^\[default\]/ { print "default" }
  ' "$cfg")}")

  local account
  for name in $names; do
    [[ -z "$name" ]] && continue
    [[ "$name" == "$current" ]] && mark="*" || mark=" "
    # arn:aws:iam::<계정ID>:role/<역할명> → 계정ID 와 역할명만 뽑는다
    role="$(_av_cfg "$name" role_arn)"
    if [[ -n "$role" ]]; then
      account="${${role#arn:aws:iam::}%%:*}"
      role="${account}/${role##*/}"
    fi
    printf '%s %-24s %-16s %s\n' "$mark" "$name" "$(_av_region "$name")" "$role"
  done
}

# 임시 자격증명을 현재 셸에 export
#   사용법: av-on <프로필> [aws-vault export 옵션...]
#   예:     av-on terraform
#           av-on hive-live -d 4h      (유효시간 연장)
#           av-on hive-live -t 123456  (MFA 토큰을 미리 넘기기)
av-on() {
  local profile="$1"
  shift 2>/dev/null

  if [[ -z "$profile" ]]; then
    echo "사용법: av-on <프로필> [aws-vault export 옵션...]   (목록: av-profiles)"
    return 1
  fi

  if ! command -v aws-vault &>/dev/null; then
    echo "aws-vault 가 없습니다: brew install aws-vault"
    return 1
  fi
  if ! command -v jq &>/dev/null; then
    echo "jq가 필요합니다: sudo apt install -y jq"
    return 1
  fi

  if [[ -z "$(_av_cfg "$profile" region)$(_av_cfg "$profile" source_profile)$(_av_cfg "$profile" role_arn)" ]]; then
    echo "~/.aws/config 에서 프로필을 찾을 수 없습니다: ${profile}"
    echo "목록 확인: av-profiles"
    return 1
  fi

  # stderr 를 가로채지 않는다. 패스프레이즈·MFA 프롬프트와 오류 메시지가 터미널에 그대로 보여야 한다.
  local json rc
  json=$(aws-vault export --format=json "$profile" "$@")
  rc=$?

  local -a fields
  fields=("${(@f)$(print -r -- "$json" | jq -r '
    [.AccessKeyId, .SecretAccessKey, (.SessionToken // ""), (.Expiration // "")] | .[]' 2>/dev/null)}")

  if [[ $rc -ne 0 || ${#fields} -lt 2 || -z "${fields[1]}" || "${fields[1]}" == "null" ]]; then
    echo "자격증명을 가져오지 못했습니다. (profile: ${profile})"
    return 1
  fi

  # av-on 이전의 환경변수는 보관했다가 av-off 에서 되돌린다.
  # (export 하지 않는다 - 자식 프로세스에는 임시 자격증명만 보이게)
  if [[ -z "${AV_PROFILE}" ]]; then
    AV_PREV_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
    AV_PREV_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
    AV_PREV_SESSION_TOKEN="${AWS_SESSION_TOKEN}"
    AV_PREV_REGION="${AWS_REGION}"
    AV_PREV_DEFAULT_REGION="${AWS_DEFAULT_REGION}"
  fi

  export AWS_ACCESS_KEY_ID="${fields[1]}"
  export AWS_SECRET_ACCESS_KEY="${fields[2]}"
  if [[ -n "${fields[3]}" ]]; then
    export AWS_SESSION_TOKEN="${fields[3]}"
  else
    unset AWS_SESSION_TOKEN   # --no-session 등으로 정적 키를 그대로 받은 경우
  fi

  # aws-vault exec 과 달리 export 는 리전을 넘겨주지 않으므로 config 에서 직접 채운다.
  # (terraform provider 에 region 이 없으면 여기 값이 쓰인다)
  local region
  region="$(_av_region "$profile")"
  if [[ -n "$region" ]]; then
    export AWS_REGION="$region"
    export AWS_DEFAULT_REGION="$region"
  fi

  export AV_PROFILE="$profile"
  export AV_EXPIRE="${fields[4]}"

  echo "프로필   : ${profile}"
  echo "리전     : ${region:-(미설정)}"
  echo "만료     : $(_av_expire_text)"
  echo "해제     : av-off"

  # AWS_PROFILE 이 남아 있으면 도구에 따라 어느 쪽을 볼지 헷갈린다.
  if [[ -n "${AWS_PROFILE}" ]]; then
    echo "주의: AWS_PROFILE=${AWS_PROFILE} 이 설정되어 있습니다. 혼동을 피하려면 unset AWS_PROFILE"
  fi
}

# 자격증명 해제 - 임시 키를 지우고 av-on 이전 상태로 복귀
av-off() {
  if [[ -z "${AV_PROFILE}" ]]; then
    echo "av-on 으로 활성화한 프로필이 없습니다."
    return 1
  fi

  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  unset AWS_REGION AWS_DEFAULT_REGION
  unset AV_PROFILE AV_EXPIRE

  if [[ -n "${AV_PREV_ACCESS_KEY_ID}" ]]; then
    export AWS_ACCESS_KEY_ID="${AV_PREV_ACCESS_KEY_ID}"
    export AWS_SECRET_ACCESS_KEY="${AV_PREV_SECRET_ACCESS_KEY}"
    [[ -n "${AV_PREV_SESSION_TOKEN}" ]] && export AWS_SESSION_TOKEN="${AV_PREV_SESSION_TOKEN}"
    echo "자격증명을 해제하고 원래 환경변수를 복구했습니다."
  else
    echo "자격증명을 해제했습니다."
  fi
  [[ -n "${AV_PREV_REGION}" ]] && export AWS_REGION="${AV_PREV_REGION}"
  [[ -n "${AV_PREV_DEFAULT_REGION}" ]] && export AWS_DEFAULT_REGION="${AV_PREV_DEFAULT_REGION}"

  unset AV_PREV_ACCESS_KEY_ID AV_PREV_SECRET_ACCESS_KEY AV_PREV_SESSION_TOKEN
  unset AV_PREV_REGION AV_PREV_DEFAULT_REGION
}

# 만료 시각을 사람이 읽을 수 있게 (내부용)
#   AV_EXPIRE 는 RFC3339 문자열. date -d 를 못 쓰는 환경이면 원문을 그대로 보여준다.
_av_expire_text() {
  local epoch left

  [[ -z "${AV_EXPIRE}" ]] && { echo "(알 수 없음)"; return 0; }

  epoch=$(date -d "${AV_EXPIRE}" +%s 2>/dev/null) || { print -r -- "${AV_EXPIRE}"; return 0; }
  left=$(( epoch - $(date +%s) ))

  if (( left > 0 )); then
    printf '%s (%d분 %d초 남음)\n' "$(date -d "@${epoch}" '+%Y-%m-%d %H:%M:%S')" $(( left / 60 )) $(( left % 60 ))
  else
    printf '%s (만료됨 - av-on %s 다시 실행)\n' "$(date -d "@${epoch}" '+%Y-%m-%d %H:%M:%S')" "${AV_PROFILE}"
  fi
}

# 현재 AWS 환경 상태를 한눈에 보기
av-env() {
  if command -v aws-vault &>/dev/null; then
    echo "aws-vault  : $(aws-vault --version 2>&1 | head -n 1)  (backend: ${AWS_VAULT_BACKEND:-기본값})"
  else
    echo "aws-vault  : 미설치 (brew install aws-vault)"
  fi

  if [[ -n "${AV_PROFILE}" ]]; then
    echo "프로필     : ${AV_PROFILE}  (av-on)"
    echo "자격증명   : 임시 키 (환경변수)"
    echo "만료       : $(_av_expire_text)"
  elif [[ -n "${AWS_ACCESS_KEY_ID}" ]]; then
    echo "프로필     : (없음)"
    echo "자격증명   : 환경변수 정적 키 — av-on 으로 넣은 것이 아닙니다."
  else
    echo "프로필     : (없음)"
    echo "자격증명   : 없음 — av-on <프로필> 또는 avx <프로필> -- <명령>"
  fi

  echo "리전       : ${AWS_REGION:-${AWS_DEFAULT_REGION:-(미설정)}}"
  [[ -n "${AWS_PROFILE}" ]] && echo "AWS_PROFILE: ${AWS_PROFILE}  (환경변수 자격증명이 있으면 무시될 수 있음)"
}
