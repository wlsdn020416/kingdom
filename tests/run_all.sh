#!/bin/sh
# 모든 자동 검사를 순서대로 실행한다. 하나라도 실패하면 종료 코드 1.
# 실행: sh tests/run_all.sh        (Godot 경로를 바꾸려면 GODOT=/path/to/godot sh tests/run_all.sh)
#
# 통과 조건: 종료 코드 0 + 결과 줄 "<이름> PASS" + 로그에 "SCRIPT ERROR" 없음.
# Godot은 --script 파싱 오류나 런타임 스크립트 오류에도 종료 코드 0을 낼 수 있어서 세 가지를 모두 본다.
# Godot이 죽거나 멈추면 끝나지 않으므로 검사마다 제한 시간을 둔다 (macOS에 timeout이 없어 perl 사용).

cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
LOG_DIR="${TMPDIR:-/tmp}/kingdom-tests"
mkdir -p "$LOG_DIR"
failed=0

run() {
	name="$1"; limit="$2"; shift 2
	log="$LOG_DIR/$(echo "$name" | tr 'A-Z ' 'a-z_').log"
	perl -e 'alarm shift; exec @ARGV' "$limit" "$GODOT" --headless --path . "$@" > "$log" 2>&1
	code=$?
	if [ $code -eq 0 ] && grep -q "^$name PASS" "$log" && ! grep -q "SCRIPT ERROR" "$log"; then
		echo "PASS  $name"
	else
		echo "FAIL  $name (종료 코드 $code, 로그 $log)"
		grep -E "FAIL|SCRIPT ERROR|ERROR:" "$log" | head -20 | sed 's/^/      /'
		failed=1
	fi
}

# 새 class_name 파일은 프로젝트를 다시 훑어야 전역 클래스로 등록된다 (에디터를 열지 않은 경우 대비)
perl -e 'alarm shift; exec @ARGV' 120 "$GODOT" --headless --path . --import > "$LOG_DIR/import.log" 2>&1 \
	|| { echo "FAIL  IMPORT (로그 $LOG_DIR/import.log)"; exit 1; }

run "CHECK SCRIPTS" 120 res://tests/check_scripts.tscn
run "LOGIC TEST" 60 --script res://tests/logic_test.gd
run "SMOKE TEST" 180 res://tests/smoke_test.tscn

exit $failed
